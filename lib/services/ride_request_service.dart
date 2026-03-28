import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/ride_request_model.dart';

class RideRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Collection reference
  CollectionReference get _rideRequests =>
      _firestore.collection('ride_requests');

  /// Listen for ride requests with status 'searching', excluding ones this driver declined
  Stream<List<RideRequest>> listenForRideRequests({String? excludeDriverId}) {
    return _rideRequests
        .where('status', isEqualTo: 'searching')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final allRequests = snapshot.docs
          .map((doc) => RideRequest.fromFirestore(doc))
          .toList();

      // Client-side filter: exclude requests this driver already declined
      if (excludeDriverId != null) {
        return allRequests.where((req) {
          final data = snapshot.docs
              .firstWhere((d) => d.id == req.id)
              .data() as Map<String, dynamic>;
          final declinedBy = List<String>.from(data['declinedBy'] ?? []);
          return !declinedBy.contains(excludeDriverId);
        }).toList();
      }

      return allRequests;
    });
  }

  /// Listen to a specific ride request for updates
  Stream<RideRequest?> listenToRideRequest(String requestId) {
    return _rideRequests.doc(requestId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return RideRequest.fromFirestore(snapshot);
    });
  }

  /// Accept a ride request — assign driver info and change status to 'accepted'
  Future<void> acceptRideRequest({
    required String requestId,
    required String driverId,
    required String driverName,
    required String driverPhone,
    required String driverCarModel,
    required String driverCarPlate,
  }) async {
    await _rideRequests.doc(requestId).update({
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'driverCarModel': driverCarModel,
      'driverCarPlate': driverCarPlate,
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Decline a ride request — track driver in declinedBy array
  Future<void> declineRideRequest(String requestId, String driverId) async {
    await _rideRequests.doc(requestId).update({
      'declinedBy': FieldValue.arrayUnion([driverId]),
    });
  }

  /// Update driver location in the ride request document
  Future<void> updateDriverLocation(
    String requestId,
    GeoPoint location,
  ) async {
    await _rideRequests.doc(requestId).update({
      'driverLocation': location,
    });
  }

  /// Update ride request status (arriving, in_progress, completed)
  Future<void> updateRideStatus(String requestId, String status) async {
    final Map<String, dynamic> updateData = {'status': status};

    if (status == 'completed') {
      updateData['completedAt'] = FieldValue.serverTimestamp();
    }

    await _rideRequests.doc(requestId).update(updateData);
  }

  /// Set driver as online in the driver_status collection
  Future<void> setDriverOnline(String driverId, GeoPoint location) async {
    await _firestore.collection('driver_status').doc(driverId).set({
      'isOnline': true,
      'location': location,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  /// Set driver as offline
  Future<void> setDriverOffline(String driverId) async {
    await _firestore.collection('driver_status').doc(driverId).update({
      'isOnline': false,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  /// Update driver location in driver_status
  Future<void> updateDriverStatusLocation(
    String driverId,
    GeoPoint location,
  ) async {
    await _firestore.collection('driver_status').doc(driverId).update({
      'location': location,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }

  /// Get the driver's current active ride (if any)
  Future<RideRequest?> getActiveRideForDriver(String driverId) async {
    final query = await _rideRequests
        .where('driverId', isEqualTo: driverId)
        .where('status', whereIn: [
          'accepted',
          'arriving',
          'in_progress',
        ])
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return RideRequest.fromFirestore(query.docs.first);
  }
}
