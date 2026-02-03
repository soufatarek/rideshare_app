import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/place_model.dart';

class PlacesRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get Saved Places
  Stream<List<PlaceModel>> getSavedPlaces(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('saved_places')
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => PlaceModel.fromJson(doc.data()))
              .toList();
        });
  }

  // Add Saved Place
  Future<void> addSavedPlace(String userId, PlaceModel place) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('saved_places')
        .doc(place.id)
        .set(place.toJson());
  }

  // Delete Saved Place
  Future<void> deleteSavedPlace(String userId, String placeId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('saved_places')
        .doc(placeId)
        .delete();
  }
}
