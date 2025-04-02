import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:plateforme_services/client/marketplace/conversation_marketplace.dart';
import 'package:plateforme_services/main.dart';
import '/config/constants.dart';

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
    try {
      final receiverDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(receiverId)
          .get();

      final receiverToken = receiverDoc.data()?['fcmToken'];
      if (receiverToken == null) {
        print('Receiver token is null for user: $receiverId');
        return;
      }

      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;
      
      // Save notification to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(receiverId)
          .collection('notifications')
          .add({
            'title': 'Nouveau message de $senderName',
            'body': messageText,
            'type': 'message',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
            'data': {
              'chatroomId': chatroomId,
              'senderId': currentUserId,
              'type': 'message',
            },
          });

      // Update the FCM notification sending part
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=${AppConstants.fcmServerKey}',
        },
        body: jsonEncode({
          'to': receiverToken,
          'notification': {
            'title': 'Nouveau message de $senderName',
            'body': messageText,
          },
          'android': {
            'notification': {
              'channel_id': 'message_channel',
              'sound': 'default',
            },
          },
          'data': {
            'chatroomId': chatroomId,
            'senderId': currentUserId,
            'type': 'message',
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          },
        }),
      );

      print('Notification sent: ${response.statusCode}');
      if (response.statusCode != 200) {
        print('FCM Error: ${response.body}');
      } else {
        print('FCM Success: ${response.body}');
      }
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  static Future<void> sendMarketplaceNotification({
    required String userId,
    required String title,
    required String body,
    required String postId,
    required String action,
  }) async {
    try {
      // Remove the OAuth2 credentials part
      
      // Get the user's FCM token
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      final userToken = userDoc.data()?['fcmToken'];
      if (userToken == null) {
        print('User token is null for user: $userId');
        return;
      }

      // Save notification to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
            'title': title,
            'body': body,
            'type': 'marketplace',
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
            'data': {
              'postId': postId,
              'action': action,
              'type': 'marketplace_validation'
            },
          });

      // Update the FCM notification sending part
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/fcm/send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'key=${AppConstants.fcmServerKey}',
        },
        body: jsonEncode({
          'to': userToken,
          'notification': {
            'title': title,
            'body': body,
          },
          'android': {
            'notification': {
              'channel_id': 'message_channel',
              'sound': 'default',
            },
          },
          'data': {
            'type': 'marketplace',
            'postId': postId,
            'action': action,
            'click_action': 'FLUTTER_NOTIFICATION_CLICK',
          },
        }),
      );

      print('Marketplace notification sent: ${response.statusCode}');
      if (response.statusCode != 200) {
        print('FCM Error: ${response.body}');
      } else {
        print('FCM Success: ${response.body}');
      }
    } catch (e) {
      print('Error sending marketplace notification: $e');
    }
  }

  // Update the sendProviderStatusNotification method
  static Future<void> sendProviderStatusNotification({
      required String providerId,
      required String status,
      String? rejectionReason,
    }) async {
      try {
        // Remove the OAuth2 credentials part
        
        // Get the provider's FCM token
        final providerDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(providerId)
            .get();
  
        final providerToken = providerDoc.data()?['fcmToken'];
        if (providerToken == null) {
          print('Provider token is null for user: $providerId');
          return;
        }
  
        // Prepare notification content based on status
        final title = status == 'approved' 
            ? 'Demande approuvée'
            : 'Demande refusée';
            
        final body = status == 'approved'
            ? 'Félicitations ! Votre compte prestataire est maintenant actif.'
            : 'Votre demande de prestataire a été refusée. ${rejectionReason ?? ''}';
  
        // Save notification to Firestore
        await FirebaseFirestore.instance
            .collection('provider_requests')
            .doc(providerId)
            .collection('notifications')
            .add({
              'title': title,
              'body': body,
              'type': status == 'approved' ? 'approval' : 'rejection',
              'timestamp': FieldValue.serverTimestamp(),
              'read': false,
              'data': {
                'status': status,
                'rejectionReason': rejectionReason,
                'type': 'provider_status',
              },
            });
  
        // Update the FCM notification sending part
        final response = await http.post(
          Uri.parse('https://fcm.googleapis.com/fcm/send'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'key=${AppConstants.fcmServerKey}',
          },
          body: jsonEncode({
            'to': providerToken,
            'notification': {
              'title': title,
              'body': body,
            },
            'android': {
              'notification': {
                'channel_id': 'message_channel',
                'sound': 'default',
              },
            },
            'data': {
              'type': 'provider_status',
              'status': status,
              'rejectionReason': rejectionReason ?? '',
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            },
          }),
        );
  
        print('Provider status notification sent: ${response.statusCode}');
        if (response.statusCode != 200) {
          print('FCM Error: ${response.body}');
        } else {
          print('FCM Success: ${response.body}');
        }
      } catch (e) {
        print('Error sending provider status notification: $e');
      }
    }
    
    // Add this new method for sending notifications
    static Future<void> sendNotification({
      required String userId,
      required String title,
      required String body,
      Map<String, dynamic>? data,
    }) async {
      try {
        // Get the user's FCM token
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();
        
        if (!userDoc.exists) {
          print('User document does not exist for userId: $userId');
          return;
        }
        
        final userData = userDoc.data();
        final fcmToken = userData?['fcmToken'];
        
        if (fcmToken == null || fcmToken.isEmpty) {
          print('No FCM token found for user: $userId');
          return;
        }
        
        // Save notification to Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .add({
          'title': title,
          'body': body,
          'data': data ?? {},
          'timestamp': FieldValue.serverTimestamp(),
          'read': false,
        });
        
        // Send FCM notification
        await _sendFCMNotification(
          token: fcmToken,
          title: title,
          body: body,
          data: data ?? {},
        );
      } catch (e) {
        print('Error sending notification: $e');
      }
    }
    
    // Helper method to send FCM notification
    static Future<void> _sendFCMNotification({
      required String token,
      required String title,
      required String body,
      required Map<String, dynamic> data,
    }) async {
      try {
        final response = await http.post(
          Uri.parse('https://fcm.googleapis.com/fcm/send'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'key=${AppConstants.fcmServerKey}',
          },
          body: jsonEncode({
            'to': token,
            'notification': {
              'title': title,
              'body': body,
            },
            'data': data,
          }),
        );
        
        if (response.statusCode != 200) {
          print('Failed to send FCM notification. Status: ${response.statusCode}, Body: ${response.body}');
        }
      } catch (e) {
        print('Error sending FCM notification: $e');
      }
    }
}
