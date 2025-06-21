import 'package:flutter/material.dart';
import 'app_colors.dart';

class CustomBottomNavBarProvider extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onItemSelected;
  final bool isDarkMode;
  final bool hasUnreadMessages; // New parameter

  const CustomBottomNavBarProvider({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
    required this.isDarkMode,
    this.hasUnreadMessages = false, // Default to false
  });

  void _handleNavigation(BuildContext context, int index) {
    // Only call the parent's callback to update its selected index
    // The parent (PrestataireHomePage) will handle showing the correct IndexedStack child
    onItemSelected(index);
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: (index) => _handleNavigation(context, index), // Call internal handler
      backgroundColor: isDarkMode ? Colors.grey.shade900 : Colors.white,
      selectedItemColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
      unselectedItemColor: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade700,
      items: <BottomNavigationBarItem>[ // Removed const
        const BottomNavigationBarItem( // This can remain const
          icon: Icon(Icons.home),
          label: 'Accueil',
        ),
        const BottomNavigationBarItem( // This can remain const
          icon: Icon(Icons.assignment),
          label: 'Réservations',
        ),
        BottomNavigationBarItem( // Removed const
          icon: Stack(
            clipBehavior: Clip.none, // Allow dot to overflow if needed
            children: <Widget>[
              const Icon(Icons.message), // This can remain const
              if (hasUnreadMessages)
                Positioned(
                  top: -2, // Adjust position as needed
                  right: -4, // Adjust position as needed
                  child: Container(
                    padding: const EdgeInsets.all(2), // Keep padding small or remove if not needed with larger size
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(8), // Increased border radius for a larger dot
                      border: Border.all(color: isDarkMode ? Colors.black : Colors.white, width: 1), // Optional: border for better visibility
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 10, // Increased size
                      minHeight: 10, // Increased size
                    ),
                  ),
                ),
            ],
          ),
          label: 'Messages',
        ),
        const BottomNavigationBarItem( // This can remain const
          icon: Icon(Icons.person),
          label: 'Profil',
        ),
      ],
    );
  }
}
