import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'app_colors.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int)? onTap;
  final Widget? centerButton; // This will be ignored as we'll determine the button based on currentIndex
  final Color? backgroundColor; // Add this parameter to accept custom background color

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    this.onTap,
    this.centerButton,
    this.backgroundColor, // Make it optional
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    // Use provided backgroundColor or fall back to default
    final bgColor = backgroundColor ?? (isDarkMode ? AppColors.darkBackground : AppColors.lightBackground);
    final borderColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;
    
    return Stack(
      clipBehavior: Clip.none, // Allow the center button to overflow
      alignment: Alignment.topCenter,
      children: [
        // Main container for the navbar
        Container(
          height: 60,
          decoration: BoxDecoration(
            color: bgColor, // Use the background color here
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
            // Remove the borderRadius property to eliminate rounded corners
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // First two buttons (left side)
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavButton(
                      context: context,
                      icon: Icons.dashboard_outlined,
                      activeIcon: Icons.dashboard,
                      label: 'Accueil',
                      index: 0,
                      isDarkMode: isDarkMode,
                    ),
                    _buildSeparator(isDarkMode, borderColor),
                    _buildNavButton(
                      context: context,
                      icon: Icons.handyman_outlined,
                      activeIcon: Icons.handyman,
                      label: 'Services',
                      index: 1,
                      isDarkMode: isDarkMode,
                    ),
                  ],
                ),
              ),
              
              // Center space for the floating button
              SizedBox(width: 60), // Fixed width for center button space
              
              // Last two buttons (right side)
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildNavButton(
                      context: context,
                      icon: Icons.shopping_bag_outlined,
                      activeIcon: Icons.shopping_bag,
                      label: 'Marketplace',
                      index: 2,
                      isDarkMode: isDarkMode,
                    ),
                    _buildSeparator(isDarkMode, borderColor),
                    _buildNavButton(
                      context: context,
                      icon: Icons.chat_bubble_outline_rounded,
                      activeIcon: Icons.chat_bubble_rounded,
                      label: 'Messages',
                      index: 3,
                      isDarkMode: isDarkMode,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Center button that changes based on current index
        Positioned(
          top: -15, // Make it pop out by 15 pixels
          child: GestureDetector(
            onTap: () {
              // Navigate based on current index
              if (currentIndex == 2) { // If in marketplace
                context.push('/clientHome/marketplace/add');
              } else { // For all other pages
                context.push('/clientHome/chatbot');
              }
            },
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                // Updated icons to more modern alternatives
                currentIndex == 2 
                    ? Icons.add_circle_outline_rounded  // More modern add icon with outline
                    : Icons.smart_toy_outlined,         // Outlined robot icon to match style
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavButton({
    required BuildContext context,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required bool isDarkMode,
  }) {
    final isActive = index == currentIndex;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (onTap != null) {
            onTap!(index);
          } else if (index != currentIndex) {
            _handleNavigation(context, index);
          }
        },
        hoverColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(15),
        child: SizedBox(
          width: 70,
          height: 50,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                color: isActive 
                    ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                    : (isDarkMode ? Colors.grey.shade500 : Colors.grey.shade600),
                size: 22,
              ),
              if (isActive) ...[
                const SizedBox(height: 2),
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSeparator(bool isDarkMode, Color borderColor) {
    return Container(
      height: 25,
      width: 1,
      color: borderColor.withOpacity(0.5),
    );
  }

  void _handleNavigation(BuildContext context, int index) {
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
  }
}