import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'app_colors.dart';

class ThemeToggleSwitch extends StatelessWidget {
  const ThemeToggleSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;
    final currentTheme = themeProvider.themeMode;
    
    return PopupMenuButton<ThemeMode>(
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 50,
        height: 26,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: isDarkMode 
              ? Colors.grey.shade800 
              : Colors.grey.shade300,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(3),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              left: isDarkMode ? 24 : 0,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryColor,
                ),
                child: Center(
                  child: Icon(
                    isDarkMode ? Icons.dark_mode : Icons.light_mode,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      onSelected: (ThemeMode mode) {
        themeProvider.setTheme(mode);
      },
      itemBuilder: (context) => [
        _buildPopupItem('Système', ThemeMode.system, context, currentTheme),
        _buildPopupItem('Clair', ThemeMode.light, context, currentTheme),
        _buildPopupItem('Sombre', ThemeMode.dark, context, currentTheme),
      ],
    );
  }
  
  PopupMenuItem<ThemeMode> _buildPopupItem(
    String text, 
    ThemeMode mode, 
    BuildContext context,
    ThemeMode currentTheme,
  ) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;
    
    return PopupMenuItem<ThemeMode>(
      value: mode,
      child: Row(
        children: [
          Icon(
            _getIcon(mode),
            color: currentTheme == mode ? primaryColor : Theme.of(context).iconTheme.color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              fontWeight: currentTheme == mode ? FontWeight.bold : FontWeight.normal,
              color: currentTheme == mode ? primaryColor : null,
            ),
          ),
          if (currentTheme == mode)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Icon(
                Icons.check,
                color: primaryColor,
                size: 18,
              ),
            ),
        ],
      ),
    );
  }

  IconData _getIcon(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return Icons.light_mode;
      case ThemeMode.dark:
        return Icons.dark_mode;
      default:
        return Icons.settings_suggest;
    }
  }
}