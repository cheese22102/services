import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

enum StatusType {
  pending,
  approved,
  rejected,
  completed,
  cancelled,
  active,
  inactive,
}

class StatusBadge extends StatelessWidget {
  final StatusType status;
  final String? customText;
  final Color? customColor;
  final IconData? customIcon;
  final bool showIcon;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  const StatusBadge({
    Key? key,
    required this.status,
    this.customText,
    this.customColor,
    this.customIcon,
    this.showIcon = true,
    this.fontSize = 12,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    String text;
    Color backgroundColor;
    Color textColor;
    IconData? icon;

    switch (status) {
      case StatusType.pending:
        text = customText ?? 'En attente';
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade800;
        icon = Icons.schedule;
        break;
      case StatusType.approved:
        text = customText ?? 'Approuvé';
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade800;
        icon = Icons.check_circle;
        break;
      case StatusType.rejected:
        text = customText ?? 'Rejeté';
        backgroundColor = Colors.red.shade100;
        textColor = Colors.red.shade800;
        icon = Icons.cancel;
        break;
      case StatusType.completed:
        text = customText ?? 'Terminé';
        backgroundColor = Colors.blue.shade100;
        textColor = Colors.blue.shade800;
        icon = Icons.done_all;
        break;
      case StatusType.cancelled:
        text = customText ?? 'Annulé';
        backgroundColor = Colors.grey.shade200;
        textColor = Colors.grey.shade700;
        icon = Icons.close;
        break;
      case StatusType.active:
        text = customText ?? 'Actif';
        backgroundColor = AppColors.primaryGreen.withOpacity(0.1);
        textColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;
        icon = Icons.radio_button_checked;
        break;
      case StatusType.inactive:
        text = customText ?? 'Inactif';
        backgroundColor = Colors.grey.shade200;
        textColor = Colors.grey.shade600;
        icon = Icons.radio_button_unchecked;
        break;
    }

    if (customColor != null) {
      backgroundColor = customColor!.withOpacity(0.1);
      textColor = customColor!;
    }

    if (customIcon != null) {
      icon = customIcon;
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: textColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon && icon != null) 
            Icon(
              icon,
              size: fontSize + 2,
              color: textColor,
            ),
            const SizedBox(width: 4),
          
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}