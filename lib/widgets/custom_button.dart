import 'package:flutter/material.dart';

class CustomButton extends StatelessWidget {
  final String text;
  final Function()? onPressed;
  final IconData icon; // Déclaré mais pas utilisé actuellement

  const CustomButton({
    super.key, 
    required this.text, 
    required this.onPressed, 
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
      ),
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 10),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 18)),
        ],
      ),
    );
  }
}