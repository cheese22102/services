import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../front/custom_app_bar.dart';
import '../front/app_colors.dart';
import '../front/custom_bottom_nav.dart';
import 'package:go_router/go_router.dart';

class ChatbotPage extends StatefulWidget {
  const ChatbotPage({super.key});

  @override
  State<ChatbotPage> createState() => _ChatbotPageState();
}

class _ChatbotPageState extends State<ChatbotPage> {
  // Navigation index - no specific tab is active for this page
  // We'll handle navigation manually through the CustomBottomNav
  final int _selectedIndex = -1; // Using -1 to indicate this is a special page

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: CustomAppBar(
        title: 'Assistant IA',
        showBackButton: true,
        onBackPressed: () {
          // Navigate back to the home page
          context.go('/clientHome');
        },
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.smart_toy,
              size: 80,
              color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
            ),
            const SizedBox(height: 24),
            Text(
              'Assistant IA',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                'Cette fonctionnalité sera bientôt disponible',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _selectedIndex,
        onTap: (index) {
          // Handle navigation based on the tapped index
          switch (index) {
            case 0:
              context.go('/clientHome');
              break;
            case 1:
              context.go('/clientHome/all-services');
              break;
            case 2:
              context.go('/clientHome/marketplace');
              break;
            case 3:
              context.go('/clientHome/marketplace/chat');
              break;
          }
        },
      ),
    );
  }
}