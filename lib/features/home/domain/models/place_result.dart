class PlaceResult {
  final String address;
  final double lat;
  final double lng;

  PlaceResult({required this.address, required this.lat, required this.lng});

  @override
  String toString() => 'PlaceResult(address: $address, lat: $lat, lng: $lng)';
}
