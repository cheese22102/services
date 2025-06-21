import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Assuming GoogleFonts might be used for any text
import 'front/app_colors.dart'; // Import AppColors

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
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
