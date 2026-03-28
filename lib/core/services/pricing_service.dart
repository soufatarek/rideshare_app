import 'package:cloud_functions/cloud_functions.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Pricing rates for different vehicle types in EGP (Egyptian Pounds)
/// Used as local fallback only — the server calculates the real price.
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

/// Server price estimate result
class PriceEstimate {
  final double estimatedPrice;
  final double baseFare;
  final double surgeMultiplier;
  final String currency;

  const PriceEstimate({
    required this.estimatedPrice,
    required this.baseFare,
    required this.surgeMultiplier,
    this.currency = 'EGP',
  });

  bool get hasSurge => surgeMultiplier > 1.0;

  String get surgeLabel => '${surgeMultiplier}×';
}

class PricingService {
  // Local fallback pricing in EGP (Egyptian Pounds)
  static const Map<String, VehiclePricing> vehiclePricingMap = {
    '1': VehiclePricing(
      vehicleId: '1',
      baseFare: 15.0,
      perKmRate: 5.0,
      perMinuteRate: 0.5,
    ),
    '2': VehiclePricing(
      vehicleId: '2',
      baseFare: 30.0,
      perKmRate: 12.0,
      perMinuteRate: 1.0,
    ),
    '3': VehiclePricing(
      vehicleId: '3',
      baseFare: 20.0,
      perKmRate: 7.0,
      perMinuteRate: 0.7,
    ),
  };

  /// Fetch server-side price estimate (calls Cloud Function)
  static Future<PriceEstimate> fetchServerPrice(
    String vehicleType,
    double distanceKm,
  ) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'getEstimatedPrice',
      );
      final result = await callable.call<Map<String, dynamic>>({
        'vehicleType': vehicleType,
        'distanceKm': distanceKm,
      });

      final data = result.data;
      return PriceEstimate(
        estimatedPrice: (data['estimatedPrice'] as num).toDouble(),
        baseFare: (data['baseFare'] as num).toDouble(),
        surgeMultiplier: (data['surgeMultiplier'] as num).toDouble(),
        currency: data['currency'] as String? ?? 'EGP',
      );
    } catch (e) {
      // Fallback to local calculation if server is unavailable
      final localPrice = calculatePrice(vehicleType, distanceKm);
      return PriceEstimate(
        estimatedPrice: localPrice,
        baseFare: localPrice,
        surgeMultiplier: 1.0,
      );
    }
  }

  /// Calculate distance between two points in kilometers
  static double calculateDistanceKm(LatLng origin, LatLng destination) {
    final distanceInMeters = Geolocator.distanceBetween(
      origin.latitude,
      origin.longitude,
      destination.latitude,
      destination.longitude,
    );
    return distanceInMeters / 1000;
  }

  /// Estimate trip time in minutes (rough: 2 min per km in city)
  static int estimateTripMinutes(double distanceKm) {
    return (distanceKm * 2).ceil();
  }

  /// Local price calculation (fallback only)
  static double calculatePrice(String vehicleId, double distanceKm) {
    final pricing = vehiclePricingMap[vehicleId];
    if (pricing == null) return 0.0;

    final tripMinutes = estimateTripMinutes(distanceKm);

    final fare =
        pricing.baseFare +
        (pricing.perKmRate * distanceKm) +
        (pricing.perMinuteRate * tripMinutes);

    return fare.roundToDouble();
  }

  /// Format price as EGP string
  static String formatPrice(double price) {
    return 'EGP ${price.toStringAsFixed(0)}';
  }
}
