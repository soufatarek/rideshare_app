import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' as math;
import 'package:flutter/services.dart';

import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/directions_service.dart';
import '../../domain/models/vehicle.dart';
import '../widgets/home_drawer.dart';
import '../widgets/sheets/where_to_sheet.dart';
import '../widgets/sheets/vehicle_selection_sheet.dart';
import '../widgets/sheets/finding_driver_sheet.dart';
import '../widgets/sheets/driver_arriving_sheet.dart';
import '../widgets/sheets/trip_in_progress_sheet.dart';
import '../widgets/sheets/trip_completed_sheet.dart';
import '../../domain/models/place_result.dart';
import '../../../../features/payment/domain/models/payment_method_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Completer<GoogleMapController> _controller = Completer();

  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(37.7749, -122.4194), // San Francisco (default)
    zoom: 14.4746,
  );

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Location state
  LatLng? _currentLocation;
  bool _isLoadingLocation = true;

  // Destination state
  LatLng? _destination;
  String _destinationAddress = '';
  double _distanceKm = 0;
  DirectionsResult? _routeInfo;

  // Map elements
  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  // State
  bool _showVehicleSelection = false;
  bool _isFindingDriver = false;
  bool _isDriverArriving = false;
  bool _isTripInProgress = false;
  bool _isTripCompleted = false;

  Vehicle? _selectedVehicle;

  // Mock data
  final List<Vehicle> _vehicles = const [
    Vehicle(
      id: '1',
      name: 'UberX',
      description: 'Affordable rides',
      price: 12.50,
      imageAsset: 'assets/images/uber_x.png',
      etaMinutes: 3,
    ),
    Vehicle(
      id: '2',
      name: 'Black',
      description: 'Luxury rides',
      price: 25.20,
      imageAsset: 'assets/images/uber_black.png',
      etaMinutes: 5,
    ),
    Vehicle(
      id: '3',
      name: 'UberXL',
      description: 'Larger rides',
      price: 18.50,
      imageAsset: 'assets/images/uber_xl.png',
      etaMinutes: 6,
    ),
  ];

  // Payment State
  final List<PaymentMethod> _paymentMethods = const [
    PaymentMethod(id: '1', name: 'Cash', type: PaymentType.cash),
    PaymentMethod(id: '2', name: 'Visa •••• 4242', type: PaymentType.card),
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
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _isLoadingLocation = false);
        return;
      }

      // Check permission
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

      // Get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });

      // Move camera to current location
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
        _routeInfo = result;
        _distanceKm = result.distanceKm;

        // Create polyline
        _polylines = {
          Polyline(
            polylineId: const PolylineId('route'),
            points: result.polylinePoints,
            color: Colors.blue,
            width: 5,
          ),
        };

        // Create markers
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

      // Fit map to show entire route
      final controller = await _controller.future;
      controller.animateCamera(CameraUpdate.newLatLngBounds(result.bounds, 80));
    }
  }

  @override
  Widget build(BuildContext context) {
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
      drawer: const HomeDrawer(),
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
              // Move to current location once map is ready
              if (_currentLocation != null) {
                _moveCameraToCurrentLocation();
              }
            },
          ),

          // Loading indicator for location
          if (_isLoadingLocation)
            const Center(child: CircularProgressIndicator()),

          // Custom Menu Button (Only show when not in specific flow or allow always?)
          // For simplicity, hide when selecting vehicles or in trip to focus user
          if (!_showVehicleSelection &&
              !_isFindingDriver &&
              !_isDriverArriving &&
              !_isTripInProgress &&
              !_isTripCompleted)
            Positioned(
              top: 50,
              left: 16,
              child: CircleAvatar(
                backgroundColor: Colors.white,
                radius: 24,
                child: IconButton(
                  icon: const Icon(Icons.menu, color: Colors.black),
                  onPressed: () {
                    _scaffoldKey.currentState?.openDrawer();
                  },
                ),
              ),
            ),

          // Back Button for Vehicle Selection
          if (_showVehicleSelection && !_isFindingDriver)
            Positioned(
              top: 50,
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

          // Custom Location Button
          Positioned(
            bottom: 340,
            right: 16,
            child: FloatingActionButton(
              mini: true,
              heroTag: 'myLocation',
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              onPressed: _moveCameraToCurrentLocation,
              child: const Icon(Icons.my_location),
            ),
          ),

          // Bottom Sheet Content
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomSheetContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheetContent() {
    if (_isTripCompleted) {
      return TripCompletedSheet(
        price: _selectedVehicle?.price ?? 0.0,
        onSubmitRating: (rating) {
          _resetState();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Rating submitted: $rating stars!')),
          );
        },
      );
    }

    if (_isTripInProgress) {
      return TripInProgressSheet(
        onPanic: () {
          // Handle emergency
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Emergency contact alerted')),
          );
        },
        onShareTrip: () {},
      );
    }

    if (_isDriverArriving) {
      return DriverArrivingSheet(
        onCall: () => _contactDriver('tel', '1234567890'),
        onMessage: () => _contactDriver('sms', '1234567890'),
        onCancel: () {
          _resetState();
        },
      );
    }

    if (_isFindingDriver) {
      return FindingDriverSheet(
        onCancel: () {
          setState(() {
            _isFindingDriver = false;
          });
        },
      );
    }

    if (_showVehicleSelection) {
      return VehicleSelectionSheet(
        vehicles: _vehicles,
        selectedVehicle: _selectedVehicle,
        distanceKm: _distanceKm,
        selectedPaymentMethod: _selectedPaymentMethod,
        onPaymentMethodTap: _showPaymentMethodPicker,
        onVehicleSelected: (vehicle) {
          setState(() {
            _selectedVehicle = vehicle;
          });
        },
        onConfirm: () {
          setState(() {
            _isFindingDriver = true;
          });

          // Simulation Logic
          // 1. Finding Driver (3s) -> Driver Arriving
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) {
              setState(() {
                _isFindingDriver = false;
                _isDriverArriving = true;
              });

              // Start Driver Animation
              _simulateDriverMovement();

              // 2. Driver Arriving (5s) -> Trip In Progress
              Future.delayed(const Duration(seconds: 5), () {
                if (mounted && _isDriverArriving) {
                  _driverTimer?.cancel(); // Stop animation
                  setState(() {
                    _isDriverArriving = false;
                    _isTripInProgress = true;
                    _markers.removeWhere(
                      (m) => m.markerId.value == 'driver',
                    ); // Remove driver marker

                    // Restore Destination Path
                    if (_routeInfo != null &&
                        _destination != null &&
                        _currentLocation != null) {
                      _polylines = {
                        Polyline(
                          polylineId: const PolylineId('route'),
                          points: _routeInfo!.polylinePoints,
                          color: Colors.blue,
                          width: 5,
                        ),
                      };
                      _markers.add(
                        Marker(
                          markerId: const MarkerId('origin'),
                          position: _currentLocation!,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueGreen,
                          ),
                          infoWindow: const InfoWindow(title: 'Pickup'),
                        ),
                      );
                      _markers.add(
                        Marker(
                          markerId: const MarkerId('destination'),
                          position: _destination!,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueRed,
                          ),
                          infoWindow: InfoWindow(title: _destinationAddress),
                        ),
                      );
                    }
                  });

                  // 3. Trip In Progress (10s) -> Trip Completed
                  Future.delayed(const Duration(seconds: 10), () {
                    if (mounted && _isTripInProgress) {
                      setState(() {
                        _isTripInProgress = false;
                        _isTripCompleted = true;
                      });
                    }
                  });
                }
              });

              // Apply Driver Path Logic (This runs immediately for Driver Arriving)
              // See _simulateDriverMovement for the actual updates
            }
          });
        },
      );
    }

    return WhereToSheet(
      onSearchTap: () async {
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

  Timer? _driverTimer;

  Future<void> _simulateDriverMovement() async {
    if (_currentLocation == null) return;

    // 1. Pick a random start point roughly 1km away
    // For simplicity, we just add 0.01 to lat/lng.
    // The Directions API will snap this to the nearest road.
    final startPos = LatLng(
      _currentLocation!.latitude + 0.008,
      _currentLocation!.longitude + 0.008,
    );

    // 2. Fetch real driving directions from Start -> User
    final directions = await DirectionsService.getDirections(
      origin: startPos,
      destination: _currentLocation!,
    );

    if (directions == null || directions.polylinePoints.isEmpty) {
      // Fallback if API fails
      return;
    }

    final points = directions.polylinePoints;
    int currentPointIndex = 0;

    // 3. Animate along the path
    // Update every 200ms

    // Draw the initial driver path (Driver -> User)
    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('driver_path'),
          points: points,
          color: Colors.grey, // Grey path for driver approach
          width: 4,
          jointType: JointType.round,
          patterns: [PatternItem.dash(10), PatternItem.gap(10)], // Dashed line
        ),
      };
    });

    _driverTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (currentPointIndex >= points.length - 1) {
        timer.cancel();
        return;
      }

      final currentPos = points[currentPointIndex];
      final nextPos = points[currentPointIndex + 1];

      // Calculate bearing for rotation
      final bearing = _calculateBearing(currentPos, nextPos);

      setState(() {
        _markers.removeWhere((m) => m.markerId.value == 'driver');
        _markers.add(
          Marker(
            markerId: const MarkerId('driver'),
            position: currentPos,
            icon:
                _driverIcon ??
                BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueViolet,
                ),
            // The icon likely faces Right (East), so we subtract 90 degrees to align with North (0)
            rotation: (bearing - 90),
            anchor: const Offset(0.5, 0.5),
            flat: true,
          ),
        );

        // Optional: Trim the polyline as driver moves?
        // For now, keeping the full path is fine, or we can slice 'points'
      });

      // Zoom camera to fit User + Driver
      // We throttle this to every 5 steps (1 second) to avoid jitter
      if (currentPointIndex % 5 == 0) {
        _updateCameraForDriver(currentPos);
      }

      currentPointIndex++;
    });
  }

  // Helper to calculate bearing between two points
  double _calculateBearing(LatLng start, LatLng end) {
    // Convert to radians
    final startLat = start.latitude * (3.141592653589793 / 180.0);
    final startLng = start.longitude * (3.141592653589793 / 180.0);
    final endLat = end.latitude * (3.141592653589793 / 180.0);
    final endLng = end.longitude * (3.141592653589793 / 180.0);

    final dLng = endLng - startLng;

    final y = math.sin(dLng) * math.cos(endLat);
    final x =
        math.cos(startLat) * math.sin(endLat) -
        math.sin(startLat) * math.cos(endLat) * math.cos(dLng);

    final toDeg = 180.0 / 3.141592653589793;
    final bearing = math.atan2(y, x) * toDeg;

    return (bearing + 360) % 360;
  }

  Future<void> _updateCameraForDriver(LatLng driverPos) async {
    if (_currentLocation == null) return;

    final controller = await _controller.future;

    // Calculate bounds
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
        100.0, // Padding
      ),
    );
  }

  void _contactDriver(String scheme, String number) async {
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
    _driverTimer?.cancel(); // Stop animation if running
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
      _routeInfo = null;
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
