import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'ride_request_service.dart';

class DriverLocationService {
  final RideRequestService _rideRequestService = RideRequestService();
  StreamSubscription<Position>? _locationSubscription;
  String? _activeRideRequestId;
  String? _driverId;

  /// Start streaming location updates
  /// Updates both the ride request doc and driver_status doc
  Future<void> startLocationUpdates({
    required String driverId,
    String? rideRequestId,
  }) async {
    _driverId = driverId;
    _activeRideRequestId = rideRequestId;

    // Request permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('DriverLocationService: Location permission denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint(
          'DriverLocationService: Location permission permanently denied');
      return;
    }

    // Cancel any existing subscription
    await stopLocationUpdates();

    // Start listening to position changes
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((Position position) {
      final geoPoint = GeoPoint(position.latitude, position.longitude);

      // Update ride request doc (if active trip)
      if (_activeRideRequestId != null) {
        _rideRequestService.updateDriverLocation(
          _activeRideRequestId!,
          geoPoint,
        );
      }

      // Update driver_status doc (always when online)
      if (_driverId != null) {
        _rideRequestService.updateDriverStatusLocation(
          _driverId!,
          geoPoint,
        );
      }
    });
  }

  /// Update the active ride request ID (e.g., when accepting a new ride)
  void setActiveRideRequest(String? rideRequestId) {
    _activeRideRequestId = rideRequestId;
  }

  /// Stop streaming location updates
  Future<void> stopLocationUpdates() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;
  }

  /// Get current position as GeoPoint
  Future<GeoPoint?> getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return GeoPoint(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('DriverLocationService: Error getting location: $e');
      return null;
    }
  }
}
