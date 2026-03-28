import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/services.dart';

import 'package:url_launcher/url_launcher.dart';
import '../../../../core/utils/map_style.dart';
import '../../../../core/services/directions_service.dart';
import '../../../../core/services/ride_request_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../domain/models/vehicle.dart';
import '../../domain/models/ride_request_model.dart';
import '../widgets/sheets/vehicle_selection_sheet.dart';
import '../widgets/sheets/finding_driver_sheet.dart';
import '../widgets/sheets/driver_arriving_sheet.dart';
import '../widgets/sheets/trip_in_progress_sheet.dart';
import '../widgets/sheets/trip_completed_sheet.dart';
import '../../domain/models/place_result.dart';
import '../../../../features/payment/domain/models/payment_method_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../places/presentation/providers/places_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final Completer<GoogleMapController> _controller = Completer();

  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(37.7749, -122.4194), // San Francisco (default)
    zoom: 14.4746,
  );

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Services
  final RideRequestService _rideRequestService = RideRequestService();

  // Location state
  LatLng? _currentLocation;
  bool _isLoadingLocation = true;

  // Destination state
  LatLng? _destination;
  String _destinationAddress = '';
  double _distanceKm = 0;


  // Map elements
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  // Ride state
  bool _showVehicleSelection = false;
  bool _isFindingDriver = false;
  bool _isDriverArriving = false;
  bool _isTripInProgress = false;
  bool _isTripCompleted = false;

  // Active ride request
  String? _activeRideRequestId;
  RideRequest? _activeRideRequest;
  StreamSubscription? _rideRequestSubscription;
  StreamSubscription? _driverLocationSubscription;
  Timer? _rideTimeoutTimer;
  String? _lastNotifiedStatus; // Track to avoid notification spam

  Vehicle? _selectedVehicle;

  final List<Vehicle> _vehicles = const [
    Vehicle(
      id: '1',
      name: 'Economy',
      description: '4 min away • 14:32 arrival',
      price: 12.50,
      imageAsset: 'assets/images/uber_x.png',
      etaMinutes: 4,
    ),
    Vehicle(
      id: '2',
      name: 'Comfort',
      description: '6 min away • 14:34 arrival',
      price: 18.20,
      imageAsset: 'assets/images/uber_black.png',
      etaMinutes: 6,
    ),
    Vehicle(
      id: '3',
      name: 'XL',
      description: '8 min away • 14:36 arrival',
      price: 24.00,
      imageAsset: 'assets/images/uber_xl.png',
      etaMinutes: 8,
    ),
  ];

  // Payment State — Cash only for V1
  final List<PaymentMethod> _paymentMethods = const [
    PaymentMethod(id: '1', name: 'Cash', type: PaymentType.cash),
  ];
  late PaymentMethod _selectedPaymentMethod;

  BitmapDescriptor? _driverIcon;

  @override
  void initState() {
    super.initState();
    _loadDriverIcon();
    _selectedVehicle = _vehicles.first;
    _selectedPaymentMethod = _paymentMethods.first;
    _requestLocationPermission();
  }

  @override
  void dispose() {
    _rideRequestSubscription?.cancel();
    _driverLocationSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadDriverIcon() async {
    try {
      final icon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(size: Size(48, 48)),
        'assets/images/car_icon.png',
      );
      setState(() {
        _driverIcon = icon;
      });
    } catch (e) {
      debugPrint('Error loading car icon: $e');
    }
  }

  Future<void> _requestLocationPermission() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });

      _moveCameraToCurrentLocation();
    } catch (e) {
      setState(() => _isLoadingLocation = false);
    }
  }

  Future<void> _moveCameraToCurrentLocation() async {
    if (_currentLocation == null) return;

    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _currentLocation!, zoom: 15),
      ),
    );
  }

  /// Fetch route from current location to destination
  Future<void> _fetchRoute() async {
    if (_currentLocation == null || _destination == null) return;

    final result = await DirectionsService.getDirections(
      origin: _currentLocation!,
      destination: _destination!,
    );

    if (result != null) {
      setState(() {
        _distanceKm = result.distanceKm;

        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: result.polylinePoints,
            color: Colors.blue,
            width: 5,
          ),
        };

        _markers = {
          Marker(
            markerId: const MarkerId('origin'),
            position: _currentLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            ),
            infoWindow: const InfoWindow(title: 'Pickup'),
          ),
          Marker(
            markerId: const MarkerId('destination'),
            position: _destination!,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            ),
            infoWindow: InfoWindow(title: _destinationAddress),
          ),
        };
      });

      final controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newLatLngBounds(result.bounds, 80));
    }
  }

  /// Create a ride request in Firestore and start listening for updates
  Future<void> _createRideRequest() async {
    if (_currentLocation == null || _destination == null) return;
    if (_selectedVehicle == null) return;

    // Guard against duplicate ride requests (non-blocking if query fails)
    try {
      final activeRequest = await _rideRequestService.getActiveRideRequest();
      if (activeRequest != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You already have an active ride request.')),
          );
        }
        return;
      }
    } catch (e) {
      debugPrint('Active request check failed (proceeding): $e');
    }

    try {
      setState(() {
        _isFindingDriver = true;
      });

      final requestId = await _rideRequestService.createRideRequest(
        pickupAddress:
            _destinationAddress.isNotEmpty
                ? 'Current Location'
                : 'Current Location',
        dropoffAddress: _destinationAddress,
        pickupLocation: GeoPoint(
          _currentLocation!.latitude,
          _currentLocation!.longitude,
        ),
        dropoffLocation: GeoPoint(
          _destination!.latitude,
          _destination!.longitude,
        ),
        vehicleType: _selectedVehicle!.name,
        price: 0, // Server-side pricing — Cloud Function will set the real price
        paymentMethod: _selectedPaymentMethod.name,
        distanceKm: _distanceKm,
      );

      _activeRideRequestId = requestId;

      // Start 3-minute timeout timer
      _rideTimeoutTimer?.cancel();
      _rideTimeoutTimer = Timer(const Duration(minutes: 3), () {
        if (_isFindingDriver && mounted) {
          _cancelActiveRide();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No drivers available right now. Please try again.'),
              duration: Duration(seconds: 4),
            ),
          );
        }
      });

      // Listen to the ride request for real-time status changes
      _listenToRideRequest(requestId);
    } catch (e) {
      debugPrint('Error creating ride request: $e');
      if (mounted) {
        setState(() {
          _isFindingDriver = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error requesting ride: $e')),
        );
      }
    }
  }

  /// Listen to ride request status changes from Firestore
  void _listenToRideRequest(String requestId) {
    _rideRequestSubscription?.cancel();
    _rideRequestSubscription =
        _rideRequestService.listenToRideRequest(requestId).listen((
      rideRequest,
    ) {
      if (!mounted) return;
      if (rideRequest == null) return;

      setState(() {
        _activeRideRequest = rideRequest;
      });

      // Transition states based on Firestore status
      switch (rideRequest.status) {
        case 'searching':
          setState(() {
            _isFindingDriver = true;
            _isDriverArriving = false;
            _isTripInProgress = false;
            _isTripCompleted = false;
          });
          break;

        case 'accepted':
          _rideTimeoutTimer?.cancel();
          _rideTimeoutTimer = null;
          setState(() {
            _isFindingDriver = false;
            _isDriverArriving = true;
            _isTripInProgress = false;
            _isTripCompleted = false;
          });
          // Show notification when driver is assigned (only once per status)
          if (_lastNotifiedStatus != 'accepted') {
            _lastNotifiedStatus = 'accepted';
            NotificationService().showRideStatusNotification(rideRequest);
          }
          // Start listening for driver location
          _listenToDriverLocation(requestId);
          break;

        case 'arriving':
          setState(() {
            _isFindingDriver = false;
            _isDriverArriving = true;
            _isTripInProgress = false;
            _isTripCompleted = false;
          });
          // Show notification when driver arrives (only once per status)
          if (_lastNotifiedStatus != 'arriving') {
            _lastNotifiedStatus = 'arriving';
            NotificationService().showRideStatusNotification(rideRequest);
          }
          break;

        case 'in_progress':
          setState(() {
            _isFindingDriver = false;
            _isDriverArriving = false;
            _isTripInProgress = true;
            _isTripCompleted = false;
          });
          // Show notification when trip starts (only once per status)
          if (_lastNotifiedStatus != 'in_progress') {
            _lastNotifiedStatus = 'in_progress';
            NotificationService().showRideStatusNotification(rideRequest);
          }
          // Keep listening for driver location during trip
          if (_driverLocationSubscription == null) {
            _listenToDriverLocation(requestId);
          }
          break;

        case 'completed':
          _driverLocationSubscription?.cancel();
          _driverLocationSubscription = null;
          setState(() {
            _isFindingDriver = false;
            _isDriverArriving = false;
            _isTripInProgress = false;
            _isTripCompleted = true;
          });
          // Show notification when trip completes (only once per status)
          if (_lastNotifiedStatus != 'completed') {
            _lastNotifiedStatus = 'completed';
            NotificationService().showRideStatusNotification(rideRequest);
          }
          break;

        case 'cancelled':
        case 'declined':
          _driverLocationSubscription?.cancel();
          _driverLocationSubscription = null;
          setState(() {
            _isFindingDriver = false;
            _isDriverArriving = false;
            _isTripInProgress = false;
            _isTripCompleted = false;
          });
          // Show notification when ride is cancelled
          NotificationService().showRideStatusNotification(rideRequest.copyWith(
            status: 'cancelled',
          ));
          _resetState();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  rideRequest.status == 'cancelled'
                      ? 'Ride cancelled'
                      : 'No driver available. Please try again.',
                ),
              ),
            );
          }
          break;
      }
    });
  }

  /// Listen to driver location updates and show on map
  void _listenToDriverLocation(String requestId) {
    _driverLocationSubscription?.cancel();
    _driverLocationSubscription =
        _rideRequestService.listenToDriverLocation(requestId).listen((
      geoPoint,
    ) {
      if (!mounted || geoPoint == null) return;

      final driverPos = LatLng(geoPoint.latitude, geoPoint.longitude);

      setState(() {
        // Remove old driver marker
        _markers.removeWhere((m) => m.markerId.value == 'driver');

        // Add updated driver marker
        _markers.add(
          Marker(
            markerId: const MarkerId('driver'),
            position: driverPos,
            icon:
                _driverIcon ??
                BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueViolet,
                ),
            rotation: 0,
            anchor: const Offset(0.5, 0.5),
            flat: true,
            infoWindow: InfoWindow(
              title: _activeRideRequest?.driverName ?? 'Driver',
            ),
          ),
        );
      });

      // Update camera to show both driver and relevant point
      _updateCameraForDriver(driverPos);
    });
  }

  /// Cancel the active ride request — with confirmation if driver is assigned
  Future<void> _cancelActiveRide() async {
    // If driver has been assigned, show cancellation fee warning
    if (_isDriverArriving || _isTripInProgress) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cancel Ride?'),
          content: const Text(
            'Your driver is already on the way.\n\nA cancellation fee of EGP 10 may apply.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep Ride'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Cancel Ride'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    if (_activeRideRequestId != null) {
      try {
        await _rideRequestService.cancelRideRequest(_activeRideRequestId!);
      } catch (e) {
        debugPrint('Error cancelling ride: $e');
      }
    }
    _resetState();
  }

  /// Submit rating for the completed ride
  Future<void> _submitRating(double rating) async {
    if (_activeRideRequestId != null) {
      try {
        await _rideRequestService.submitRating(_activeRideRequestId!, rating);
      } catch (e) {
        debugPrint('Error submitting rating: $e');
      }
    }
    _resetState();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rating submitted: $rating stars!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep saved places stream alive
    ref.watch(savedPlacesProvider);

    // Calculate bottom padding for map based on active sheet
    double bottomPadding = 180;
    if (_showVehicleSelection ||
        _isFindingDriver ||
        _isDriverArriving ||
        _isTripInProgress ||
        _isTripCompleted) {
      bottomPadding = 320;
    }

    return Scaffold(
      key: _scaffoldKey,
      body: Stack(
        children: [
          GoogleMap(
            padding: EdgeInsets.only(bottom: bottomPadding),
            mapType: MapType.normal,
            initialCameraPosition: _kGooglePlex,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            polylines: _polylines,
            markers:
                _markers.isNotEmpty
                    ? _markers
                    : (_currentLocation != null
                        ? {
                          Marker(
                            markerId: const MarkerId('currentLocation'),
                            position: _currentLocation!,
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueAzure,
                            ),
                            infoWindow: const InfoWindow(title: 'You are here'),
                          ),
                        }
                        : {}),
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
              controller.setMapStyle(darkMapStyle);

              if (_currentLocation != null) {
                _moveCameraToCurrentLocation();
              }
            },
          ),

          // Loading indicator for location
          if (_isLoadingLocation)
            const Center(child: CircularProgressIndicator()),

          // Center Location Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 80,
            right: 16,
            child: CircleAvatar(
              backgroundColor: Theme.of(context).cardColor,
              radius: 20,
              child: IconButton(
                icon: Icon(
                  Icons.my_location,
                  color: Theme.of(context).iconTheme.color,
                ),
                onPressed: _moveCameraToCurrentLocation,
              ),
            ),
          ),

          // Back Button for Vehicle Selection
          if (_showVehicleSelection && !_isFindingDriver)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              child: CircleAvatar(
                backgroundColor: Colors.white,
                radius: 24,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: () {
                    _resetState();
                  },
                ),
              ),
            ),

          // Top Floating UI
          if (!_showVehicleSelection &&
              !_isFindingDriver &&
              !_isDriverArriving &&
              !_isTripInProgress &&
              !_isTripCompleted)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: _buildTopFloatingUI(),
            ),

          // Bottom Sheet Content
          Positioned.fill(child: _buildBottomSheetContent()),
        ],
      ),
    );
  }

  Widget _buildBottomSheetContent() {
    if (_isTripCompleted) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: TripCompletedSheet(
          price: _activeRideRequest?.price ?? _selectedVehicle?.price ?? 0.0,
          driverName: _activeRideRequest?.driverName,
          onSubmitRating: _submitRating,
        ),
      );
    }

    if (_isTripInProgress) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: TripInProgressSheet(
          destinationAddress:
              _activeRideRequest?.dropoffAddress ?? _destinationAddress,
          onPanic: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Emergency contact alerted')),
            );
          },
          onShareTrip: () {},
        ),
      );
    }

    if (_isDriverArriving) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: DriverArrivingSheet(
          driverName: _activeRideRequest?.driverName ?? 'Driver',
          carModel: _activeRideRequest?.driverCarModel ?? 'Car',
          carPlate: _activeRideRequest?.driverCarPlate ?? 'N/A',
          onCall: () => _contactDriver(
            'tel',
            _activeRideRequest?.driverPhone ?? '',
          ),
          onMessage: () => _contactDriver(
            'sms',
            _activeRideRequest?.driverPhone ?? '',
          ),
          onCancel: _cancelActiveRide,
        ),
      );
    }

    if (_isFindingDriver) {
      return Align(
        alignment: Alignment.bottomCenter,
        child: FindingDriverSheet(onCancel: _cancelActiveRide),
      );
    }

    return VehicleSelectionSheet(
      vehicles: _vehicles,
      selectedVehicle: _selectedVehicle,
      distanceKm: _distanceKm,
      selectedPaymentMethod: _selectedPaymentMethod,
      onPaymentMethodTap: _showPaymentMethodPicker,
      onQuickDestTap: (dest) async {
        final savedPlaces = ref.read(savedPlacesProvider).value ?? [];
        try {
          final place = savedPlaces.firstWhere(
            (p) => p.name.toLowerCase() == dest.toLowerCase(),
          );
          setState(() {
            _destination = LatLng(
              place.location.latitude,
              place.location.longitude,
            );
            _destinationAddress = place.address;
            _showVehicleSelection = true;
          });
          await _fetchRoute();
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No saved location for $dest')),
          );
        }
      },
      onVehicleSelected: (vehicle) {
        setState(() {
          _selectedVehicle = vehicle;
        });
      },
      onConfirm: () {
        if (_destination == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a destination first')),
          );
          return;
        }

        // Create a real ride request in Firestore
        _createRideRequest();
      },
    );
  }

  Widget _buildTopFloatingUI() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Profile Pic
            GestureDetector(
              onTap: () {
                context.go('/profile');
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey[800]!, width: 2),
                ),
                child: const Icon(Icons.person, color: Colors.black, size: 24),
              ),
            ),
            // Gold Member Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E2630),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white12),
              ),
              child: const Row(
                children: [
                  Text(
                    'Gold Member',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.star, color: Colors.amber, size: 14),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Search Bar (Where to?)
        GestureDetector(
          onTap: () async {
            final result = await context.push('/search');
            if (result != null && result is PlaceResult) {
              setState(() {
                _destination = LatLng(result.lat, result.lng);
                _destinationAddress = result.address;
                _showVehicleSelection = true;
              });
              await _fetchRoute();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1C242E),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Color(0xFF2b8cee), size: 20),
                const SizedBox(width: 12),
                const Text(
                  'Where to?',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 1,
                  height: 24,
                  color: Colors.grey.withOpacity(0.3),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A3441),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.schedule, size: 14, color: Colors.white),
                      SizedBox(width: 4),
                      Text(
                        'Now',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 14,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showPaymentMethodPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Payment Method',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              ..._paymentMethods.map(
                (method) => ListTile(
                  leading: Icon(
                    method.type == PaymentType.cash
                        ? Icons.money
                        : Icons.credit_card,
                    color: Colors.black,
                  ),
                  title: Text(method.name),
                  trailing:
                      _selectedPaymentMethod == method
                          ? const Icon(Icons.check, color: Colors.green)
                          : null,
                  onTap: () {
                    setState(() => _selectedPaymentMethod = method);
                    Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.add, color: Colors.blue),
                title: const Text(
                  'Add Payment Method',
                  style: TextStyle(color: Colors.blue),
                ),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/wallet');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateCameraForDriver(LatLng driverPos) async {
    if (_currentLocation == null) return;

    final controller = await _controller.future;

    double minLat =
        _currentLocation!.latitude < driverPos.latitude
            ? _currentLocation!.latitude
            : driverPos.latitude;
    double maxLat =
        _currentLocation!.latitude > driverPos.latitude
            ? _currentLocation!.latitude
            : driverPos.latitude;
    double minLng =
        _currentLocation!.longitude < driverPos.longitude
            ? _currentLocation!.longitude
            : driverPos.longitude;
    double maxLng =
        _currentLocation!.longitude > driverPos.longitude
            ? _currentLocation!.longitude
            : driverPos.longitude;

    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        100.0,
      ),
    );
  }

  void _contactDriver(String scheme, String number) async {
    if (number.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Driver phone number not available')),
        );
      }
      return;
    }
    final Uri launchUri = Uri(scheme: scheme, path: number);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not launch app')));
      }
    }
  }

  void _resetState() {
    _rideRequestSubscription?.cancel();
    _rideRequestSubscription = null;
    _driverLocationSubscription?.cancel();
    _driverLocationSubscription = null;
    _rideTimeoutTimer?.cancel();
    _rideTimeoutTimer = null;
    setState(() {
      _polylines = {};
      _markers = {};
      _destination = null;
      _destinationAddress = '';
      _selectedVehicle = null;
      _showVehicleSelection = false;
      _isFindingDriver = false;
      _isDriverArriving = false;
      _isTripInProgress = false;
      _isTripCompleted = false;

      _activeRideRequestId = null;
      _activeRideRequest = null;
    });
    // Restore User Location Marker
    if (_currentLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('currentLocation'),
          position: _currentLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }
  }
}
