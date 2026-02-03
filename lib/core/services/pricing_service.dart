import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Pricing rates for different vehicle types in EGP (Egyptian Pounds)
class VehiclePricing {
  final String vehicleId;
  final double baseFare; // EGP
  final double perKmRate; // EGP per kilometer
  final double perMinuteRate; // EGP per minute

  const VehiclePricing({
    required this.vehicleId,
    required this.baseFare,
    required this.perKmRate,
    required this.perMinuteRate,
  });
}

class PricingService {
  // Pricing in EGP (Egyptian Pounds)
  static const Map<String, VehiclePricing> vehiclePricingMap = {
    '1': VehiclePricing(
      vehicleId: '1',
      baseFare: 15.0, // 15 EGP base
      perKmRate: 5.0, // 5 EGP per km
      perMinuteRate: 0.5, // 0.5 EGP per minute
    ),
    '2': VehiclePricing(
      vehicleId: '2',
      baseFare: 30.0, // 30 EGP base (Black/Luxury)
      perKmRate: 12.0, // 12 EGP per km
      perMinuteRate: 1.0,
    ),
    '3': VehiclePricing(
      vehicleId: '3',
      baseFare: 20.0, // 20 EGP base (XL)
      perKmRate: 7.0, // 7 EGP per km
      perMinuteRate: 0.7,
    ),
  };

  /// Calculate distance between two points in kilometers
  static double calculateDistanceKm(LatLng origin, LatLng destination) {
    final distanceInMeters = Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );
    return distanceInMeters / 1000; // Convert to km
  }

  /// Estimate trip time in minutes (rough estimate: 2 min per km in city)
  static int estimateTripMinutes(double distanceKm) {
    // Assume average speed of 30 km/h in city traffic
    return (distanceKm * 2).ceil();
  }

  /// Calculate price for a vehicle type based on distance
  static double calculatePrice(String vehicleId, double distanceKm) {
    final pricing = vehiclePricingMap[vehicleId];
    if (pricing == null) return 0.0;

    final tripMinutes = estimateTripMinutes(distanceKm);

    final fare =
        pricing.baseFare +
        (pricing.perKmRate * distanceKm) +
        (pricing.perMinuteRate * tripMinutes);

    // Round to nearest whole number for EGP
    return fare.roundToDouble();
  }

  /// Format price as EGP string
  static String formatPrice(double price) {
    return 'EGP ${price.toStringAsFixed(0)}';
  }
}
