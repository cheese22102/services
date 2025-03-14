import 'package:flutter/material.dart';

class SocialIcon extends StatelessWidget {
  final String imagePath;

  const SocialIcon({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: CircleAvatar(
        radius: 20,
        backgroundColor: Colors.white,
        backgroundImage: AssetImage(imagePath),
      ),
    );
  }
}
