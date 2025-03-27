import 'package:flutter/material.dart';

class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData? icon;
  final bool obscure;
  final String? Function(String?)? validator;
  final Widget? suffixIcon;  // Add this line

  const CustomTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.icon,
    this.obscure = false,
    this.validator,
    this.suffixIcon,  // Add this line
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE8E8E8),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[400]!,
          width: 1,
        ),
      ),
      child: TextFormField(
        controller: widget.controller,
        obscureText: widget.obscure,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: TextStyle(
            color: isDark ? Colors.grey[400] : const Color(0xFF9E9E9E),
          ),
          prefixIcon: Icon(
            widget.icon,
            color: isDark ? Colors.grey[400] : const Color(0xFF757575),
          ),
          suffixIcon: widget.suffixIcon,  // Add this line
          border: InputBorder.none,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide.none,
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide.none,
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(25),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE8E8E8),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 15,
          ),
        ),
        validator: widget.validator,
      ),
    );
  }
}