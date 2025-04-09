import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF78B235);
  static const Color background = Colors.white;
  static const Color inputBackground = Color(0xFFF8FFF0);
  static const Color inputBorder = Color(0xFFE8F3D8);
  static const Color textDark = Color(0xFF000000);
  static const Color textGrey = Color(0xFF333333);

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF98C94B),
      Color(0xFF8CBB41),
      Color(0xFF80AE37),
      Color(0xFFCCFF00),
      Color(0xFFB2E426),
      Color(0xFF8CBB41),
      Color(0xFFB2E426),
    ],
    stops: [0.149, 0.25, 0.351, 0.399, 0.4663, 0.649, 0.6971],
  );
}