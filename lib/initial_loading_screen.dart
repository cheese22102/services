import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart'; // Import GoogleFonts
import 'front/app_colors.dart'; // Assuming AppColors is used for styling

class InitialLoadingScreen extends StatefulWidget {
  const InitialLoadingScreen({super.key});

  @override
  State<InitialLoadingScreen> createState() => _InitialLoadingScreenState();
}

class _InitialLoadingScreenState extends State<InitialLoadingScreen> {
  @override
  void initState() {
    super.initState();
    _initializeAppAndRedirect();
  }

  Future<void> _initializeAppAndRedirect() async {
    // Check if it's the first launch
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('is_first_launch') ?? true;

    if (isFirstLaunch) {
      await prefs.setBool('is_first_launch', false);
      if (mounted) {
        context.go('/tutorial');
      }
      return;
    }

    // Check if user is logged in
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      // No user logged in, go to login page
      if (mounted) {
        context.go('/');
      }
      return;
    } else {
      // User is logged in, perform additional checks
      try {
        await currentUser.reload();
        final updatedUser = FirebaseAuth.instance.currentUser;

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(updatedUser!.uid)
            .get();
        
        final userData = userDoc.data();
        final isGoogleSignIn = updatedUser.providerData.any((info) => info.providerId == 'google.com');
        final profileCompleted = userData?['profileCompleted'] ?? false;
        final userRole = userData?['role'] as String?;

        if (!userDoc.exists || !profileCompleted) {
          if (mounted) {
            context.go('/completer-profile');
          }
          return;
        }

        if (!updatedUser.emailVerified && !isGoogleSignIn) {
          if (mounted) {
            context.go('/verification');
          }
          return;
        }
        
        // All checks passed, redirect to appropriate home page
        if (userRole == 'admin') {
          if (mounted) {
            context.go('/admin');
          }
        } else if (userRole == 'prestataire') {
          if (mounted) {
            context.go('/prestataireHome');
          }
        } else {
          if (mounted) {
            context.go('/clientHome'); // Default to client
          }
        }
      } catch (e) {
        print('Error during initial loading redirect: $e');
        if (mounted) {
          context.go('/'); // Fallback to login on error
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? AppColors.darkBackground : Colors.white;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'AiDomi',
              style: GoogleFonts.poppins(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : AppColors.primaryDarkGreen,
              ),
            ),
            const SizedBox(height: 16), // Space between title and logo
            Image.asset(
              'assets/images/login.png',
              width: 200, // Adjust size as needed
              height: 200, // Adjust size as needed
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 16), // Space between logo and message
            Text(
              'Votre aide à domicile, à portée de main.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 24), // Space before indicator
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(
                isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
