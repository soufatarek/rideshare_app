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

  RideRequest copyWith({
    String? id,
    String? riderId,
    String? riderName,
    String? riderPhone,
    String? driverId,
    String? driverName,
    String? driverPhone,
    String? driverCarModel,
    String? driverCarPlate,
    String? status,
    String? vehicleType,
    double? price,
    String? paymentMethod,
    String? pickupAddress,
    String? dropoffAddress,
    GeoPoint? pickupLocation,
    GeoPoint? dropoffLocation,
    GeoPoint? driverLocation,
    DateTime? createdAt,
    DateTime? acceptedAt,
    DateTime? completedAt,
    double? rating,
    double? distanceKm,
  }) {
    return RideRequest(
      id: id ?? this.id,
      riderId: riderId ?? this.riderId,
      riderName: riderName ?? this.riderName,
      riderPhone: riderPhone ?? this.riderPhone,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      driverCarModel: driverCarModel ?? this.driverCarModel,
      driverCarPlate: driverCarPlate ?? this.driverCarPlate,
      status: status ?? this.status,
      vehicleType: vehicleType ?? this.vehicleType,
      price: price ?? this.price,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      dropoffAddress: dropoffAddress ?? this.dropoffAddress,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      dropoffLocation: dropoffLocation ?? this.dropoffLocation,
      driverLocation: driverLocation ?? this.driverLocation,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      completedAt: completedAt ?? this.completedAt,
      rating: rating ?? this.rating,
      distanceKm: distanceKm ?? this.distanceKm,
    );
  }

  /// Whether the ride request is in an active state
  bool get isActive =>
      status == 'searching' ||
      status == 'accepted' ||
      status == 'arriving' ||
      status == 'in_progress';
}
