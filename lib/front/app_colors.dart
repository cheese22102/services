import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary colors
  static const Color primaryGreen = Color(0xFF8BC34A);
  static const Color primaryDarkGreen = Color(0xFF3A523E);
  
  // Light mode colors
  static const Color lightBackground = Colors.white;
  static const Color lightTextPrimary = Colors.black;
  static const Color lightTextSecondary = Colors.black54;
  static const Color lightTextHint = Colors.black38;
  static const Color lightSurface = Color(0xFFFAFAFA); // Standard light surface color
  static const Color lightBorder = Color(0xFFE0E0E0); // Light border color
  
  // Dark mode colors
  static const Color darkBackground = Color(0xFF2D3B33);
  static const Color darkTextPrimary = Colors.white;
  static const Color darkTextSecondary = Colors.white70;
  static const Color darkTextHint = Colors.white38;
  static const Color darkSurface = Color(0xFF28332C); // Slightly darker than main background
  static const Color darkBorder = Color(0xFF424242); // Dark border color
  static const Color darkAppBarBackground = Color(0xFF28332C);
  static const Color lightAppBarBackground = Colors.white;
  static const Color darkIconColor = Colors.white;
  static const Color lightIconColor = primaryDarkGreen;
  
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
  static const Color errorRed = Color.fromARGB(255, 246, 88, 76);
  static const Color errorDarkRed = Color(0xFF8B2D2D);
  static const Color errorLightRed = Color(0xFFD32F2F);
  
  // Warning colors
  static const Color warningOrange = Color(0xFFFFA000); // Added warning orange

  // Success colors
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color successDarkGreen = Color(0xFF3A523E);

  // Typography System
  static TextStyle get displayLarge => GoogleFonts.poppins(
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static TextStyle get displayMedium => GoogleFonts.poppins(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.25,
    height: 1.3,
  );

  static TextStyle get displaySmall => GoogleFonts.poppins(
    fontSize: 24,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.3,
  );

  static TextStyle get headlineLarge => GoogleFonts.poppins(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.4,
  );

  static TextStyle get headlineMedium => GoogleFonts.poppins(
    fontSize: 20,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.15,
    height: 1.4,
  );

  static TextStyle get headlineSmall => GoogleFonts.poppins(
    fontSize: 18,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.15,
    height: 1.4,
  );

  static TextStyle get titleLarge => GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.15,
    height: 1.5,
  );

  static TextStyle get titleMedium => GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.5,
  );

  static TextStyle get titleSmall => GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.5,
  );

  static TextStyle get bodyLarge => GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.5,
    height: 1.6,
  );

  static TextStyle get bodyMedium => GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.25,
    height: 1.6,
  );

  static TextStyle get bodySmall => GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.4,
    height: 1.6,
  );

  static TextStyle get labelLarge => GoogleFonts.poppins(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.4,
  );

  static TextStyle get labelMedium => GoogleFonts.poppins(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.4,
  );

  static TextStyle get labelSmall => GoogleFonts.poppins(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.4,
  );

  // Helper methods for themed text styles
  static TextStyle getThemedTextStyle(TextStyle baseStyle, bool isDarkMode) {
    return baseStyle.copyWith(
      color: isDarkMode ? darkTextPrimary : lightTextPrimary,
    );
  }

  static TextStyle getThemedSecondaryTextStyle(TextStyle baseStyle, bool isDarkMode) {
    return baseStyle.copyWith(
      color: isDarkMode ? darkTextSecondary : lightTextSecondary,
    );
  }

  static TextStyle getThemedHintTextStyle(TextStyle baseStyle, bool isDarkMode) {
    return baseStyle.copyWith(
      color: isDarkMode ? darkTextHint : lightTextHint,
    );
  }

  // Text colors
  static Color get darkTextColor => darkTextPrimary;
  static Color get lightTextColor => lightTextPrimary;
  static Color get darkHintColor => darkTextHint;
  static Color get lightHintColor => lightTextHint;

  // Backgrounds and borders
  static Color get darkInputBackground => const Color(0xFF3A4D40);
  static Color get lightInputBackground => const Color(0xFFF9FFF5);
  static Color get darkCardBackground => const Color(0xFF3C4A40);
  static Color get lightCardBackground => primaryGreen.withOpacity(0.05);
  static Color get darkBorderColor => darkBorder;
  static Color get lightBorderColor => lightBorder;

  // Legacy primary getter for compatibility
  static Color get primary => primaryGreen;
}
