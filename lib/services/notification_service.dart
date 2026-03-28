import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../models/ride_request_model.dart';

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> driverFirebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Driver background message handler triggered');
  debugPrint('Title: ${message.notification?.title}');
  debugPrint('Body: ${message.notification?.body}');
  debugPrint('Data: ${message.data}');

  // For driver app, show critical notifications even in background
  final notification = message.notification;
  if (notification != null) {
    final FlutterLocalNotificationsPlugin localNotifications =
        FlutterLocalNotificationsPlugin();

    await localNotifications.show(
      DateTime.now().millisecond,
      notification.title ?? 'New Ride Request',
      notification.body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'driver_rideshare_channel',
          'Driver Notifications',
          channelDescription: 'Ride requests and updates',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: RawResourceAndroidNotificationSound('notification_sound'),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }
}

/// Notification types for driver
enum DriverNotificationType {
  newRideRequest,
  rideCancelled,
  passengerMessage,
  dailySummary,
  systemUpdate,
  unknown;

  static DriverNotificationType fromString(String? value) {
    switch (value) {
      case 'new_ride_request':
        return DriverNotificationType.newRideRequest;
      case 'ride_cancelled':
        return DriverNotificationType.rideCancelled;
      case 'passenger_message':
        return DriverNotificationType.passengerMessage;
      case 'daily_summary':
        return DriverNotificationType.dailySummary;
      case 'system_update':
        return DriverNotificationType.systemUpdate;
      default:
        return DriverNotificationType.unknown;
    }
  }
}

/// Notification service for driver app
class DriverNotificationService {
  static final DriverNotificationService _instance = DriverNotificationService._internal();
  factory DriverNotificationService() => _instance;
  DriverNotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // Callbacks
  Function(DriverNotificationType, Map<String, dynamic>)? onNotificationTapped;
  Function(RideRequest)? onNewRideRequest;

  bool _isInitialized = false;

  /// Initialize notification service
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Request permissions with critical alert for drivers
    await _requestPermissions();

    // Initialize local notifications
    await _initLocalNotifications();

    // Set up foreground message handler
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Set up background handler
    FirebaseMessaging.onBackgroundMessage(driverFirebaseMessagingBackgroundHandler);

    // Set up notification tap handler
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Get initial message
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
      criticalAlert: true, // For drivers, critical alerts are important
    );

    debugPrint('Driver notification permission: ${settings.authorizationStatus}');

    // Also request permissions for local notifications
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Initialize local notifications
  Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
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
          final type = DriverNotificationType.fromString(data['type'] as String?);
          onNotificationTapped?.call(type, data);
        }
      },
    );

    // Create notification channels for Android
    const AndroidNotificationChannel rideRequestChannel =
        AndroidNotificationChannel(
      'driver_ride_requests',
      'Ride Requests',
      description: 'Incoming ride requests',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    const AndroidNotificationChannel generalChannel =
        AndroidNotificationChannel(
      'driver_general',
      'General Notifications',
      description: 'General updates and alerts',
      importance: Importance.high,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(rideRequestChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(generalChannel);
  }

  /// Get FCM token
  Future<String?> getToken() async {
    return await _firebaseMessaging.getToken();
  }

  /// Subscribe to topics
  Future<void> subscribeToDriverTopics(String driverId) async {
    await _firebaseMessaging.subscribeToTopic('drivers');
    await _firebaseMessaging.subscribeToTopic('driver_$driverId');
    debugPrint('Driver subscribed to topics');
  }

  /// Unsubscribe from topics
  Future<void> unsubscribeFromTopics(String driverId) async {
    await _firebaseMessaging.unsubscribeFromTopic('drivers');
    await _firebaseMessaging.unsubscribeFromTopic('driver_$driverId');
  }

  /// Handle foreground messages
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Driver received foreground message');

    final notification = message.notification;
    final data = message.data;
    final type = DriverNotificationType.fromString(data['type'] as String?);

    // For new ride requests, trigger immediate callback
    if (type == DriverNotificationType.newRideRequest && data.containsKey('ride_request')) {
      try {
        final rideRequest = RideRequest.fromJson(
          jsonDecode(data['ride_request']) as Map<String, dynamic>,
        );
        onNewRideRequest?.call(rideRequest);
      } catch (e) {
        debugPrint('Error parsing ride request from notification: $e');
      }
    }

    if (notification != null) {
      await _showLocalNotification(
        title: notification.title ?? 'RideShare Driver',
        body: notification.body ?? '',
        payload: jsonEncode(data),
        isRideRequest: type == DriverNotificationType.newRideRequest,
      );
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
    bool isRideRequest = false,
  }) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      isRideRequest ? 'driver_ride_requests' : 'driver_general',
      isRideRequest ? 'Ride Requests' : 'General Notifications',
      channelDescription: isRideRequest
          ? 'Incoming ride requests'
          : 'General updates and alerts',
      importance: isRideRequest ? Importance.max : Importance.high,
      priority: isRideRequest ? Priority.max : Priority.high,
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

    final NotificationDetails details = NotificationDetails(
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
    final type = DriverNotificationType.fromString(message.data['type'] as String?);
    onNotificationTapped?.call(type, message.data);
  }

  /// Show notification for new ride request
  Future<void> showNewRideRequestNotification(RideRequest request) async {
    await _showLocalNotification(
      title: '🚗 New Ride Request!',
      body: 'Pickup: ${request.pickupAddress} → Dropoff: ${request.dropoffAddress}\n'
          'Fare: \$${request.price.toStringAsFixed(2)}',
      payload: jsonEncode({
        'type': 'new_ride_request',
        'ride_request': request.toJson(),
      }),
      isRideRequest: true,
    );
  }

  /// Show ride cancelled notification
  Future<void> showRideCancelledNotification(String rideId, String reason) async {
    await _showLocalNotification(
      title: 'Ride Cancelled',
      body: 'The passenger has cancelled the ride. ${reason.isNotEmpty ? 'Reason: $reason' : ''}',
      payload: jsonEncode({
        'type': 'ride_cancelled',
        'rideId': rideId,
        'reason': reason,
      }),
    );
  }

  /// Save FCM token to driver profile
  Future<void> saveTokenToProfile(String driverId) async {
    final token = await getToken();
    if (token != null) {
      debugPrint('Driver FCM Token: $token');
      // This should be saved to Firestore via driver repository
    }
  }

  /// Delete FCM token (call on logout)
  Future<void> deleteToken() async {
    await _firebaseMessaging.deleteToken();
    debugPrint('Driver FCM token deleted');
  }

  /// Configure foreground notification presentation options
  Future<void> configureForegroundPresentation() async {
    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  }
}
