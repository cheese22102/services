import 'package:flutter/material.dart';

class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final String? Function(String?)? validator;
  final Function(String)? onChanged; // Add this line for the onChanged callback

  const CustomTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    required this.obscure,
    this.validator,
    this.onChanged, // Add this to the constructor
  });

  @override
  _CustomTextFieldState createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  bool _passwordVisible = false;

  @override
  void initState() {
    super.initState();
    _passwordVisible = !widget.obscure;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(30),
      ),
      child: TextFormField(
        controller: widget.controller,
        obscureText: widget.obscure ? !_passwordVisible : false,
        validator: widget.validator,
        onChanged: widget.onChanged, // Add this line to pass the onChanged callback
        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color),
        decoration: InputDecoration(
          icon: Icon(widget.icon, color: Theme.of(context).iconTheme.color),
          hintText: widget.hint,
          hintStyle: TextStyle(color: Theme.of(context).hintColor),
          border: InputBorder.none,
          suffixIcon: widget.obscure
              ? IconButton(
                  icon: Icon(
                    _passwordVisible ? Icons.visibility : Icons.visibility_off,
                    color: Theme.of(context).iconTheme.color,
                  ),
                  onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                )
              : null,
        ),
      ),
    );
  }
}