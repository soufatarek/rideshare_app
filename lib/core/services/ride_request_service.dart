import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../features/home/domain/models/ride_request_model.dart';

class RideRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Collection reference
  CollectionReference get _rideRequests =>
      _firestore.collection('ride_requests');

  /// Create a new ride request with status 'searching'
  Future<String> createRideRequest({
    required String pickupAddress,
    required String dropoffAddress,
    required GeoPoint pickupLocation,
    required GeoPoint dropoffLocation,
    required String vehicleType,
    required double price,
    required String paymentMethod,
    required double distanceKm,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Fetch rider profile for name/phone
    final userDoc =
        await _firestore.collection('users').doc(user.uid).get();
    final userData = userDoc.data() ?? {};

    final riderName =
        '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
    final riderPhone = userData['phone'] as String? ?? '';

    final docRef = _rideRequests.doc();
    final request = RideRequest(
      id: docRef.id,
      riderId: user.uid,
      riderName: riderName.isNotEmpty ? riderName : 'Rider',
      riderPhone: riderPhone,
      status: 'searching',
      vehicleType: vehicleType,
      price: price,
      paymentMethod: paymentMethod,
      pickupAddress: pickupAddress,
      dropoffAddress: dropoffAddress,
      pickupLocation: pickupLocation,
      dropoffLocation: dropoffLocation,
      createdAt: DateTime.now(),
      distanceKm: distanceKm,
    );

    await docRef.set(request.toFirestore());
    return docRef.id;
  }

  /// Listen to a specific ride request for real-time updates
  Stream<RideRequest?> listenToRideRequest(String requestId) {
    return _rideRequests.doc(requestId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return RideRequest.fromFirestore(snapshot);
    });
  }

  /// Listen to driver location updates for a ride request
  Stream<GeoPoint?> listenToDriverLocation(String requestId) {
    return _rideRequests.doc(requestId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      final data = snapshot.data() as Map<String, dynamic>?;
      return data?['driverLocation'] as GeoPoint?;
    });
  }

  /// Cancel a ride request
  Future<void> cancelRideRequest(String requestId) async {
    await _rideRequests.doc(requestId).update({
      'status': 'cancelled',
    });
  }

  /// Submit a rating for a completed ride
  Future<void> submitRating(String requestId, double rating) async {
    await _rideRequests.doc(requestId).update({
      'rating': rating,
    });
  }

  /// Get the rider's active ride request (if any)
  Future<RideRequest?> getActiveRideRequest() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final query = await _rideRequests
        .where('riderId', isEqualTo: user.uid)
        .where('status', whereIn: [
          'searching',
          'accepted',
          'arriving',
          'in_progress',
        ])
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    return RideRequest.fromFirestore(query.docs.first);
  }
}
