import 'package:flutter/material.dart';

class CustomSnackbar {
  /// Shows a custom styled snackbar that matches the app's design
  static void show({
    required BuildContext context,
    required String message,
    bool isError = true,
    Duration duration = const Duration(seconds: 4),
  }) {
    // Ensure the context is mounted before showing the snackbar
    if (!context.mounted) {
      return;
    }

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    final backgroundColor = isError 
        ? (isDarkMode ? const Color(0xFF8B2D2D) : const Color(0xFFD32F2F))
        : (isDarkMode ? const Color(0xFF3A523E) : const Color(0xFF4CAF50));
    final textColor = Colors.white;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Builder( // Added Builder to get a new context for the button
          builder: (builderContext) => Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: textColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(builderContext).textTheme.bodyMedium?.copyWith( // Use builderContext
                    fontSize: 14,
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(builderContext).hideCurrentSnackBar(); // Use builderContext
                },
                child: Text(
                  'OK',
                  style: Theme.of(builderContext).textTheme.labelLarge?.copyWith( // Use builderContext
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.fromLTRB(16, kToolbarHeight + 10, 16, 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
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
    show(
      context: context,
      message: message,
      isError: false, // Info is not an error
      duration: duration,
    );
  }
}
