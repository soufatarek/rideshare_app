import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../features/home/domain/models/ride_request_model.dart';

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Handling background message: ${message.messageId}');
  debugPrint('Title: ${message.notification?.title}');
  debugPrint('Body: ${message.notification?.body}');
  debugPrint('Data: ${message.data}');
}

/// Notification types
enum NotificationType {
  driverAssigned,
  driverArriving,
  tripStarted,
  tripCompleted,
  rideCancelled,
  promotion,
  unknown;

  static NotificationType fromString(String? value) {
    switch (value) {
      case 'driver_assigned':
        return NotificationType.driverAssigned;
      case 'driver_arriving':
        return NotificationType.driverArriving;
      case 'trip_started':
        return NotificationType.tripStarted;
      case 'trip_completed':
        return NotificationType.tripCompleted;
      case 'ride_cancelled':
        return NotificationType.rideCancelled;
      case 'promotion':
        return NotificationType.promotion;
      default:
        return NotificationType.unknown;
    }
  }
}

/// Notification service for handling FCM
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Callback for when notification is tapped
  Function(NotificationType, Map<String, dynamic>)? onNotificationTapped;

  bool _isInitialized = false;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Request permissions
    await _requestPermissions();

    // Initialize local notifications
    await _initLocalNotifications();

    // Set up foreground message handler
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Set up background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Set up notification tap handler
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Get initial message (if app was opened from terminated state)
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    _isInitialized = true;
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('Notification permission status: ${settings.authorizationStatus}');
  }

  /// Initialize local notifications
  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          final data = jsonDecode(response.payload!) as Map<String, dynamic>;
          final type = NotificationType.fromString(data['type'] as String?);
          onNotificationTapped?.call(type, data);
        }
      },
    );

    // Create notification channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'rideshare_channel',
      'RideShare Notifications',
      description: 'Notifications for ride status updates',
      importance: Importance.high,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Get FCM token for this device
  Future<String?> getToken() async {
    return await _firebaseMessaging.getToken();
  }

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    await _firebaseMessaging.subscribeToTopic(topic);
    debugPrint('Subscribed to topic: $topic');
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _firebaseMessaging.unsubscribeFromTopic(topic);
    debugPrint('Unsubscribed from topic: $topic');
  }

  /// Handle foreground messages (show local notification)
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Received foreground message');
    debugPrint('Title: ${message.notification?.title}');
    debugPrint('Body: ${message.notification?.body}');

    final notification = message.notification;
    final data = message.data;

    if (notification != null) {
      await _showLocalNotification(
        title: notification.title ?? 'RideShare',
        body: notification.body ?? '',
        payload: jsonEncode(data),
      );
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'rideshare_channel',
      'RideShare Notifications',
      channelDescription: 'Notifications for ride status updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecond,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Handle notification tap
  void _handleNotificationTap(RemoteMessage message) {
    final type = NotificationType.fromString(message.data['type'] as String?);
    onNotificationTapped?.call(type, message.data);
  }

  /// Save FCM token to user profile (call after login)
  Future<void> saveTokenToProfile(String userId) async {
    final token = await getToken();
    if (token != null) {
      // Token should be saved to Firestore via user repository
      debugPrint('FCM Token: $token');
    }
  }

  /// Show custom notification for ride status
  Future<void> showRideStatusNotification(RideRequest rideRequest) async {
    String title;
    String body;

    switch (rideRequest.status) {
      case 'accepted':
        title = 'Driver Assigned';
        body = '${rideRequest.driverName} is your driver. They will arrive soon.';
        break;
      case 'arriving':
        title = 'Driver Arriving';
        body = '${rideRequest.driverName} has arrived at your pickup location.';
        break;
      case 'in_progress':
        title = 'Trip Started';
        body = 'Your trip has started. Enjoy your ride!';
        break;
      case 'completed':
        title = 'Trip Completed';
        body = 'You have arrived at your destination. Thanks for riding with us!';
        break;
      case 'cancelled':
        title = 'Ride Cancelled';
        body = 'Your ride has been cancelled.';
        break;
      default:
        return;
    }

    await _showLocalNotification(
      title: title,
      body: body,
      payload: jsonEncode({
        'type': rideRequest.status,
        'rideRequestId': rideRequest.id,
      }),
    );
  }

  /// Delete FCM token (call on logout)
  Future<void> deleteToken() async {
    await _firebaseMessaging.deleteToken();
    debugPrint('FCM token deleted');
  }
}
