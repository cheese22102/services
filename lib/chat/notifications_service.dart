import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;
import 'package:plateforme_services/chat/chat_screen.dart';
import 'package:plateforme_services/main.dart';
import 'chat_screen.dart';

class NotificationsService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Canal de notification pour les messages (son par défaut)
  static const AndroidNotificationChannel _messageChannel = AndroidNotificationChannel(
    'message_channel', 
    'New Message Notifications', 
    description: 'This channel is used for notifications about new messages.',
    importance: Importance.max,
    playSound: true,
  );

  static Future<void> initialize() async {
    // Demande de permissions
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    // Add this to your existing notification service initialization method:
    
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          // Extract chatroomId from payload
          final chatroomId = response.payload;
          if (chatroomId != null && chatroomId.isNotEmpty) {
            // Extract parts from chatroomId (format: user1_user2_postId)
            final parts = chatroomId.split('_');
            if (parts.length >= 3) {
              final postId = parts[2];
              final currentUserId = FirebaseAuth.instance.currentUser!.uid;
              final otherUserId = parts[0] == currentUserId ? parts[1] : parts[0];
              
              // Fetch user name before navigation
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(otherUserId)
                  .get()
                  .then((doc) {
                final userData = doc.data();
                final userName = userData != null 
                    ? '${userData['firstname'] ?? ''} ${userData['lastname'] ?? ''}'.trim()
                    : 'User';
                    
                navigatorKey.currentState?.push(
                  MaterialPageRoute(
                    builder: (context) => ChatScreenPage(
                      otherUserId: otherUserId,
                      postId: postId,
                      otherUserName: userName.isEmpty ? 'User' : userName,
                    ),
                  ),
                );
              });
            }
          }
        }
      },
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_messageChannel);

    // Gérer les messages en arrière-plan
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Écouter les messages au premier plan
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _showNotification(message);
      }
    });

    // Sauvegarde du token FCM dans Firestore
    String? token = await _firebaseMessaging.getToken();
    print(token);
    if (token != null) {
      _saveFCMToken(token);
    }
    _firebaseMessaging.onTokenRefresh.listen(_saveFCMToken);
  }

  // Add these methods to your existing NotificationsService class
  
  // Save notification to Firestore when received
  static Future<void> _saveNotificationToFirestore(RemoteMessage message) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .add({
          'title': message.notification?.title ?? 'Nouvelle notification',
          'body': message.notification?.body ?? '',
          'type': message.data['type'] ?? 'message',
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
          'data': message.data,
        });
  }

  // Update the _showNotification method to also save to Firestore
  static Future<void> _showNotification(RemoteMessage message) async {
    // Save to Firestore first
    await _saveNotificationToFirestore(message);
    
    // Then show local notification as before
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'message_channel',
        'New Message Notifications',
        importance: Importance.max,
        priority: Priority.high,
      ),
    );
    
    await _flutterLocalNotificationsPlugin.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      notificationDetails,
      payload: message.data['chatroomId'],
    );
  }

  // Also update the background handler to save notifications
  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    print("Background message: ${message.messageId}");
    await _saveNotificationToFirestore(message);
  }

  static Future<void> _saveFCMToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'fcmToken': token});
    }
  }

  /// Envoie une notification push via l’API Firebase Cloud Messaging V1.
  /// Veillez à ne pas exposer vos clés sensibles dans le dépôt public.
  static Future<void> sendMessageNotification({
    required String receiverId,
    required String messageText,
    required String senderName,
    required String chatroomId,
  }) async {
    // Get the receiver's FCM token
    final receiverDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(receiverId)
        .get();

    final receiverToken = receiverDoc.data()?['fcmToken'];
    if (receiverToken == null) return;

    // Get current user ID (sender)
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      // Save notification to receiver's collection in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(receiverId) // Save to receiver's notifications
          .collection('notifications')
          .add({
            'title': 'Nouveau message de $senderName',
            'body': messageText,
            'type': 'message',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
            'data': {
              'chatroomId': chatroomId,
              'senderId': currentUserId, // Store sender's ID
            },
          });

      // Send FCM notification only to the receiver
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=l0is7Wyv1K3tjFOdkRJSf5gbJknpw-ouGdeYJt2UjgM', // Replace with your FCM server key
        },
        body: jsonEncode({
          'to': receiverToken,
          'notification': {
            'title': 'Nouveau message de $senderName',
            'body': messageText,
            'sound': 'default',
          },
          'data': {
            'chatroomId': chatroomId,
            'senderId': currentUserId,
            'type': 'message',
          },
        }),
      );

      print('Notification sent: ${response.statusCode}');
    } catch (e) {
      print('Error sending notification: $e');
    }
  }
}
