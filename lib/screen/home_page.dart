import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/ride_request_service.dart';
import '../services/driver_location_service.dart';
import '../services/notification_service.dart';
import '../models/ride_request_model.dart';
import 'trip_history_page.dart';

class HomePage extends StatefulWidget {
  final String driverId;
  final Map<String, dynamic> driverData;

  const HomePage({
    super.key,
    required this.driverId,
    required this.driverData,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final Completer<GoogleMapController> _mapController = Completer();
  final RideRequestService _rideRequestService = RideRequestService();
  final DriverLocationService _locationService = DriverLocationService();

  // Driver state
  bool _isOnline = false;
  LatLng? _currentLocation;
  bool _isLoadingLocation = true;

  // Ride state
  RideRequest? _currentRide;
  String? _activeRideId;
  StreamSubscription? _rideRequestsSubscription;
  StreamSubscription? _activeRideSubscription;

  // Incoming requests queue
  List<RideRequest> _incomingRequests = [];

  // Map elements
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  // Trip state
  // 'idle' | 'incoming' | 'navigating_to_pickup' | 'at_pickup' | 'in_progress' | 'completed'
  String _tripState = 'idle';

  // Earnings from Firestore
  double _todayEarnings = 0.0;
  int _todayTrips = 0;
  StreamSubscription? _earningsSubscription;

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _setupNotifications();
    _streamEarnings();
  }

  /// Stream real-time earnings from Firestore
  void _streamEarnings() {
    _earningsSubscription = FirebaseFirestore.instance
        .collection('drivers')
        .doc(widget.driverId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      final data = snapshot.data();
      if (data != null) {
        setState(() {
          _todayEarnings = (data['totalEarnings'] as num?)?.toDouble() ?? 0.0;
          _todayTrips = (data['totalTrips'] as num?)?.toInt() ?? 0;
        });
      }
    });
  }

  void _setupNotifications() {
    // Set up notification callbacks
    DriverNotificationService().onNewRideRequest = (RideRequest request) {
      // Show notification when app is in foreground
      DriverNotificationService().showNewRideRequestNotification(request);
    };

    DriverNotificationService().onNotificationTapped = (type, data) {
      switch (type) {
        case DriverNotificationType.newRideRequest:
          // Already handled by the stream listener
          break;
        case DriverNotificationType.rideCancelled:
          // Handle ride cancelled notification tap
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ride was cancelled by passenger')),
            );
          }
          break;
        default:
          break;
      }
    };
  }

  @override
  void dispose() {
    _rideRequestsSubscription?.cancel();
    _activeRideSubscription?.cancel();
    _earningsSubscription?.cancel();
    _locationService.stopLocationUpdates();
    // Set driver offline when leaving the page
    if (_isOnline) {
      _rideRequestService.setDriverOffline(widget.driverId);
    }
    // Clear notification callbacks
    DriverNotificationService().onNewRideRequest = null;
    DriverNotificationService().onNotificationTapped = null;
    super.dispose();
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
    final controller = await _mapController.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: _currentLocation!, zoom: 15),
      ),
    );
  }

  /// Toggle online/offline status
  Future<void> _toggleOnline() async {
    if (_isOnline) {
      // Go offline
      await _rideRequestService.setDriverOffline(widget.driverId);
      await _locationService.stopLocationUpdates();
      _rideRequestsSubscription?.cancel();
      _rideRequestsSubscription = null;
      setState(() {
        _isOnline = false;
        _incomingRequests = [];
        _tripState = 'idle';
      });
    } else {
      // Go online
      final location = await _locationService.getCurrentLocation();
      if (location != null) {
        await _rideRequestService.setDriverOnline(widget.driverId, location);
        await _locationService.startLocationUpdates(
          driverId: widget.driverId,
        );
        
        // Save FCM Token for Push Notifications
        final token = await DriverNotificationService().getToken();
        if (token != null) {
          try {
            await FirebaseFirestore.instance
                .collection('drivers')
                .doc(widget.driverId)
                .update({'fcmToken': token});
          } catch (e) {
            debugPrint('Failed to save FCM token: $e');
          }
        }
        // Subscribe to drivers topic for broadcast ride requests
        await DriverNotificationService().subscribeToDriverTopics(widget.driverId);

        _startListeningForRequests();
        setState(() {
          _isOnline = true;
          _currentLocation = LatLng(location.latitude, location.longitude);
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not get location. Please enable GPS.'),
            ),
          );
        }
      }
    }
  }

  /// Start listening for incoming ride requests
  void _startListeningForRequests() {
    _rideRequestsSubscription?.cancel();
    _rideRequestsSubscription =
        _rideRequestService.listenForRideRequests(excludeDriverId: widget.driverId).listen((requests) {
      if (!mounted) return;
      setState(() {
        _incomingRequests = requests;
      });

      // Show the first request if we're idle
      if (_tripState == 'idle' && requests.isNotEmpty) {
        setState(() {
          _tripState = 'incoming';
        });
      }
    });
  }

  /// Accept a ride request
  Future<void> _acceptRide(RideRequest request) async {
    try {
      final driverName =
          '${widget.driverData['firstName'] ?? ''} ${widget.driverData['lastName'] ?? ''}'
              .trim();

      await _rideRequestService.acceptRideRequest(
        requestId: request.id,
        driverId: widget.driverId,
        driverName: driverName.isNotEmpty ? driverName : 'Driver',
        driverPhone: widget.driverData['phone'] ?? '',
        driverCarModel: widget.driverData['carModel'] ?? 'Car',
        driverCarPlate: widget.driverData['carPlate'] ?? 'N/A',
      );

      _activeRideId = request.id;
      _locationService.setActiveRideRequest(request.id);

      // Stop listening for new requests — we have a ride
      _rideRequestsSubscription?.cancel();

      // Listen to this specific ride for status updates
      _listenToActiveRide(request.id);

      setState(() {
        _currentRide = request;
        _tripState = 'navigating_to_pickup';
        _incomingRequests = [];
      });

      // Show pickup location on map
      _showPickupOnMap(request);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accepting ride: $e')),
        );
      }
    }
  }

  /// Decline a ride request — persist to Firestore so it won't re-show
  void _declineRide(RideRequest request) {
    _rideRequestService.declineRideRequest(request.id, widget.driverId);
    setState(() {
      _incomingRequests.removeWhere((r) => r.id == request.id);
      if (_incomingRequests.isEmpty) {
        _tripState = 'idle';
      }
    });
  }

  /// Listen to the accepted ride for status changes (e.g., rider cancels)
  void _listenToActiveRide(String rideId) {
    _activeRideSubscription?.cancel();
    _activeRideSubscription =
        _rideRequestService.listenToRideRequest(rideId).listen((ride) {
      if (!mounted) return;
      if (ride == null) return;

      setState(() {
        _currentRide = ride;
      });

      if (ride.status == 'cancelled') {
        // Rider cancelled the ride
        _handleRideCancelled();
      }
    });
  }

  /// Handle when rider cancels the ride
  void _handleRideCancelled() {
    _activeRideSubscription?.cancel();
    _activeRideSubscription = null;
    _locationService.setActiveRideRequest(null);

    setState(() {
      _currentRide = null;
      _activeRideId = null;
      _tripState = 'idle';
      _markers = {};
      _polylines = {};
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rider cancelled the trip')),
      );
    }

    // Resume listening for new requests
    if (_isOnline) {
      _startListeningForRequests();
    }
  }

  /// Show pickup location marker on map
  void _showPickupOnMap(RideRequest request) {
    setState(() {
      _markers = {
        if (_currentLocation != null)
          Marker(
            markerId: const MarkerId('driver'),
            position: _currentLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueBlue,
            ),
            infoWindow: const InfoWindow(title: 'You'),
          ),
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(
            request.pickupLocation.latitude,
            request.pickupLocation.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(title: 'Pickup: ${request.pickupAddress}'),
        ),
      };
    });

    // Fit the camera to show both points
    _fitMapToBounds();
  }

  /// Show dropoff location marker on map
  void _showDropoffOnMap(RideRequest request) {
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(
            request.pickupLocation.latitude,
            request.pickupLocation.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: const InfoWindow(title: 'Pickup'),
        ),
        Marker(
          markerId: const MarkerId('dropoff'),
          position: LatLng(
            request.dropoffLocation.latitude,
            request.dropoffLocation.longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRed,
          ),
          infoWindow: InfoWindow(title: 'Dropoff: ${request.dropoffAddress}'),
        ),
      };
    });

    _fitMapToBounds();
  }

  Future<void> _fitMapToBounds() async {
    if (_markers.length < 2) return;

    final positions = _markers.map((m) => m.position).toList();
    double minLat = positions.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
    double maxLat = positions.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
    double minLng = positions.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
    double maxLng = positions.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);

    final controller = await _mapController.future;
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

  /// Mark as arrived at pickup and update status to 'arriving'
  Future<void> _arrivedAtPickup() async {
    if (_activeRideId == null) return;
    await _rideRequestService.updateRideStatus(_activeRideId!, 'arriving');
    setState(() {
      _tripState = 'at_pickup';
    });
  }

  /// Start the trip — rider is in the car
  Future<void> _startTrip() async {
    if (_activeRideId == null || _currentRide == null) return;
    await _rideRequestService.updateRideStatus(_activeRideId!, 'in_progress');
    setState(() {
      _tripState = 'in_progress';
    });
    // Show route from pickup to dropoff
    _showDropoffOnMap(_currentRide!);
  }

  /// Complete the trip
  Future<void> _completeTrip() async {
    if (_activeRideId == null) return;
    await _rideRequestService.updateRideStatus(_activeRideId!, 'completed');

    // Update earnings
    setState(() {
      _tripState = 'completed';
      _todayEarnings += _currentRide?.price ?? 0.0;
      _todayTrips += 1;
    });
  }

  /// Dismiss completion view and return to idle
  void _dismissCompletion() {
    _activeRideSubscription?.cancel();
    _activeRideSubscription = null;
    _locationService.setActiveRideRequest(null);

    setState(() {
      _currentRide = null;
      _activeRideId = null;
      _tripState = 'idle';
      _markers = {};
      _polylines = {};
    });

    // Resume listening for new requests
    if (_isOnline) {
      _startListeningForRequests();
    }
  }

  /// Call the rider
  void _callRider() async {
    final phone = _currentRide?.riderPhone ?? '';
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rider phone not available')),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  /// Navigate to pickup/dropoff using external maps app
  void _navigateToLocation(double lat, double lng) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Google Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentLocation ?? const LatLng(37.7749, -122.4194),
              zoom: 15,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            markers: _markers,
            polylines: _polylines,
            onMapCreated: (controller) {
              _mapController.complete(controller);
              if (_currentLocation != null) {
                _moveCameraToCurrentLocation();
              }
            },
          ),

          // Loading indicator
          if (_isLoadingLocation)
            const Center(child: CircularProgressIndicator()),

          // Top bar with status and logout
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: _buildTopBar(),
          ),

          // Center location button
          Positioned(
            top: MediaQuery.of(context).padding.top + 70,
            right: 16,
            child: FloatingActionButton.small(
              heroTag: 'location',
              backgroundColor: Theme.of(context).cardColor,
              onPressed: _moveCameraToCurrentLocation,
              child: Icon(
                Icons.my_location,
                color: Theme.of(context).iconTheme.color,
              ),
            ),
          ),

          // Bottom content based on state
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomContent(),
          ),

          // Incoming ride request overlay
          if (_tripState == 'incoming' && _incomingRequests.isNotEmpty)
            _buildIncomingRequestOverlay(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C242E),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          // Online status dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: _isOnline ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _isOnline ? 'Online' : 'Offline',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          // Earnings badge
          if (_todayTrips > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'EGP ${_todayEarnings.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Trip history button
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TripHistoryPage(driverId: widget.driverId),
                ),
              );
            },
            icon: const Icon(Icons.history, color: Colors.white70, size: 20),
            tooltip: 'Trip History',
          ),
          // Logout button
          IconButton(
            onPressed: () async {
              try {
                // Go offline first
                if (_isOnline) {
                  await _rideRequestService.setDriverOffline(widget.driverId);
                  await _locationService.stopLocationUpdates();
                }
                // Clear FCM token from Firestore
                await FirebaseFirestore.instance
                    .collection('drivers')
                    .doc(widget.driverId)
                    .update({'fcmToken': FieldValue.delete()});
                // Delete device FCM token
                await DriverNotificationService().deleteToken();
                // Unsubscribe from topics
                await DriverNotificationService().unsubscribeFromTopics(widget.driverId);
              } catch (e) {
                debugPrint('Error during logout cleanup: $e');
              }
              await FirebaseAuth.instance.signOut();
              if (context.mounted) Navigator.pop(context);
            },
            icon: const Icon(Icons.logout, color: Colors.white70, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomContent() {
    switch (_tripState) {
      case 'navigating_to_pickup':
      case 'at_pickup':
        return _buildNavigatingToPickupSheet();
      case 'in_progress':
        return _buildTripInProgressSheet();
      case 'completed':
        return _buildTripCompletedSheet();
      default:
        return _buildIdleSheet();
    }
  }

  /// Idle state — online/offline toggle and stats
  Widget _buildIdleSheet() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1C242E),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Go Online / Go Offline Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _toggleOnline,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _isOnline ? Colors.red[700] : Colors.green[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_isOnline ? Icons.pause_circle : Icons.play_circle),
                  const SizedBox(width: 12),
                  Text(
                    _isOnline ? 'Go Offline' : 'Go Online',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Today's summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                Icons.attach_money,
                'EGP ${_todayEarnings.toStringAsFixed(0)}',
                'Earnings',
              ),
              _buildStatItem(
                Icons.directions_car,
                '$_todayTrips',
                'Trips',
              ),
              _buildStatItem(
                Icons.access_time,
                _isOnline ? 'Active' : 'Off',
                'Status',
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }

  /// Incoming ride request overlay
  Widget _buildIncomingRequestOverlay() {
    final request = _incomingRequests.first;
    return Positioned.fill(
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1C242E),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                const Icon(
                  Icons.local_taxi,
                  color: Colors.amber,
                  size: 48,
                ),
                const SizedBox(height: 12),
                const Text(
                  'New Ride Request!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // Rider info
                _buildInfoRow(Icons.person, 'Rider', request.riderName),
                _buildInfoRow(
                  Icons.my_location,
                  'Pickup',
                  request.pickupAddress,
                ),
                _buildInfoRow(
                  Icons.flag,
                  'Dropoff',
                  request.dropoffAddress,
                ),
                _buildInfoRow(
                  Icons.straighten,
                  'Distance',
                  '${request.distanceKm.toStringAsFixed(1)} km',
                ),

                const SizedBox(height: 16),

                // Price
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'EGP ${request.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Accept / Decline buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _declineRide(request),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Decline',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => _acceptRide(request),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Accept',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue[300], size: 20),
          const SizedBox(width: 12),
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// Navigating to pickup sheet
  Widget _buildNavigatingToPickupSheet() {
    final ride = _currentRide;
    if (ride == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1C242E),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.navigation,
                  color: Colors.greenAccent,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tripState == 'at_pickup'
                          ? 'Waiting for Rider'
                          : 'Navigate to Pickup',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      ride.pickupAddress,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Rider info row
          Row(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: Colors.blueGrey,
                child: Icon(Icons.person, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ride.riderName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${ride.vehicleType} · EGP ${ride.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Call rider button
              IconButton(
                onPressed: _callRider,
                icon: const Icon(Icons.phone, color: Colors.greenAccent),
              ),
              // Navigate button
              IconButton(
                onPressed: () => _navigateToLocation(
                  ride.pickupLocation.latitude,
                  ride.pickupLocation.longitude,
                ),
                icon: const Icon(Icons.directions, color: Colors.blue),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Action button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed:
                  _tripState == 'at_pickup' ? _startTrip : _arrivedAtPickup,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _tripState == 'at_pickup'
                        ? Colors.blue[700]
                        : Colors.green[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                _tripState == 'at_pickup'
                    ? 'Start Trip'
                    : 'Arrived at Pickup',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Trip in progress sheet — driving to dropoff
  Widget _buildTripInProgressSheet() {
    final ride = _currentRide;
    if (ride == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1C242E),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.directions_car,
                  color: Colors.blue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Trip in Progress',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Heading to: ${ride.dropoffAddress}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Navigate to dropoff
              IconButton(
                onPressed: () => _navigateToLocation(
                  ride.dropoffLocation.latitude,
                  ride.dropoffLocation.longitude,
                ),
                icon: const Icon(Icons.directions, color: Colors.blue),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Price and distance info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                Icons.attach_money,
                'EGP ${ride.price.toStringAsFixed(0)}',
                'Fare',
              ),
              _buildStatItem(
                Icons.straighten,
                '${ride.distanceKm.toStringAsFixed(1)} km',
                'Distance',
              ),
              _buildStatItem(
                Icons.payments,
                ride.paymentMethod,
                'Payment',
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Complete trip button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _completeTrip,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Complete Trip',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Trip completed sheet — earnings summary
  Widget _buildTripCompletedSheet() {
    final ride = _currentRide;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1C242E),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle,
            color: Colors.greenAccent,
            size: 56,
          ),
          const SizedBox(height: 12),
          const Text(
            'Trip Completed!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You earned EGP ${ride?.price.toStringAsFixed(0) ?? '0'}',
            style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Rider: ${ride?.riderName ?? 'Unknown'}',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Today's total
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  Icons.attach_money,
                  'EGP ${_todayEarnings.toStringAsFixed(0)}',
                  'Today Total',
                ),
                _buildStatItem(
                  Icons.directions_car,
                  '$_todayTrips',
                  'Trips Today',
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _dismissCompletion,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Continue Driving',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
