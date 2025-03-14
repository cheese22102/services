import 'package:flutter/material.dart';

class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    required this.obscure,
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
        color: Theme.of(context).cardColor, // S'adapte au mode clair/sombre
        borderRadius: BorderRadius.circular(30),
      ),
      child: TextFormField(
        controller: widget.controller,
        obscureText: widget.obscure ? !_passwordVisible : false,
        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color), // Texte adaptatif
        decoration: InputDecoration(
          icon: Icon(widget.icon, color: Theme.of(context).iconTheme.color), // Icône adaptative
          hintText: widget.hint,
          hintStyle: TextStyle(color: Theme.of(context).hintColor), // Placeholder en mode sombre
          border: InputBorder.none,
          suffixIcon: widget.obscure
              ? IconButton(
                  icon: Icon(
                    _passwordVisible ? Icons.visibility : Icons.visibility_off,
                    color: Theme.of(context).iconTheme.color, // S'adapte au mode sombre
                  ),
                  onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                )
              : null,
        ),
      ),
    );
  }
}
