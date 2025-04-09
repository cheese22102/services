import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'loading_overlay.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isPrimary;
  final bool isLoading;
  final Widget? icon;
  final double? width;
  final double height;
  final double borderRadius;
  final bool useFullScreenLoader;

  const CustomButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.isPrimary = true,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height = 50,
    this.borderRadius = 24,
    this.useFullScreenLoader = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : () {
          if (useFullScreenLoader) {
            // Show loading overlay
            LoadingOverlay.show(context);
            
            // Execute the onPressed function
            onPressed();
          } else {
            onPressed();
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary
              ? (isDarkMode ? AppColors.primaryDarkGreen : AppColors.primaryGreen)
              : (isDarkMode ? AppColors.darkInputBackground : Colors.white),
          foregroundColor: isPrimary
              ? Colors.white
              : (isDarkMode ? Colors.white : Colors.black87),
          elevation: isPrimary ? 2 : 0,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
            side: isPrimary
                ? BorderSide.none
                : BorderSide(color: isDarkMode ? Colors.white24 : Colors.black12),
          ),
        ),
        child: isLoading && !useFullScreenLoader
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isPrimary ? Colors.white : (isDarkMode ? Colors.white70 : Colors.black54),
                  ),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    icon!,
                    const SizedBox(width: 8),
                  ],
                  Text(
                    text,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}