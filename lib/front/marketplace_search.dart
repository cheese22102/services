import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class MarketplaceSearch extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onClear;
  final String hintText;
  final ValueChanged<String>? onChanged; // <-- Add this line

  const MarketplaceSearch({
    super.key,
    required this.controller,
    required this.onClear,
    this.hintText = 'Rechercher un article...',
    this.onChanged, // <-- Add this line
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade800.withOpacity(0.8) : Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: TextField(
          controller: controller,
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.white : Colors.black87,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.poppins(
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade500,
              fontSize: 14,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
              size: 22,
            ),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear_rounded,
                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                      size: 20,
                    ),
                    onPressed: onClear,
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            isDense: true,
            filled: true,
            fillColor: isDarkMode ? Colors.grey.shade800.withOpacity(0.8) : Colors.white,
          ),
          cursorColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
          textAlignVertical: TextAlignVertical.center,
          onChanged: onChanged, // <-- Add this line
        ),
      ),
    );
  }
}