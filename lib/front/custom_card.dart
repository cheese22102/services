import 'package:flutter/material.dart';
import 'app_colors.dart';

class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? elevation;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final VoidCallback? onTap;
  final bool isClickable;

  const CustomCard({
    Key? key,
    required this.child,
    this.padding,
    this.margin,
    this.elevation,
    this.backgroundColor,
    this.borderRadius,
    this.border,
    this.boxShadow,
    this.onTap,
    this.isClickable = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    final defaultBackgroundColor = backgroundColor ?? 
        (isDarkMode ? AppColors.darkCardBackground : AppColors.lightCardBackground);
    
    final defaultBorderRadius = borderRadius ?? BorderRadius.circular(16);
    
    final defaultBoxShadow = boxShadow ?? [
      BoxShadow(
        color: isDarkMode 
            ? Colors.black.withOpacity(0.2)
            : Colors.black.withOpacity(0.08),
        blurRadius: 8,
        offset: const Offset(0, 2),
        spreadRadius: 0,
      ),
    ];

    Widget cardContent = Container(
      margin: margin ?? const EdgeInsets.all(8),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: defaultBackgroundColor,
        borderRadius: defaultBorderRadius,
        border: border,
        boxShadow: elevation != null ? null : defaultBoxShadow,
      ),
      child: child,
    );

    if (isClickable && onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: defaultBorderRadius,
          child: cardContent,
        ),
      );
    }

    if (elevation != null) {
      return Card(
        margin: margin ?? const EdgeInsets.all(8),
        elevation: elevation!,
        color: defaultBackgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: defaultBorderRadius,
        ),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      );
    }

    return cardContent;
  }
}