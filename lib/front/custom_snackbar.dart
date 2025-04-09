import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomSnackbar {
  /// Shows a custom styled snackbar that matches the app's design
  static void show({
    required BuildContext context,
    required String message,
    bool isError = true,
    Duration duration = const Duration(seconds: 4),
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    final snackBar = SnackBar(
      content: Text(
        message,
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: isError 
          ? (isDarkMode ? const Color(0xFF8B2D2D) : const Color(0xFFD32F2F))
          : (isDarkMode ? const Color(0xFF3A523E) : const Color(0xFF4CAF50)),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.all(16),
      duration: duration,
      action: SnackBarAction(
        label: 'OK',
        textColor: Colors.white,
        onPressed: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        },
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
  
  /// Shows a success message
  static void showSuccess({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context: context,
      message: message,
      isError: false,
      duration: duration,
    );
  }
  
  /// Shows an error message
  static void showError({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 4),
  }) {
    show(
      context: context,
      message: message,
      isError: true,
      duration: duration,
    );
  }
  
  /// Shows an info message
  static void showInfo({
    required BuildContext context,
    required String message,
    Duration duration = const Duration(seconds: 4),
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    final snackBar = SnackBar(
      content: Text(
        message,
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: isDarkMode ? const Color(0xFF2D4263) : const Color(0xFF2196F3),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      margin: const EdgeInsets.all(16),
      duration: duration,
      action: SnackBarAction(
        label: 'OK',
        textColor: Colors.white,
        onPressed: () {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
        },
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }
}