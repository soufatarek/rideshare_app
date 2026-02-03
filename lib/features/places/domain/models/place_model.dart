import 'package:cloud_firestore/cloud_firestore.dart';

class PlaceModel {
  final String id;
  final String name; // 'Home', 'Work', 'Gym'
  final String address;
  final GeoPoint location;

  PlaceModel({
    required this.id,
    required this.name,
    required this.address,
    required this.location,
  });

  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    return PlaceModel(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      location: json['location'] as GeoPoint,
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'address': address, 'location': location};
  }
}
