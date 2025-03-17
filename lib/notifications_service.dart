import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

class NotificationsService {
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Canal de notification pour les messages (sans son personnalisé)
  static const AndroidNotificationChannel _messageChannel = AndroidNotificationChannel(
    'message_channel', 
    'New Message Notifications', 
    description: 'This channel is used for notifications about new messages.',
    importance: Importance.max,
    playSound: true,
    // Suppression de l'attribut "sound" pour utiliser le son par défaut
  );

  static Future<void> initialize() async {
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

    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('Notification clicked: ${response.payload}');
      },
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_messageChannel);

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _showNotification(message);
      }
    });

    String? token = await _firebaseMessaging.getToken();
    if (token != null) {
      _saveFCMToken(token);
    }

    _firebaseMessaging.onTokenRefresh.listen(_saveFCMToken);
  }

  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    print("Background message: ${message.messageId}");
  }

  static Future<void> _showNotification(RemoteMessage message) async {
    const notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'message_channel',
        'New Message Notifications',
        importance: Importance.max,
        priority: Priority.high,
        // Suppression du paramètre "sound" pour utiliser le son par défaut
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

  static Future<void> _saveFCMToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'fcmToken': token});
    }
  }

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

      final receiverToken = receiverDoc.data()?['fcmToken'] as String?;
      if (receiverToken == null) return;

      // Configuration du compte de service pour OAuth 2.0
      final accountCredentials = ServiceAccountCredentials.fromJson({
        "type": "service_account",
        "project_id": "plateformeservices-72c64",
        "private_key_id": "6ed9e51a43a201b5c14d8229bc26659d821ad6d1",
        "private_key": "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCWkGDXEaMFC1pz\n... (reste de votre clé privée) ...\n-----END PRIVATE KEY-----\n",
        "client_email": "plateformeservices-72c64@appspot.gserviceaccount.com",
        "client_id": "108837948097491127157",
        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
        "token_uri": "https://oauth2.googleapis.com/token",
        "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
        "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/plateformeservices-72c64%40appspot.gserviceaccount.com"
      });

      // Création du client d'authentification avec la scope pour Firebase Messaging
      final authClient = await clientViaServiceAccount(
        accountCredentials,
        ['https://www.googleapis.com/auth/firebase.messaging']
      );

      // URL de l'API FCM v1 (remplacez YOUR_PROJECT_ID par l'ID de votre projet)
      final url = Uri.parse('https://fcm.googleapis.com/v1/projects/plateformeservices-72c64/messages:send');

      // Construction du payload
      final body = jsonEncode({
        'message': {
          'token': receiverToken,
          'notification': {
            'title': 'New Message from $senderName',
            'body': messageText,
          },
          'android': {
            'notification': {
              'channelId': 'message_channel',
              'sound': 'default'
            }
          },
          'data': {
            'type': 'new_message',
            'chatroomId': chatroomId,
            'senderId': FirebaseAuth.instance.currentUser!.uid,
          }
        }
      });

      // Envoi de la requête via le client d'authentification
      final response = await authClient.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode != 200) {
        print('Erreur FCM: ${response.statusCode} ${response.body}');
      } else {
        print('Notification envoyée avec succès!');
      }
    } catch (e) {
      print('Erreur d\'envoi de notification: $e');
    }
  }
}
