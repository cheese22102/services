import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

enum SnackBarType {
  success,
  error,
  warning,
  info,
}

class CustomSnackBar {
  static OverlayEntry? _currentOverlayEntry;

  static void show({
    required BuildContext context,
    required String message,
    SnackBarType type = SnackBarType.info,
    Duration duration = const Duration(seconds: 3),
    String? actionLabel,
    VoidCallback? onActionPressed,
  }) {
    // Remove any existing snackbar overlay
    _currentOverlayEntry?.remove();
    _currentOverlayEntry = null;

    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    Color backgroundColor;
    Color textColor;
    IconData icon;
    
    switch (type) {
      case SnackBarType.success:
        backgroundColor = Colors.green.shade600;
        textColor = Colors.white;
        icon = Icons.check_circle_outline;
        break;
      case SnackBarType.error:
        backgroundColor = Colors.red.shade600;
        textColor = Colors.white;
        icon = Icons.error_outline;
        break;
      case SnackBarType.warning:
        backgroundColor = Colors.orange.shade600;
        textColor = Colors.white;
        icon = Icons.warning_outlined;
        break;
      case SnackBarType.info:
        backgroundColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;
        textColor = Colors.white;
        icon = Icons.info_outline;
        break;
    }

    _currentOverlayEntry = OverlayEntry(
      builder: (overlayContext) => Positioned(
        top: MediaQuery.of(context).padding.top + 10, // Offset from safe area top
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: SafeArea(
            child: GestureDetector(
              onTap: () {
                _currentOverlayEntry?.remove();
                _currentOverlayEntry = null;
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      color: textColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: GoogleFonts.poppins(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (actionLabel != null && onActionPressed != null)
                      TextButton(
                        onPressed: () {
                          onActionPressed();
                          _currentOverlayEntry?.remove();
                          _currentOverlayEntry = null;
                        },
                        child: Text(
                          actionLabel,
                          style: GoogleFonts.poppins(
                            color: textColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_currentOverlayEntry!);

    Future.delayed(duration, () {
      if (_currentOverlayEntry != null) {
        _currentOverlayEntry?.remove();
        _currentOverlayEntry = null;
      }
    });
  }

  static void showSuccess(BuildContext context, String message) {
    show(context: context, message: message, type: SnackBarType.success);
  }

  static void showError(BuildContext context, String message) {
    show(context: context, message: message, type: SnackBarType.error);
  }

  static void showWarning(BuildContext context, String message) {
    show(context: context, message: message, type: SnackBarType.warning);
  }

  static void showInfo(BuildContext context, String message) {
    show(context: context, message: message, type: SnackBarType.info);
  }
}
