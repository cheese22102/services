import 'dart:async'; // For StreamSubscription
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'app_colors.dart';
import '../chat/liste_conversations.dart'; // Import ChatListScreen

class CustomBottomNav extends StatefulWidget {
  final int currentIndex;
  final Function(int)? onTap;
  final Color? backgroundColor;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    this.onTap,
    this.backgroundColor,
  });

  @override
  State<CustomBottomNav> createState() => _CustomBottomNavState();
}

class _CustomBottomNavState extends State<CustomBottomNav> {
  bool _hasUnreadMessages = false;
  StreamSubscription<int>? _unreadCountSubscription;

  @override
  void initState() {
    super.initState();
    _unreadCountSubscription = ChatListScreen.getTotalUnreadCount().listen((count) {
      if (_hasUnreadMessages != (count > 0)) {
        setState(() {
          _hasUnreadMessages = count > 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _unreadCountSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final bgColor = widget.backgroundColor ?? (isDarkMode ? Colors.grey.shade900 : Colors.white);
    
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: bgColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavButton(
            context: context,
            icon: Icons.home_outlined,
            activeIcon: Icons.home_rounded,
            label: 'Accueil',
            index: 0,
            isDarkMode: isDarkMode,
            hasRedDot: false, // No red dot for home
          ),
          _buildNavButton(
            context: context,
            icon: Icons.build_outlined,
            activeIcon: Icons.build_rounded,
            label: 'Services',
            index: 1,
            isDarkMode: isDarkMode,
            hasRedDot: false, // No red dot for services
          ),
          _buildNavButton(
            context: context,
            icon: Icons.shopping_cart_outlined,
            activeIcon: Icons.shopping_cart_rounded,
            label: 'Market',
            index: 2,
            isDarkMode: isDarkMode,
            hasRedDot: false, // No red dot for market
          ),
          _buildNavButton(
            context: context,
            icon: Icons.chat_bubble_outline_rounded,
            activeIcon: Icons.chat_bubble_rounded,
            label: 'Messages',
            index: 3,
            isDarkMode: isDarkMode,
            hasRedDot: _hasUnreadMessages, // Use internal state for red dot
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required BuildContext context,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int index,
    required bool isDarkMode,
    bool hasRedDot = false,
  }) {
    final isActive = index == widget.currentIndex;
    final activeColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;
    final inactiveColor = isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    
    final textColor = isActive ? activeColor : inactiveColor;
    final iconColor = isActive ? activeColor : inactiveColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (widget.onTap != null) {
            widget.onTap!(index);
          } else if (index != widget.currentIndex) {
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
              Stack(
                alignment: Alignment.topRight,
                children: [
                  Icon(
                    isActive ? activeIcon : icon,
                    color: iconColor, // Use the determined icon color
                    size: 24,
                  ),
                  if (hasRedDot && index == 3)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 10, // Bigger dot
                        height: 10, // Bigger dot
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                  color: textColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
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
