import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service for handling Polar.sh payment integration via Firebase Cloud Functions.
///
/// All sensitive API keys and tokens are stored server-side in Cloud Functions.
/// The client only calls callable functions — no secrets are exposed.
class PolarService {
  static final _functions = FirebaseFunctions.instance;

  // ── Checkout Session ───────────────────────────────────────────

  /// Creates a Polar.sh checkout session for the given ride fare.
  ///
  /// Calls the `createPolarCheckout` Cloud Function, which handles
  /// the Polar API interaction server-side and stores a payment
  /// record in Firestore.
  ///
  /// Returns the checkout URL, or `null` on failure.
  static Future<String?> createCheckoutSession({
    required double amount,
    required String rideId,
    String currency = 'usd',
  }) async {
    try {
      final result = await _functions
          .httpsCallable('createPolarCheckout')
          .call<Map<String, dynamic>>({
        'amount': amount,
        'rideId': rideId,
        'currency': currency,
      });

      return result.data['checkoutUrl'] as String?;
    } catch (e) {
      debugPrint('Polar checkout error: $e');
      return null;
    }
  }

  /// Opens the Polar.sh checkout URL in the device browser.
  static Future<bool> launchCheckout(String checkoutUrl) async {
    final uri = Uri.parse(checkoutUrl);
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  // ── Payment Verification ───────────────────────────────────────

  /// Verifies a payment was successfully completed for a given ride.
  ///
  /// Calls the `verifyPolarPayment` Cloud Function which checks
  /// Polar's order API and updates the Firestore payment record.
  static Future<bool> verifyPayment(String rideId) async {
    try {
      final result = await _functions
          .httpsCallable('verifyPolarPayment')
          .call<Map<String, dynamic>>({
        'rideId': rideId,
      });

      return result.data['paid'] as bool? ?? false;
    } catch (e) {
      debugPrint('Polar verify error: $e');
      return false;
    }
  }

  // ── Refund ─────────────────────────────────────────────────────

  /// Requests a refund for a completed Polar payment.
  ///
  /// Calls the `requestPolarRefund` Cloud Function.
  static Future<bool> requestRefund({
    required String orderId,
    String reason = 'Ride cancelled',
  }) async {
    try {
      final result = await _functions
          .httpsCallable('requestPolarRefund')
          .call<Map<String, dynamic>>({
        'orderId': orderId,
        'reason': reason,
      });

      return result.data['success'] as bool? ?? false;
    } catch (e) {
      debugPrint('Polar refund error: $e');
      return false;
    }
  }
}
