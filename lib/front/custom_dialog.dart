import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomDialog {
  /// Shows a custom styled dialog that matches the app's design
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required String message,
    String? confirmText,
    String? cancelText,
    bool isError = true,
    VoidCallback? onConfirm,
  }) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return showDialog<T>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          backgroundColor: isDarkMode ? const Color(0xFF2D3B33) : Colors.white,
          title: Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isError 
                  ? (isDarkMode ? Colors.redAccent : Colors.red)
                  : (isDarkMode ? Colors.white : Colors.black),
            ),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          actions: <Widget>[
            if (cancelText != null)
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  cancelText,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ElevatedButton(
              onPressed: () {
                if (onConfirm != null) {
                  onConfirm();
                }
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isError 
                    ? (isDarkMode ? const Color(0xFF8B2D2D) : const Color(0xFFD32F2F))
                    : (isDarkMode ? const Color(0xFF4CAF50) : const Color(0xFF8BC34A)),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                confirmText ?? 'OK',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  
  /// Shows an error dialog
  static Future<T?> showError<T>({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'OK',
    VoidCallback? onConfirm,
  }) async {
    return show<T>(
      context: context,
      title: title,
      message: message,
      confirmText: confirmText,
      isError: true,
      onConfirm: onConfirm,
    );
  }
  
  /// Shows a confirmation dialog
  static Future<bool?> showConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'Confirmer',
    String cancelText = 'Annuler',
    VoidCallback? onConfirm,
  }) async {
    return show<bool>(
      context: context,
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      isError: false,
      onConfirm: onConfirm,
    );
  }
  
  /// Shows a success dialog
  static Future<T?> showSuccess<T>({
    required BuildContext context,
    required String title,
    required String message,
    String confirmText = 'OK',
    VoidCallback? onConfirm,
  }) async {
    return show<T>(
      context: context,
      title: title,
      message: message,
      confirmText: confirmText,
      isError: false,
      onConfirm: onConfirm,
    );
  }
}