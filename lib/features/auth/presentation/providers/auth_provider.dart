import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/repositories/auth_repository.dart';
import '../../domain/models/user_model.dart';

// Auth State
class AuthState {
  final bool isLoading;
  final String? error;
  final bool isCodeSent;
  final bool needsRegistration;
  final UserModel? user;

  AuthState({
    this.isLoading = false,
    this.error,
    this.isCodeSent = false,
    this.needsRegistration = false,
    this.user,
  });

  AuthState copyWith({
    bool? isLoading,
    String? error,
    bool? isCodeSent,
    bool? needsRegistration,
    UserModel? user,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isCodeSent: isCodeSent ?? this.isCodeSent,
      needsRegistration: needsRegistration ?? this.needsRegistration,
      user: user ?? this.user,
    );
  }
}

// Auth Repository Provider
final authRepositoryProvider = Provider((ref) => AuthRepository());

// Auth Controller Provider
final authProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.read(authRepositoryProvider));
});

class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthController(this._repository) : super(AuthState()) {
    checkCurrentUser();
  }

  Future<void> checkCurrentUser() async {
    final user = _repository.currentUser;
    if (user != null) {
      await fetchUserProfile();
    }
  }

  Future<void> fetchUserProfile() async {
    try {
      final user = await _repository.getUserProfile();
      if (mounted) {
        state = state.copyWith(user: user);
      }
    } catch (e) {
      // Silent fail or log
      print('Failed to fetch user profile: $e');
    }
  }

  Future<void> verifyPhone(String phoneNumber) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      await _repository.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        onCodeSent: (verificationId) {
          state = state.copyWith(isLoading: false, isCodeSent: true);
        },
        onVerificationFailed: (errorMessage) {
          state = state.copyWith(isLoading: false, error: errorMessage);
        },
        onCodeAutoRetrievalTimeout: () {
          // Handle timeout if needed
        },
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> verifyOtp(String smsCode) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _repository.verifyOtp(smsCode);

      // Check if user exists
      final exists = await _repository.checkUserExists();
      state = state.copyWith(isLoading: false, needsRegistration: !exists);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> createProfile(
    String firstName,
    String lastName,
    String email,
  ) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = _repository.currentUser;
      if (user == null) throw Exception('No authenticated user');

      final userModel = UserModel(
        id: user.uid,
        phoneNumber: user.phoneNumber ?? '',
        firstName: firstName,
        lastName: lastName,
        email: email,
        createdAt: DateTime.now(),
      );

      await _repository.createUserProfile(userModel);
      state = state.copyWith(
        isLoading: false,
        needsRegistration: false,
        user: userModel,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    final biometricEnabled = prefs.getBool('biometric_enabled') ?? false;

    // Only sign out from Firebase if biometrics are disabled
    if (!biometricEnabled) {
      await _repository.signOut();
    }
    state = AuthState(); // Reset local state
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled', enabled);
  }

  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('biometric_enabled') ?? false;
  }

  // Biometrics
  Future<bool> authenticateWithBiometrics() async {
    final LocalAuthentication auth = LocalAuthentication();
    try {
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate =
          canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (!canAuthenticate) {
        return false;
      }

      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Please authenticate to login',
        options: const AuthenticationOptions(biometricOnly: false),
      );

      if (didAuthenticate) {
        // Restore user session
        state = state.copyWith(isLoading: true);
        await checkCurrentUser(); // Fetch user from existing session
        state = state.copyWith(isLoading: false);
      }

      return didAuthenticate;
    } catch (e) {
      print('Biometric error: $e');
      return false;
    }
  }
}
