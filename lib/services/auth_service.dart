import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';

class AuthService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    await _db.collection('drivers').doc(cred.user!.uid).set({
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    return cred;
  }

  Future<UserCredential> loginWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<Map<String, dynamic>> loginWithPhone({
    required String phone,
    required String password,
  }) async {
    try {
      // 🛑 CRITICAL: We MUST sign in anonymously to have a 'request.auth'
      // object for your Firestore rules to allow the lookup.
      if (_auth.currentUser == null) {
        debugPrint(
          "AuthService: No user signed in. Attempting anonymous sign-in...",
        );
        await _auth.signInAnonymously();
        debugPrint(
          "AuthService: Anonymous sign-in successful. UID: ${_auth.currentUser?.uid}",
        );
      }

      final ph = phone.trim();
      debugPrint("AuthService: Fetching phone_index for '$ph'...");
      final phoneSnap = await _db
          .collection('driver_phone_index')
          .doc(ph)
          .get();
      if (!phoneSnap.exists) {
        return {'success': false, 'error': 'Phone number not found'};
      }

      final uid = phoneSnap.data()?['uid'];
      final userSnap = await _db.collection('drivers').doc(uid).get();
      if (!userSnap.exists) {
        return {'success': false, 'error': 'User data not found'};
      }

      final data = userSnap.data()!;
      final bool approved = data['approved'] ?? false;
      if (!approved) {
        return {'success': false, 'error': 'Your account is pending approval.'};
      }

      final String storedHash = data['passwordHash'] ?? '';
      final String currentHash = sha256
          .convert(utf8.encode("$uid:$password"))
          .toString();

      if (storedHash != currentHash) {
        return {'success': false, 'error': 'Invalid password'};
      }

      // If approved and password matches, we can optionally sign them in with a custom token
      // or just return success if we are using custom auth logic.
      // For now, returning success as requested for the test.
      return {'success': true, 'uid': uid, 'userData': data};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Save FCM token after successful login
  Future<void> saveFCMToken(String driverId) async {
    try {
      final token = await DriverNotificationService().getToken();
      if (token != null) {
        await _db.collection('drivers').doc(driverId).update({
          'fcmToken': token,
          'lastTokenUpdate': FieldValue.serverTimestamp(),
        });
        // Subscribe to driver-specific topic
        await DriverNotificationService().subscribeToDriverTopics(driverId);
        debugPrint('Driver FCM token saved successfully');
      }
    } catch (e) {
      debugPrint('Failed to save driver FCM token: $e');
    }
  }

  /// Remove FCM token on logout
  Future<void> removeFCMToken(String driverId) async {
    try {
      await _db.collection('drivers').doc(driverId).update({
        'fcmToken': FieldValue.delete(),
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
      await DriverNotificationService().unsubscribeFromTopics(driverId);
      await DriverNotificationService().deleteToken();
      debugPrint('Driver FCM token removed successfully');
    } catch (e) {
      debugPrint('Failed to remove driver FCM token: $e');
    }
  }

  /// Sign out and clean up
  Future<void> signOut(String driverId) async {
    await removeFCMToken(driverId);
    await _auth.signOut();
  }
}
