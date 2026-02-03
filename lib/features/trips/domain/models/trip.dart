class Trip {
  final String id;
  final String date;
  final String time;
  final String pickupAddress;
  final String destinationAddress;
  final double price;
  final String carModel;
  final String carPlate;
  final String status; // 'completed', 'cancelled'
  final double? rating;

  const Trip({
    required this.id,
    required this.date,
    required this.time,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.price,
    required this.carModel,
    required this.carPlate,
    required this.status,
    this.rating,
  });
}
