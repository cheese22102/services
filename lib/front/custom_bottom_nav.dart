import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'app_colors.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int)? onTap; // Made optional to allow internal routing

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade900 : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) {
            // If external onTap is provided, call it
            if (onTap != null) {
              onTap!(index);
              return;
            }
            
            // Otherwise handle navigation internally
            if (index != currentIndex) {
              _handleNavigation(context, index);
            }
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
          unselectedItemColor: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade600,
          selectedLabelStyle: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          unselectedLabelStyle: GoogleFonts.poppins(
            fontSize: 12,
          ),
          elevation: 0,
          items: [
            _buildNavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: 'Accueil',
              index: 0,
              currentIndex: currentIndex,
            ),
            _buildNavItem(
              icon: Icons.handyman_outlined,
              activeIcon: Icons.handyman,
              label: 'Services',
              index: 1,
              currentIndex: currentIndex,
            ),
            _buildNavItem(
              icon: Icons.shopping_bag_outlined,
              activeIcon: Icons.shopping_bag,
              label: 'Marketplace',
              index: 2,
              currentIndex: currentIndex,
            ),
            _buildNavItem(
              icon: Icons.chat_bubble_outline,
              activeIcon: Icons.chat_bubble,
              label: 'Messages',
              index: 3,
              currentIndex: currentIndex,
            ),
          ],
        ),
      ),
    );
  }

  // New method to handle navigation
  void _handleNavigation(BuildContext context, int index) {
    switch (index) {
      case 0:
        // Home
        context.go('/clientHome');
        break;
      case 1:
        // Services
        context.go('/clientHome/request-service');
        break;
      case 2:
        // Marketplace
        context.go('/clientHome/marketplace');
        break;
      case 3:
        // Messages
        context.go('/clientHome/marketplace/chat');
        break;
    }
  }

  BottomNavigationBarItem _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required int currentIndex,
  }) {
    return BottomNavigationBarItem(
      icon: Icon(
        index == currentIndex ? activeIcon : icon,
        size: 24,
      ),
      label: label,
    );
  }
}