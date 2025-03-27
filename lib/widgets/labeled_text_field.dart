import 'package:flutter/material.dart';
import 'custom_text_field.dart';

class LabeledTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final bool obscure;
  final bool obscureText; // Added parameter for consistency
  final String? Function(String?)? validator;
  final Widget? suffixIcon;

  const LabeledTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint = '',
    this.icon,
    this.obscure = false,
    this.obscureText = false, // Default value
    this.validator,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).brightness == Brightness.dark 
              ? Colors.white 
              : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        CustomTextField(
          controller: controller,
          hint: hint,
          icon: icon,
          obscure: obscureText, // Use obscureText instead of obscure
          validator: validator,
          suffixIcon: suffixIcon,
        ),
      ],
    );
  }
}