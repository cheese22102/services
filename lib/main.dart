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
import 'chat/notifications_service.dart';
import 'admin_home_page.dart';

// Add this line at the top level
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

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

  PageRouteBuilder _fadeRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            navigatorKey: navigatorKey, // Add this line
            title: 'Services App',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.getLightTheme(),
            darkTheme: themeProvider.getDarkTheme(),
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
            }
          );
        },
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

                // Handle different roles including admin
                switch (role) {
                  case 'admin':
                    return const AdminHomePage();
                  case 'client':
                    return const ClientHomePage();
                  case 'prestataire':
                    return const PrestataireHomePage();
                  default:
                    return const ClientHomePage();
                }
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
