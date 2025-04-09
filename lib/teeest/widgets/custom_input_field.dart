import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app_colors.dart';

class CustomInputField extends StatelessWidget {
  final String label;
  final String placeholder;
  final bool isPassword;
  final TextEditingController? controller;
  final VoidCallback? onToggleVisibility;
  final bool obscureText;

  const CustomInputField({
    Key? key,
    required this.label,
    required this.placeholder,
    this.isPassword = false,
    this.controller,
    this.onToggleVisibility,
    this.obscureText = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: AppColors.inputBackground,
          ),
          child: TextFormField(
            controller: controller,
            obscureText: isPassword && obscureText,
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: AppColors.textDark,
            ),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: GoogleFonts.poppins(
                fontSize: 16,
                color: AppColors.textGrey.withOpacity(0.5),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 20,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(
                  color: AppColors.inputBorder,
                  width: 2,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(
                  color: AppColors.inputBorder,
                  width: 2,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 2,
                ),
              ),
              suffixIcon: isPassword
                  ? IconButton(
                      icon: Icon(
                        obscureText ? Icons.visibility : Icons.visibility_off,
                        color: AppColors.textGrey,
                      ),
                      onPressed: onToggleVisibility,
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}