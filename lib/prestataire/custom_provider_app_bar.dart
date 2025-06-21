import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../front/app_colors.dart';
import 'provider_notifications_page.dart'; // Import for notifications count
import 'package:go_router/go_router.dart'; // Import for navigation

class CustomProviderAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int selectedIndex;
  final bool isDarkMode;

  const CustomProviderAppBar({
    super.key,
    required this.selectedIndex,
    required this.isDarkMode,
  });

  String _getTitle(int index) {
    switch (index) {
      case 0:
        return 'Espace Prestataire';
      case 1:
        return 'Mes Réservations';
      case 2:
        return 'Mes Messages';
      case 3:
        return 'Mon Profil';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: isDarkMode ? Colors.grey.shade900 : Colors.white,
      centerTitle: true,
      title: Text(
        _getTitle(selectedIndex),
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen, // Matches selectedItemColor
        ),
      ),
      foregroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen, // Matches selectedItemColor
      actions: [
        StreamBuilder<int>(
          stream: ProviderNotificationsPage.getUnreadNotificationsCount(),
          builder: (context, snapshot) {
            final unreadCount = snapshot.data ?? 0;
            return Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.notifications_outlined,
                    color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen, // Matches selectedItemColor
                  ),
                  onPressed: () {
                    context.go('/prestataireHome/notifications');
                  },
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 12,
                      height: 12,
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
        const SizedBox(width: 8), // Add a small padding at the end
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
