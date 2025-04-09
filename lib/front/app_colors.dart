import 'package:flutter/material.dart';

class AppColors {
  // Primary colors
  static const Color primaryGreen = Color(0xFF8BC34A);
  static const Color primaryDarkGreen = Color(0xFF3A523E);
  
  // Light mode colors
  static const Color lightBackground = Colors.white;
  static const Color lightInputBackground = Color(0xFFF9FFF5);
  static const Color lightBorderColor = Color(0xFF4D8C3F);
  static const Color lightTextPrimary = Colors.black;
  static const Color lightTextSecondary = Colors.black54;
  static const Color lightTextHint = Colors.black38;
  
  // Dark mode colors
  static const Color darkBackground = Color(0xFF2D3B33);
  static const Color darkInputBackground = Color(0xFF3A4D40);
  static const Color darkBorderColor = Color(0xFF4D8C3F);
  static const Color darkTextPrimary = Colors.white;
  static const Color darkTextSecondary = Colors.white70;
  static const Color darkTextHint = Colors.white38;
  
  // Gradient colors - Light mode
  static const List<Color> lightGradient = [
    Color(0xFF8BC34A),    // Medium green at top
    Color(0xFF9CCC65),    // Light green
    Color(0xFFCDDC39),    // Lime green
    Color(0xFFD4E157),    // Bright lime
    Color(0xFFCDDC39),    // Lime green again
    Color(0xFF9CCC65),    // Light green
    Color(0xFF8BC34A),    // Medium green at bottom
  ];
  
  // Gradient colors - Dark mode
  static const List<Color> darkGradient = [
    Color(0xFF1F2923),    // Dark green at top
    Color(0xFF2A3C30),    // Slightly lighter dark green
    Color(0xFF3A523E),    // Medium dark green
    Color(0xFF435C46),    // Highlight dark green
    Color(0xFF3A523E),    // Medium dark green again
    Color(0xFF2A3C30),    // Slightly lighter dark green
    Color(0xFF1F2923),    // Dark green at bottom
  ];
  
  // Gradient stops
  static const List<double> gradientStops = [0.0, 0.2, 0.4, 0.5, 0.6, 0.8, 1.0];
  
  // Error colors
  static const Color errorRed = Colors.red;
  static const Color errorDarkRed = Color(0xFF8B2D2D);
  static const Color errorLightRed = Color(0xFFD32F2F);
  
  // Success colors
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color successDarkGreen = Color(0xFF3A523E);
}