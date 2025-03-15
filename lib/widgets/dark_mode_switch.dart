import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class DarkModeSwitch extends StatelessWidget {
  const DarkModeSwitch({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return PopupMenuButton<ThemeMode>(
      icon: Icon(Icons.brightness_6, color: Theme.of(context).iconTheme.color),
      onSelected: (mode) => themeProvider.setTheme(mode),
      itemBuilder: (context) => [
        _buildPopupItem('Automatique', ThemeMode.system, context),
        _buildPopupItem('Clair', ThemeMode.light, context),
        _buildPopupItem('Sombre', ThemeMode.dark, context),
      ],
    );
  }

  PopupMenuItem<ThemeMode> _buildPopupItem(String text, ThemeMode mode, BuildContext context) {
    return PopupMenuItem<ThemeMode>(
      value: mode,
      child: Row(
        children: [
          Icon(
            _getIcon(mode),
            color: Theme.of(context).iconTheme.color,
          ),
          const SizedBox(width: 10),
          Text(text),
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