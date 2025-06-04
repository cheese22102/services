import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_spacing.dart'; // Import AppSpacing
import 'app_typography.dart'; // Import AppTypography

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
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg), // Use AppSpacing
          ),
          backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground, // Use AppColors
          title: Text(
            title,
            style: AppTypography.h4(context).copyWith( // Use AppTypography
              color: isError 
                  ? (isDarkMode ? AppColors.errorDarkRed : AppColors.errorLightRed) // Use AppColors
                  : (isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary), // Use AppColors
            ),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Text(
              message,
              style: AppTypography.bodyMedium(context).copyWith( // Use AppTypography
                color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, // Use AppColors
              ),
              textAlign: TextAlign.center,
            ),
          ),
          actions: <Widget>[
            if (cancelText != null)
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm), // Use AppSpacing
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd), // Use AppSpacing
                  ),
                ),
                child: Text(
                  cancelText,
                  style: AppTypography.button(context).copyWith( // Corrected to AppTypography.button
                    color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, // Use AppColors
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
                    ? (isDarkMode ? AppColors.errorDarkRed : AppColors.errorLightRed)
                    : AppColors.primaryGreen, // Use AppColors
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm), // Use AppSpacing
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd), // Use AppSpacing
                ),
                elevation: 2,
              ),
              child: Text(
                confirmText ?? 'OK',
                style: AppTypography.button(context), // Corrected to AppTypography.button
              ),
            ),
          ],
        );
      },
    );
  }
  
  /// Enhanced confirmation dialog with better visual design for post preview
  static Future<bool?> showPostConfirmation({
    required BuildContext context,
    required String title,
    required String description,
    required String price,
    required String condition,
    required String category,
    required String location,
    required int imageCount,
    String confirmText = 'Publier',
    String cancelText = 'Modifier',
  }) async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl), // Use AppSpacing
          ),
          backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground, // Use AppColors
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with icon and gradient
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(AppSpacing.lg), // Use AppSpacing
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        isDarkMode ? AppColors.primaryDarkGreen : AppColors.primaryGreen, // Consistent gradient
                        isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(AppSpacing.radiusXl), // Use AppSpacing
                      topRight: Radius.circular(AppSpacing.radiusXl), // Use AppSpacing
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(AppSpacing.md), // Use AppSpacing
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.preview,
                          color: Colors.white,
                          size: AppSpacing.iconLg, // Use AppSpacing
                        ),
                      ),
                      SizedBox(height: AppSpacing.md), // Use AppSpacing
                      Text(
                        'Aperçu de votre annonce',
                        style: AppTypography.h3(context).copyWith( // Corrected to AppTypography.h3
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: AppSpacing.xs), // Use AppSpacing
                      Text(
                        'Vérifiez les informations avant de soumettre votre annonce',
                        style: AppTypography.bodyMedium(context).copyWith( // Use AppTypography
                          color: Colors.white.withOpacity(0.9),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(AppSpacing.lg), // Use AppSpacing
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(
                          context: context, // Pass context
                          icon: Icons.title,
                          label: 'Titre',
                          value: title,
                          isDarkMode: isDarkMode,
                        ),
                        SizedBox(height: AppSpacing.md), // Use AppSpacing
                        _buildInfoRow(
                          context: context, // Pass context
                          icon: Icons.description,
                          label: 'Description',
                          value: description,
                          isDarkMode: isDarkMode,
                          maxLines: 3,
                        ),
                        SizedBox(height: AppSpacing.md), // Use AppSpacing
                        Row(
                          children: [
                            Expanded(
                              child: _buildInfoRow(
                                context: context, // Pass context
                                icon: Icons.attach_money,
                                label: 'Prix',
                                value: '$price TND',
                                isDarkMode: isDarkMode,
                              ),
                            ),
                            SizedBox(width: AppSpacing.md), // Use AppSpacing
                            Expanded(
                              child: _buildInfoRow(
                                context: context, // Pass context
                                icon: Icons.info_outline,
                                label: 'État',
                                value: condition,
                                isDarkMode: isDarkMode,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: AppSpacing.md), // Use AppSpacing
                        _buildInfoRow(
                          context: context, // Pass context
                          icon: Icons.category,
                          label: 'Catégorie',
                          value: category,
                          isDarkMode: isDarkMode,
                        ),
                        SizedBox(height: AppSpacing.md), // Use AppSpacing
                        _buildInfoRow(
                          context: context, // Pass context
                          icon: Icons.location_on,
                          label: 'Localisation',
                          value: location,
                          isDarkMode: isDarkMode,
                        ),
                        SizedBox(height: AppSpacing.md), // Use AppSpacing
                        _buildInfoRow(
                          context: context, // Pass context
                          icon: Icons.photo_library,
                          label: 'Images',
                          value: '$imageCount image${imageCount > 1 ? 's' : ''}',
                          isDarkMode: isDarkMode,
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Actions
                Container(
                  padding: EdgeInsets.all(AppSpacing.lg), // Use AppSpacing
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: AppSpacing.md), // Use AppSpacing
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppSpacing.radiusMd), // Use AppSpacing
                              side: BorderSide(
                                color: isDarkMode ? AppColors.darkBorderColor : AppColors.lightBorderColor, // Use AppColors
                              ),
                            ),
                          ),
                          child: Text(
                            cancelText,
                            style: AppTypography.button(context).copyWith( // Corrected to AppTypography.button
                              color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, // Use AppColors
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: AppSpacing.md), // Use AppSpacing
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen, // Use AppColors
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: AppSpacing.md), // Use AppSpacing
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppSpacing.radiusMd), // Use AppSpacing
                            ),
                            elevation: 2,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.publish, size: AppSpacing.iconMd), // Use AppSpacing
                              SizedBox(width: AppSpacing.xs), // Use AppSpacing
                              Text(
                                confirmText,
                                style: AppTypography.button(context), // Corrected to AppTypography.button
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  static Widget _buildInfoRow({
    required BuildContext context, // Added context
    required IconData icon,
    required String label,
    required String value,
    required bool isDarkMode,
    int maxLines = 1,
  }) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.md), // Use AppSpacing
      decoration: BoxDecoration(
        color: isDarkMode 
            ? AppColors.darkCardBackground // Use AppColors
            : AppColors.lightCardBackground, // Use AppColors
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd), // Use AppSpacing
        border: Border.all(
          color: isDarkMode ? AppColors.darkBorderColor : AppColors.lightBorderColor, // Use AppColors
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(AppSpacing.xs), // Use AppSpacing
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusXs), // Use AppSpacing
            ),
            child: Icon(
              icon,
              color: AppColors.primaryGreen,
              size: AppSpacing.iconSm, // Use AppSpacing
            ),
          ),
          SizedBox(width: AppSpacing.md), // Use AppSpacing
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.labelSmall(context).copyWith( // Use AppTypography
                    color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, // Use AppColors
                  ),
                ),
                SizedBox(height: AppSpacing.xs), // Use AppSpacing
                Text(
                  value,
                  style: AppTypography.bodyLarge(context).copyWith( // Use AppTypography
                    color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, // Use AppColors
                  ),
                  maxLines: maxLines,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
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
