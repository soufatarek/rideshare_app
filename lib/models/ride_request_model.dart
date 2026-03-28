import 'package:cloud_firestore/cloud_firestore.dart';

/// Status flow: searching → accepted → arriving → in_progress → completed
/// Alternative endings: cancelled (by rider), declined (by driver)
class RideRequest {
  final String id;
  final String riderId;
  final String riderName;
  final String riderPhone;
  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final String? driverCarModel;
  final String? driverCarPlate;
  final String status;
  final String vehicleType;
  final double price;
  final String paymentMethod;
  final String pickupAddress;
  final String dropoffAddress;
  final GeoPoint pickupLocation;
  final GeoPoint dropoffLocation;
  final GeoPoint? driverLocation;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final double? rating;
  final double distanceKm;

  const RideRequest({
    required this.id,
    required this.riderId,
    required this.riderName,
    required this.riderPhone,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.driverCarModel,
    this.driverCarPlate,
    required this.status,
    required this.vehicleType,
    required this.price,
    required this.paymentMethod,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.pickupLocation,
    required this.dropoffLocation,
    this.driverLocation,
    required this.createdAt,
    this.acceptedAt,
    this.completedAt,
    this.rating,
    required this.distanceKm,
  });

  factory RideRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RideRequest(
      id: doc.id,
      riderId: data['riderId'] as String,
      riderName: data['riderName'] as String? ?? '',
      riderPhone: data['riderPhone'] as String? ?? '',
      driverId: data['driverId'] as String?,
      driverName: data['driverName'] as String?,
      driverPhone: data['driverPhone'] as String?,
      driverCarModel: data['driverCarModel'] as String?,
      driverCarPlate: data['driverCarPlate'] as String?,
      status: data['status'] as String? ?? 'searching',
      vehicleType: data['vehicleType'] as String? ?? 'Economy',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: data['paymentMethod'] as String? ?? 'Cash',
      pickupAddress: data['pickupAddress'] as String? ?? '',
      dropoffAddress: data['dropoffAddress'] as String? ?? '',
      pickupLocation: data['pickupLocation'] as GeoPoint,
      dropoffLocation: data['dropoffLocation'] as GeoPoint,
      driverLocation: data['driverLocation'] as GeoPoint?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      acceptedAt: (data['acceptedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      rating: (data['rating'] as num?)?.toDouble(),
      distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'riderId': riderId,
      'riderName': riderName,
      'riderPhone': riderPhone,
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'driverCarModel': driverCarModel,
      'driverCarPlate': driverCarPlate,
      'status': status,
      'vehicleType': vehicleType,
      'price': price,
      'paymentMethod': paymentMethod,
      'pickupAddress': pickupAddress,
      'dropoffAddress': dropoffAddress,
      'pickupLocation': pickupLocation,
      'dropoffLocation': dropoffLocation,
      'driverLocation': driverLocation,
      'createdAt': Timestamp.fromDate(createdAt),
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'rating': rating,
      'distanceKm': distanceKm,
    };
  }

  /// Convert to JSON for serialization (used in notifications)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'riderId': riderId,
      'riderName': riderName,
      'riderPhone': riderPhone,
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'driverCarModel': driverCarModel,
      'driverCarPlate': driverCarPlate,
      'status': status,
      'vehicleType': vehicleType,
      'price': price,
      'paymentMethod': paymentMethod,
      'pickupAddress': pickupAddress,
      'dropoffAddress': dropoffAddress,
      'pickupLocation': {
        'latitude': pickupLocation.latitude,
        'longitude': pickupLocation.longitude,
      },
      'dropoffLocation': {
        'latitude': dropoffLocation.latitude,
        'longitude': dropoffLocation.longitude,
      },
      'driverLocation': driverLocation != null
          ? {
              'latitude': driverLocation!.latitude,
              'longitude': driverLocation!.longitude,
            }
          : null,
      'createdAt': createdAt.toIso8601String(),
      'acceptedAt': acceptedAt?.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'rating': rating,
      'distanceKm': distanceKm,
    };
  }

  /// Create from JSON (used in notifications)
  factory RideRequest.fromJson(Map<String, dynamic> json) {
    return RideRequest(
      id: json['id'] as String,
      riderId: json['riderId'] as String,
      riderName: json['riderName'] as String? ?? '',
      riderPhone: json['riderPhone'] as String? ?? '',
      driverId: json['driverId'] as String?,
      driverName: json['driverName'] as String?,
      driverPhone: json['driverPhone'] as String?,
      driverCarModel: json['driverCarModel'] as String?,
      driverCarPlate: json['driverCarPlate'] as String?,
      status: json['status'] as String? ?? 'searching',
      vehicleType: json['vehicleType'] as String? ?? 'Economy',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['paymentMethod'] as String? ?? 'Cash',
      pickupAddress: json['pickupAddress'] as String? ?? '',
      dropoffAddress: json['dropoffAddress'] as String? ?? '',
      pickupLocation: _geoPointFromJson(json['pickupLocation']),
      dropoffLocation: _geoPointFromJson(json['dropoffLocation']),
      driverLocation: json['driverLocation'] != null
          ? _geoPointFromJson(json['driverLocation'])
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      acceptedAt: json['acceptedAt'] != null
          ? DateTime.parse(json['acceptedAt'] as String)
          : null,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      rating: (json['rating'] as num?)?.toDouble(),
      distanceKm: (json['distanceKm'] as num?)?.toDouble() ?? 0.0,
    );
  }

  static GeoPoint _geoPointFromJson(dynamic json) {
    if (json is Map<String, dynamic>) {
      return GeoPoint(
        (json['latitude'] as num).toDouble(),
        (json['longitude'] as num).toDouble(),
      );
    }
    return const GeoPoint(0, 0);
  }

  /// Whether the ride request is in an active state
  bool get isActive =>
      status == 'searching' ||
      status == 'accepted' ||
      status == 'arriving' ||
      status == 'in_progress';
}
