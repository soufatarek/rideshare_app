import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/trip_model.dart';

class TripRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get trips for a specific user
  Future<List<TripModel>> getTrips(String userId) async {
    try {
      final querySnapshot =
          await _firestore
              .collection('trips')
              .where('userId', isEqualTo: userId)
              .orderBy('date', descending: true)
              .get();

      return querySnapshot.docs
          .map((doc) => TripModel.fromJson(doc.data()))
          .toList();
    } catch (e) {
      print('Error fetching trips: $e');
      return [];
    }
  }

  // Create a new trip (for testing/future use)
  Future<void> createTrip(TripModel trip) async {
    await _firestore.collection('trips').doc(trip.id).set(trip.toJson());
  }

  // Update trip rating
  Future<void> updateTripRating(String tripId, double rating) async {
    await _firestore.collection('trips').doc(tripId).update({'rating': rating});
  }
}
