import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/router.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize notification service
  await NotificationService().initialize();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  @override
  void initState() {
    super.initState();
    // Configure notification tap handler
    NotificationService().onNotificationTapped = _handleNotificationTap;
  }

  void _handleNotificationTap(
      NotificationType type, Map<String, dynamic> data) {
    switch (type) {
      case NotificationType.driverAssigned:
      case NotificationType.driverArriving:
      case NotificationType.tripStarted:
        // Navigate to home where trip status is shown
        // The home screen already listens for ride updates
        break;
      case NotificationType.tripCompleted:
        // Show rating dialog or navigate to trips
        break;
      case NotificationType.rideCancelled:
        // Show cancelled dialog
        break;
      case NotificationType.promotion:
        // Navigate to promotions
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'RideShare App',
      theme: AppTheme.darkTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
