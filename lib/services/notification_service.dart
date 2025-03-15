import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:plateforme_services/config/constants.dart';
import 'dart:convert';
import '/config/constants.dart';

class NotificationService {
  static final _firebaseMessaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    await _setupFirebase();
    await _setupLocalNotifications();
    await _setupInteractedMessage();
  }

  static Future<void> _setupFirebase() async {
    await _firebaseMessaging.requestPermission();
    final token = await _firebaseMessaging.getToken();
    if (token != null) await _saveDeviceToken(token);
  }

  static Future<void> _setupLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings),
    );
  }

  static Future<void> _setupInteractedMessage() async {
    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) _handleMessage(initialMessage);

    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
    FirebaseMessaging.onMessage.listen((message) => _showLocalNotification(message));
  }

  static void _handleMessage(RemoteMessage message) {
    // Gérer la navigation lors du clic sur notification
  }

  static Future<void> _saveDeviceToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'deviceTokens': FieldValue.arrayUnion([token])
      });
    }
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final android = message.notification?.android;

    if (notification != null && android != null) {
      const androidDetails = AndroidNotificationDetails(
        'messages_channel', 'Messages',
        channelDescription: 'Notifications de messages',
        importance: Importance.max,
        priority: Priority.high,
      );

      await _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(android: androidDetails),
        payload: jsonEncode(message.data),
      );
    }
  }

  static Future<void> sendPushNotification({
    required String receiverId,
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(receiverId).get();
    final tokens = List<String>.from(userDoc['deviceTokens'] ?? []);

    for (final token in tokens) {
      await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Authorization': 'key=${AppConstants.fcmServerKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'to': token,
          'notification': {'title': title, 'body': body},
          'data': data,
          'android': {
            'priority': 'high',
            'notification': {'channel_id': 'messages_channel'}
          }
        }),
      );
    }
  }
}