import 'package:cloud_firestore/cloud_firestore.dart';

class TripModel {
  final String id;
  final String driverId;
  final String userId;
  final DateTime date;
  final double cost;
  final String status; // 'completed', 'cancelled', 'in_progress'
  final String pickupAddress;
  final String dropoffAddress;
  final GeoPoint pickupLocation;
  final GeoPoint dropoffLocation;
  final double? rating;

  TripModel({
    required this.id,
    required this.driverId,
    required this.userId,
    required this.date,
    required this.cost,
    required this.status,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.pickupLocation,
    required this.dropoffLocation,
    this.rating,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      id: json['id'] as String,
      driverId: json['driverId'] as String,
      userId: json['userId'] as String,
      date: (json['date'] as Timestamp).toDate(),
      cost: (json['cost'] as num).toDouble(),
      status: json['status'] as String,
      pickupAddress: json['pickupAddress'] as String,
      dropoffAddress: json['dropoffAddress'] as String,
      pickupLocation: json['pickupLocation'] as GeoPoint,
      dropoffLocation: json['dropoffLocation'] as GeoPoint,
      rating:
          json['rating'] != null ? (json['rating'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'driverId': driverId,
      'userId': userId,
      'date': Timestamp.fromDate(date),
      'cost': cost,
      'status': status,
      'pickupAddress': pickupAddress,
      'dropoffAddress': dropoffAddress,
      'pickupLocation': pickupLocation,
      'dropoffLocation': dropoffLocation,
      'rating': rating,
    };
  }
}
