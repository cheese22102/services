import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart'; // Added import
import 'app_typography.dart'; // Added import
import 'loading_overlay.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed; // Changed to nullable
  final bool isPrimary;
  final bool isLoading;
  final Widget? icon;
  final double? width;
  final double height;
  final double borderRadius;
  final bool useFullScreenLoader;
  final Color? backgroundColor;
  final Color? textColor;
  final TextStyle? textStyle; // New parameter

  const CustomButton({
    Key? key,
    required this.text,
    required this.onPressed, // Still required but can be null
    this.isPrimary = true,
    this.isLoading = false,
    this.icon,
    this.width,
    this.height = AppSpacing.buttonMedium, // Using AppSpacing
    this.borderRadius = AppSpacing.radiusXxl, // Using AppSpacing
    this.useFullScreenLoader = false,
    this.backgroundColor,
    this.textColor,
    this.textStyle, // Initialize new parameter
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Determine background color with priority to custom backgroundColor
    final bgColor = backgroundColor ?? (isPrimary
        ? (isDarkMode ? AppColors.primaryDarkGreen : AppColors.primaryGreen)
        : (isDarkMode ? AppColors.darkInputBackground : Colors.white));
    
    // Determine text color with priority to custom textColor
    final txtColor = textColor ?? (isPrimary
        ? Colors.white
        : (isDarkMode ? Colors.white : Colors.black87));

    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading || onPressed == null ? null : () {
          if (useFullScreenLoader) {
            // Show loading overlay
            LoadingOverlay.show(context);
            
            // Execute the onPressed function
            onPressed!();
          } else {
            onPressed!();
          }
        },
        style: ButtonStyle(
          backgroundColor: MaterialStateProperty.resolveWith<Color>((states) {
            if (states.contains(MaterialState.pressed)) {
              return isDarkMode 
                  ? AppColors.primaryDarkGreen.withOpacity(0.7)
                  : AppColors.primaryGreen.withOpacity(0.7);
            }
            return bgColor;
          }),
          foregroundColor: MaterialStateProperty.all(txtColor),
          elevation: MaterialStateProperty.all(isPrimary ? 2 : 0),
          padding: MaterialStateProperty.all(
            const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm), // Using AppSpacing
          ),
          shape: MaterialStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(borderRadius),
              side: isPrimary
                  ? BorderSide.none
                  : BorderSide(color: isDarkMode ? Colors.white24 : Colors.black12),
            ),
          ),
        ),
        child: isLoading && !useFullScreenLoader
            ? SizedBox(
                width: AppSpacing.iconMd, // Using AppSpacing
                height: AppSpacing.iconMd, // Using AppSpacing
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
                  if (icon != null) icon!,
                  if (text.isNotEmpty) ...[
                    if (icon != null) const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      fit: FlexFit.loose,
                      child: Text(
                        text,
                        style: textStyle ?? AppTypography.button(context, color: txtColor),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }
}
