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
    try {
      // Get OAuth2 credentials
      final credentials = await obtainCredentials()

      ;
      
      // Get the receiver's FCM token
      final receiverDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(receiverId)
          .get();

      final receiverToken = receiverDoc.data()?['fcmToken'];
      if (receiverToken == null) {
        print('Receiver token is null for user: $receiverId');
        return;
      }

      // Get current user ID (sender)
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;
      
      // Save notification to receiver's collection in Firestore
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

      // Send FCM notification with OAuth2
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/plateformeservices-72c64/messages:send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${credentials.accessToken.data}',
        },
        body: jsonEncode({
          'message': {
            'token': receiverToken,
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

  static Future<AccessCredentials> obtainCredentials() async {
    final accountCredentials = ServiceAccountCredentials.fromJson({
  "type": "service_account",
  "project_id": "plateformeservices-72c64",
  "private_key_id": "6ed9e51a43a201b5c14d8229bc26659d821ad6d1",
  "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCWkGDXEaMFC1pz\nbm69i7J7yUdbIMF+nnfF+Tnc9JSpfV8ML0qQbPUn1cfY6Ynu5FIH0Bp7prBB8fMN\nxpjPXwC9ELVW5WejPqnmnoFCXL4unzWobdIrCrnAy44tWdmHwi8A210rAIHiINWQ\nwF/tPKs3zAM6sKUJr4CAcwayjHVqYbTLCSTFyO9MkWIkF502cjzhxpFkZvJ8hI5V\nhvFePaloe/UkcPq5Blm8bHBbePQWETq00wBgREf28oYOi0bkbv7kwkmY2SxNSYo+\nJ3HBia9NcchAp6shcjFZ6nzaBFpUtXv54UsXfdEGIYm1BFfwppaBERa+KTUg6k4f\nwvCUBz8pAgMBAAECggEAEcfq8dc2vviiZdWtvROHgGwqscG+bClDiJUoXtZhDJue\nWxJmLkR51sqdy3l4FUbwQ5UxXXc340/TJgY1Q28rJ4jWu5SDvuD+gFppdjh86sVZ\nWULf8j6V5YV8jNFKuehGNAYT/Ik2rYl2Yz3+ziXvK/ubSYX1NZ288Z5z9OfW0Xla\nRtgdpKk8v4QHzPz4WhtlTgAk28g2+xVjK9Dtz2vbnCFtqIHg9Cz/cwqvZVZHuQJ5\na6+cxXYCwljm4iOOlq194p1anA/2lilwbNuPQey8Q3BBTfnQ17+NJMVJP7shXDuI\nqIAKRyQz1sivb/FsSQtWoH5AUZ3ugAdRaJm5A9FrgQKBgQC5vYosSM53KNK7tifl\nqGshptiiGkEeYNursMANBu0AgTLE5YNY6dfO+fVtof+b0JT+zmEqDEbbMMSBOHTO\nAM3K/G8uHDkn3Fal4lJLGFST1ubVUdI41TvAp9HoEqx7WwZfWy+yjVcWQl8ZBba2\najcfagz47BGBw7KVoU5W+VWHqQKBgQDPhHnQtWkyLbMnYLFT2e4i8dDA48xbKG+N\nFq5R9z86N6PTPahgDjPVksSo7eLfn5mVXN635B/ARbSFaWVn7w8iex5hTT+wfSL7\ngKKJNXodgQCrKFEa39H5S5cLZhs57Y11xLAffoNcbT0gSsnL/xpQ/tU4XWT3uwMf\nb1sXDdCrgQKBgQCJJAaSXgt79ftqt7tLmYfIaA3J2sK78F4hrbaPp850MfDPansJ\nulcqrmplUViOrnpkjPM2/auPibl9g7bSp8tLFgntLM+Su+CKSMnkQomoQuNbHDew\n2NhujjqxNKB/0ByraYOVPUDQ4Z6fthVLKK+clUwQuxTOEDWav2g9VYmuSQKBgBgc\nvYbJvXpuIvX9Xz1uAiSfUnFHRtSEw0lyjDjL8NXT5z5BWNIodE9pqV4znfv78H2R\nd/OIF0RhFRO3ZmgIOAr6oVIPBsp8D9eHX9tvkkvhVHGO0rW7sgs0hE13xMwbVSeM\n/iX6rkrMCqE472+7qZQluCK/f17lpPw/FSd9nHSBAoGAAMQzGm+eNNRdaBJX7cA+\nViW0fBvCLUYywClY4za910kc7IWLk4XK45VJx0V/OYAHasv+LIpcOWkrDRAlUZlI\nolQnWC6ODKtdfQbwgpr9GHA/z6dFR2y3VoKT+W8a0nPN9o3QJUTatYOV8cKmIfHp\n+zyMYXZDr/i0w/2hDPHG1hk=\n-----END PRIVATE KEY-----\n",
  "client_email": "plateformeservices-72c64@appspot.gserviceaccount.com",
  "client_id": "108837948097491127157",
  "auth_uri": "https://accounts.google.com/o/oauth2/auth",
  "token_uri": "https://oauth2.googleapis.com/token",
  "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
  "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/plateformeservices-72c64%40appspot.gserviceaccount.com",
  "universe_domain": "googleapis.com"
}
);


    final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
    final client = http.Client();
    
    try {
      return await obtainAccessCredentialsViaServiceAccount(
        accountCredentials, 
        scopes, 
        client,
      );
    } finally {
      client.close();
    }
  }

  // Mise à jour de la méthode pour les notifications marketplace
  static Future<void> sendMarketplaceNotification({
    required String userId,
    required String title,
    required String body,
    required String postId,
    required String action,
  }) async {
    try {
      // Get OAuth2 credentials
      final credentials = await obtainCredentials();
      
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

      // Send FCM notification with OAuth2
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/plateformeservices-72c64/messages:send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${credentials.accessToken.data}',
        },
        body: jsonEncode({
          'message': {
            'token': userToken,
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

  // Add this new method for provider notifications
  static Future<void> sendProviderStatusNotification({
    required String providerId,
    required String status,
    String? rejectionReason,
  }) async {
    try {
      // Get OAuth2 credentials
      final credentials = await obtainCredentials();
      
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

      // Send FCM notification with OAuth2
      final response = await http.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/plateformeservices-72c64/messages:send'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${credentials.accessToken.data}',
        },
        body: jsonEncode({
          'message': {
            'token': providerToken,
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
}
