import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  // Heading styles
  static TextStyle h1(BuildContext context, {Color? color}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GoogleFonts.poppins(
      fontSize: 32,
      fontWeight: FontWeight.bold,
      color: color ?? (isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
      height: 1.2,
    );
  }

  static TextStyle h2(BuildContext context, {Color? color}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GoogleFonts.poppins(
      fontSize: 24,
      fontWeight: FontWeight.bold,
      color: color ?? (isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
      height: 1.3,
    );
  }

  static TextStyle h3(BuildContext context, {Color? color}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GoogleFonts.poppins(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: color ?? (isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
      height: 1.4,
    );
  }

  static TextStyle h4(BuildContext context, {Color? color}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GoogleFonts.poppins(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: color ?? (isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
      height: 1.4,
    );
  }

  // Body text styles
  static TextStyle bodyLarge(BuildContext context, {Color? color}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GoogleFonts.poppins(
      fontSize: 16,
      fontWeight: FontWeight.normal,
      color: color ?? (isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
      height: 1.5,
    );
  }

  static TextStyle bodyMedium(BuildContext context, {Color? color}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GoogleFonts.poppins(
      fontSize: 14,
      fontWeight: FontWeight.normal,
      color: color ?? (isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
      height: 1.5,
    );
  }

  static TextStyle bodySmall(BuildContext context, {Color? color}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GoogleFonts.poppins(
      fontSize: 12,
      fontWeight: FontWeight.normal,
      color: color ?? (isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
      height: 1.4,
    );
  }

  // Label styles
  static TextStyle labelLarge(BuildContext context, {Color? color}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GoogleFonts.poppins(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: color ?? (isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
      height: 1.4,
    );
  }

  static TextStyle labelMedium(BuildContext context, {Color? color}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GoogleFonts.poppins(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: color ?? (isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
      height: 1.3,
    );
  }

  static TextStyle labelSmall(BuildContext context, {Color? color}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GoogleFonts.poppins(
      fontSize: 10,
      fontWeight: FontWeight.w500,
      color: color ?? (isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
      height: 1.2,
    );
  }

  // Special styles
  static TextStyle caption(BuildContext context, {Color? color}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GoogleFonts.poppins(
      fontSize: 11,
      fontWeight: FontWeight.normal,
      color: color ?? (isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint),
      height: 1.3,
    );
  }

  static TextStyle button(BuildContext context, {Color? color}) {
    return GoogleFonts.poppins(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: color ?? Colors.white,
      height: 1.2,
    );
  }

  // New styles to match GoogleFonts.poppins usage in reservation_details_page.dart
  static TextStyle headlineMedium(BuildContext context, {Color? color}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GoogleFonts.poppins(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: color ?? (isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
      height: 1.4,
    );
  }

  static TextStyle headlineSmall(BuildContext context, {Color? color}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GoogleFonts.poppins(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: color ?? (isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
      height: 1.4,
    );
  }

  static TextStyle titleLarge(BuildContext context, {Color? color}) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GoogleFonts.poppins(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: color ?? (isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
      height: 1.5,
    );
  }
}
