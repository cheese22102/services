import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'app_colors.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBackButton;
  final List<Widget>? actions;
  final Widget? bottom;
  final VoidCallback? onBackPressed;
  final double height;
  final Color? backgroundColor;
  final Color? titleColor;
  final Color? iconColor;
  final bool showSidebar;
  final bool showNotifications;
  final int? currentIndex;

  const CustomAppBar({
    super.key,
    required this.title,
    this.showBackButton = true,
    this.actions,
    this.bottom, // Add initialization
    this.onBackPressed,
    this.height = 56.0,
    this.backgroundColor,
    this.titleColor,
    this.iconColor,
    this.showSidebar = false,
    this.showNotifications = false,
    this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    // Match colors with bottom nav
    final defaultIconColor = iconColor ?? 
        (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen);
    final defaultTitleColor = titleColor ?? 
        (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen);
    
    return AppBar(
      elevation: 0,
      backgroundColor: backgroundColor ?? (isDarkMode ? Colors.grey.shade900 : Colors.white), // Matched with CustomBottomNav
      centerTitle: true,
      leading: _buildLeadingWidget(context, defaultIconColor),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: defaultTitleColor,
        ),
      ),
      actions: _buildActions(context, defaultIconColor, isDarkMode),
      bottom: bottom != null ? PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: bottom!,
      ) : null,
    );
  }

  // Helper method to build the leading widget (back button or sidebar)
  Widget? _buildLeadingWidget(BuildContext context, Color iconColor) {
    
    if (showSidebar) {
      return Builder(
        builder: (context) => IconButton(
          icon: Icon(
            Icons.menu,
            color: iconColor,
          ),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      );
    } else if (showBackButton) {
      return IconButton(
        icon: Icon(
          Icons.arrow_back_ios,
          color: iconColor,
          size: 20,
        ),
        onPressed: onBackPressed ?? () => Navigator.of(context).pop(),
      );
    }
    return null;
  }

  // Helper method to build the actions (notifications and custom actions)
  List<Widget>? _buildActions(BuildContext context, Color iconColor, bool isDarkMode) {
    final actionsList = <Widget>[];
    
    // Add notification icon if needed
    if (showNotifications) {
      actionsList.add(
        StreamBuilder<int>(
          stream: _getUnreadNotificationsCount(),
          builder: (context, snapshot) {
            final unreadCount = snapshot.data ?? 0;
            
            return Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.notifications_outlined,
                    color: iconColor,
                  ),
                  onPressed: () {
                    context.go('/clientHome/notifications');
                  },
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: 6, // Adjusted position
                    right: 6, // Adjusted position
                    child: Container(
                      width: 12, // Increased size
                      height: 12, // Increased size
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDarkMode ? Colors.grey.shade900 : Colors.white,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }
    
    // Add custom actions if provided
    if (actions != null) {
      actionsList.addAll(actions!);
    }
    
    // Add a small padding at the end
    if (actionsList.isNotEmpty) {
      actionsList.add(const SizedBox(width: 8));
    }
    
    return actionsList.isEmpty ? null : actionsList;
  }

  // Method to get unread notifications count
  Stream<int> _getUnreadNotificationsCount() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value(0);
    }
    
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  @override
  Size get preferredSize => bottom != null 
      ? Size.fromHeight(height + 48) // Adjust height when bottom is provided
      : Size.fromHeight(height);
}
