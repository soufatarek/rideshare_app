import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_verification_screen.dart';
import '../../features/auth/presentation/screens/registration_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/home/presentation/screens/destination_search_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/saved_places_screen.dart';
import '../../features/trips/presentation/screens/trips_screen.dart';
import '../../features/payment/presentation/screens/wallet_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/settings/presentation/screens/edit_profile_screen.dart';
import '../../features/settings/presentation/screens/privacy_screen.dart';
import '../../features/settings/presentation/screens/security_screen.dart';
import '../../features/settings/presentation/screens/notifications_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authProvider.notifier);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: GoRouterRefreshStream(authNotifier.stream),
    redirect: (context, state) {
      final authState = ref.read(authProvider);

      // Corrected Logic: Rely on app state, not just Firebase
      // If biometrics logging out, authState.user is NULL, identifying as Guest -> Redirect to Login

      final isLoggedIn = authState.user != null;
      final isLoggingIn =
          state.uri.toString() == '/' || state.uri.toString() == '/otp';
      final isRegistering = state.uri.toString() == '/register';

      if (isLoggedIn) {
        // We have a user profile loaded in state
        // Prevent accessing login/register pages
        if (isLoggingIn || isRegistering) {
          return '/home';
        }
      } else {
        // Not logged in (or Biometric "Locked")
        // Check if we need registration (valid firebase user but no profile)?
        // Actually authState.needsRegistration handles that.

        if (authState.needsRegistration) {
          if (!isRegistering) return '/register';
          return null;
        }

        // Force to login if not already there
        if (!isLoggingIn && !isRegistering) {
          return '/';
        }
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/otp',
        builder: (context, state) => const OtpVerificationScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegistrationScreen(),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/search',
        builder: (context, state) => const DestinationSearchScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(path: '/trips', builder: (context, state) => const TripsScreen()),
      GoRoute(
        path: '/saved-places',
        builder: (context, state) => const SavedPlacesScreen(),
      ),
      GoRoute(
        path: '/wallet',
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/privacy',
        builder: (context, state) => const PrivacyScreen(),
      ),
      GoRoute(
        path: '/security',
        builder: (context, state) => const SecurityScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
    ],
  );
});

// Helper class for Stream to Listenable conversion
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.listen((dynamic _) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
