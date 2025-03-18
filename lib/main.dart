import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_url_gen/cloudinary.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/theme_provider.dart';
import 'login_signup/login_page.dart';
import 'login_signup/signup2_page.dart';
import 'client_home_page.dart';
import 'prestataire_home_page.dart';
import 'tutorial_screen.dart';
import 'chat/notifications_service.dart'; // Importation du service de notifications

var cloudinary = Cloudinary.fromStringUrl('cloudinary://385591396375353:xLsaxwieO44_tPNLulzCNrweET8@dfk7mskxv');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  cloudinary.config.urlConfig.secure = true;

  // Initialiser le service de notifications
  await NotificationsService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: _buildLightTheme(),
          darkTheme: _buildDarkTheme(),
          themeMode: themeProvider.themeMode,
          home: const AuthWrapper(),
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case '/signup2':
                return _fadeRoute(const Signup2Page());
              case '/clientHome':
                return _fadeRoute(const ClientHomePage());
              case '/prestataireHome':
                return _fadeRoute(const PrestataireHomePage());
              case '/tutorial':
                return _fadeRoute(const TutorialScreen());
              default:
                return _fadeRoute(const AuthWrapper());
            }
          },
        );
      }),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: Colors.green,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.fromSwatch().copyWith(
        secondary: Colors.greenAccent,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: Colors.grey[800],
      scaffoldBackgroundColor: Colors.grey[900],
      colorScheme: ColorScheme.fromSwatch(
        brightness: Brightness.dark,
        primarySwatch: Colors.grey,
      ),
    );
  }

  PageRouteBuilder _fadeRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) => FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<bool> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final firstLaunch = prefs.getBool('firstLaunch') ?? true;
    if (firstLaunch) await prefs.setBool('firstLaunch', false);
    return firstLaunch;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _checkFirstLaunch(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingScreen();
        }

        if (snapshot.data == true) {
          return const TutorialScreen();
        }

        return StreamBuilder<User?>( 
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return _buildLoadingScreen();
            }

            final user = userSnapshot.data;
            if (user == null) return const LoginPage();

            return FutureBuilder<DocumentSnapshot>( 
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .get(),
              builder: (context, docSnapshot) {
                if (docSnapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingScreen();
                }

                final data = docSnapshot.data?.data() as Map<String, dynamic>?;
                final role = data?['role'] ?? 'client'; 
                final profileCompleted = data?['profileCompleted'] ?? false;

                if (!docSnapshot.hasData || !docSnapshot.data!.exists) {
                  return const Signup2Page();
                }

                if (!profileCompleted) return const Signup2Page();

                return role == 'client'
                    ? const ClientHomePage()
                    : const PrestataireHomePage();
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingScreen() {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
