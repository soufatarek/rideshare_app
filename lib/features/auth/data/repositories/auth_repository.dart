import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/user_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthRepository {
  static final AuthRepository _instance = AuthRepository._internal();
  factory AuthRepository() => _instance;
  AuthRepository._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _verificationId;

  // Cache for user existence check
  bool? _cachedUserExists;

  // Stream of auth state changes
  Stream<User?> get authStateChanges {
    return _auth.authStateChanges().map((user) {
      if (user == null) {
        _cachedUserExists = null; // Reset cache on logout
      }
      return user;
    });
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Check if user profile exists
  Future<bool> checkUserExists() async {
    if (_cachedUserExists != null) return _cachedUserExists!;

    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      _cachedUserExists = doc.exists;
      if (doc.exists) {
        _updateFcmToken(user.uid);
      }
      return doc.exists;
    } catch (e) {
      print('Error checking user profile: $e');
      // If error (e.g. Permission Denied), return false to avoid crash
      // This will redirect to Registration, which might also fail, but it shows UI.
      return false;
    }
  }

  // Create User Profile
  Future<void> createUserProfile(UserModel userModel) async {
    await _firestore
        .collection('users')
        .doc(userModel.id)
        .set(userModel.toJson());
    _cachedUserExists = true;
  }

  // Get User Profile
  Future<UserModel?> getUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists && doc.data() != null) {
        _updateFcmToken(user.uid);
        return UserModel.fromJson(doc.data()!);
      }
    } catch (e) {
      print('Error fetching user profile: $e');
    }
    return null;
  }

  // Verify Phone Number
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String) onCodeSent,
    required Function(String) onVerificationFailed,
    required Function() onCodeAutoRetrievalTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        // Auto-resolution (Android only sometimes)
        await _auth.signInWithCredential(credential);
      },
      verificationFailed: (FirebaseAuthException e) {
        onVerificationFailed(e.message ?? 'Verification failed');
      },
      codeSent: (String verificationId, int? resendToken) {
        _verificationId = verificationId;
        onCodeSent(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
        onCodeAutoRetrievalTimeout();
      },
      timeout: const Duration(seconds: 60),
    );
  }

  // Verify OTP and Sign In
  Future<void> verifyOtp(String smsCode) async {
    if (_verificationId == null) {
      throw Exception('Verification ID is missing. Request code first.');
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: smsCode,
    );

    await _auth.signInWithCredential(credential);
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Clear FCM token from Firestore
        await _firestore.collection('users').doc(user.uid).update({
          'fcmToken': FieldValue.delete(),
        });
        // Delete the device FCM token
        await FirebaseMessaging.instance.deleteToken();
      }
    } catch (e) {
      print('Error clearing FCM token on logout: $e');
    }
    _cachedUserExists = null;
    await _auth.signOut();
  }

  // Update FCM Token
  Future<void> _updateFcmToken(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(uid).update({
          'fcmToken': token,
        });
      }
    } catch (e) {
      print('Error updating user FCM token: $e');
    }
  }
}
