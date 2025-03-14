import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary_url_gen/cloudinary.dart';
import 'providers/theme_provider.dart';
import 'login_signup/login_page.dart';
import 'login_signup/signup2_page.dart';
import 'client_home_page.dart';
import 'prestataire_home_page.dart';

// Create a Cloudinary instance using your Cloudinary credentials.
var cloudinary = Cloudinary.fromStringUrl('cloudinary://385591396375353:xLsaxwieO44_tPNLulzCNrweET8@dfk7mskxv');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Configure Cloudinary to use secure URLs.
  cloudinary.config.urlConfig.secure = true;

  // Optionally, you can call a Cloudinary uploader function here if needed.
  // For now, we just configure Cloudinary and run the app.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              brightness: Brightness.light,
              primaryColor: Colors.green,
              scaffoldBackgroundColor: Colors.white,
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              primaryColor: Colors.grey[800],
              scaffoldBackgroundColor: Colors.grey[900],
            ),
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const AuthWrapper(),
            routes: {
              '/signup2': (context) => const Signup2Page(),
              '/clientHome': (context) => const ClientHomePage(),
              '/prestataireHome': (context) => const PrestataireHomePage(),
            },
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        User? user = snapshot.data;
        if (user == null) {
          return const LoginPage();
        }

        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return const Signup2Page();
            }

            String role = userSnapshot.data!.get('role');
            if (role == 'client') {
              return const ClientHomePage();
            } else if (role == 'prestataire') {
              return const PrestataireHomePage();
            } else {
              return const Signup2Page();
            }
          },
        );
      },
    );
  }
}
