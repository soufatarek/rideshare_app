import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// Service to fetch driving directions and decode polylines
class DirectionsService {
  static const String _apiKey = 'AIzaSyCnMEavjs7z_wLKztyeHm2Vkfx-r1AmLRk';
  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/directions/json';

  /// Fetch route between origin and destination
  /// Returns a list of LatLng points for the polyline
  static Future<DirectionsResult?> getDirections({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final url =
        '$_baseUrl?'
        'origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&mode=driving'
        '&key=$_apiKey';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final overviewPolyline = route['overview_polyline']['points'];
          final bounds = route['bounds'];
          final legs = route['legs'][0];

          return DirectionsResult(
            polylinePoints: _decodePolyline(overviewPolyline),
            distanceText: legs['distance']['text'],
            distanceMeters: legs['distance']['value'],
            durationText: legs['duration']['text'],
            durationSeconds: legs['duration']['value'],
            bounds: LatLngBounds(
              southwest: LatLng(
                bounds['southwest']['lat'].toDouble(),
                bounds['southwest']['lng'].toDouble(),
              ),
              northeast: LatLng(
                bounds['northeast']['lat'].toDouble(),
                bounds['northeast']['lng'].toDouble(),
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error fetching directions: $e');
    }
    return null;
  }

  /// Decode Google's encoded polyline algorithm
  static List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      // Decode latitude
      int shift = 0;
      int result = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      // Decode longitude
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }
}

/// Result from directions API
class DirectionsResult {
  final List<LatLng> polylinePoints;
  final String distanceText;
  final int distanceMeters;
  final String durationText;
  final int durationSeconds;
  final LatLngBounds bounds;

  DirectionsResult({
    required this.polylinePoints,
    required this.distanceText,
    required this.distanceMeters,
    required this.durationText,
    required this.durationSeconds,
    required this.bounds,
  });

  /// Get distance in kilometers
  double get distanceKm => distanceMeters / 1000;
}
