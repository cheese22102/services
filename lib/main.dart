import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:cloudinary_url_gen/cloudinary.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'providers/theme_provider.dart';
import 'notifications_service.dart';
import 'router.dart';
import 'firebase_options.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
var cloudinary = Cloudinary.fromStringUrl('cloudinary://385591396375353:xLsaxwieO44_tPNLulzCNrweET8@dfk7mskxv');

Future<bool> checkFirstLaunch() async {
  final prefs = await SharedPreferences.getInstance();
  final isFirstLaunch = prefs.getBool('is_first_launch') ?? true;
  if (isFirstLaunch) {
    await prefs.setBool('is_first_launch', false);
  }
  return isFirstLaunch;
}

Future<void> updateFcmTokenIfNeeded() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null) {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': fcmToken});
      }
      // Listen for token refresh and update Firestore
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcmToken': newToken});
      });
    // ignore: empty_catches
    } catch (e) {
    }
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialize Firebase with platform-specific options
    if (kIsWeb) {
      // For web, we need to initialize Firebase with web options
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyDaghSyR8_TISxbwN1T2HVt_waYOO0A9II",
          authDomain: "plateformeservices-72c64.firebaseapp.com",
          projectId: "plateformeservices-72c64",
          storageBucket: "plateformeservices-72c64.appspot.com",
          messagingSenderId: "710615234824",
          appId: "1:710615234824:web:8775e718f54818309ed4bd"
        ),
      );
    } else {
      // For other platforms, use the platform-specific options
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    
    // Initialize Firebase App Check
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug, // Use debug provider for Android
      // appleProvider: AppleProvider.debug, // Uncomment for iOS debug
    );

    // Configure Cloudinary
    cloudinary.config.urlConfig.secure = true;
    
    // Only initialize notifications on non-web platforms
    if (!kIsWeb) {
      await NotificationsService.initialize();
      await updateFcmTokenIfNeeded();
    }
    
    final isFirstLaunch = await checkFirstLaunch();
    runApp(MyApp(isFirstLaunch: isFirstLaunch));
  } catch (e) {
    // Fallback to run the app even if Firebase fails
    final isFirstLaunch = await checkFirstLaunch();
    runApp(MyApp(isFirstLaunch: isFirstLaunch));
  }
}

class MyApp extends StatelessWidget {
  final bool isFirstLaunch;
  
  const MyApp({super.key, required this.isFirstLaunch});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp.router(
            routerConfig: AppRouter.createRouter(isFirstLaunch),
            debugShowCheckedModeBanner: false,
            title: 'Services App',
            theme: themeProvider.getLightTheme(),
            darkTheme: themeProvider.getDarkTheme(),
            themeMode: themeProvider.themeMode,
          );
        },
      ),
    );
  }
}
