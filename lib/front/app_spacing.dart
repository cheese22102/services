import 'package:flutter/material.dart';

class AppSpacing {
  // Base spacing unit
  static const double base = 8.0;
  
  // Spacing scale
  static const double xxs = base * 0.25; // 2
  static const double xs = base * 0.5;  // 4
  static const double sm = base;        // 8
  static const double md = base * 2;    // 16
  static const double lg = base * 3;    // 24
  static const double xl = base * 4;    // 32
  static const double xxl = base * 6;   // 48
  static const double xxxl = base * 8;  // 64
  
  // Specific use cases
  static const double cardPadding = md;
  static const double screenPadding = md;
  static const double sectionSpacing = lg;
  static const double elementSpacing = sm;
  
  // Border radius
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusXxl = 24.0;
  
  // Icon sizes
  static const double iconXs = 16.0;
  static const double iconSm = 20.0;
  static const double iconMd = 24.0;
  static const double iconLg = 32.0;
  static const double iconXl = 48.0;
  
  // Button heights
  static const double buttonSmall = 36.0;
  static const double buttonMedium = 44.0;
  static const double buttonLarge = 52.0;

  // Vertical spacing
  static SizedBox verticalSpacing(double height) {
    return SizedBox(height: height);
  }

  // Horizontal spacing
  static SizedBox horizontalSpacing(double width) {
    return SizedBox(width: width);
  }
}
