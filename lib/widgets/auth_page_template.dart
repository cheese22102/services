import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dark_mode_switch.dart';

class AuthPageTemplate extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imagePath;
  final List<Widget> children;
  final VoidCallback? onBackPressed;
  final bool showBackButton;

  const AuthPageTemplate({
    super.key,
    required this.title,
    required this.subtitle,
    required this.imagePath,
    required this.children,
    this.onBackPressed,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with back button and dark mode switch
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (showBackButton)
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        onPressed: onBackPressed ?? () => context.go('/'),
                      ),
                    const DarkModeSwitch(),
                  ],
                ),
                const SizedBox(height: 20),

                // Illustration
                Center(
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black26 : Colors.grey.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        imagePath,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Title and Subtitle
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontSize: 16,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 32),

                // Children widgets
                ...children,
              ],
            ),
          ),
        ),
      ),
    );
  }
}