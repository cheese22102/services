import 'package:flutter/material.dart';

class CustomAvatar extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final VoidCallback? onTap;
  final IconData placeholderIcon;

  const CustomAvatar({
    super.key,
    this.imageUrl,
    this.size = 120,
    this.onTap,
    this.placeholderIcon = Icons.person,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Color(0xFFF5F5F5),
          shape: BoxShape.circle,
          image: imageUrl != null
              ? DecorationImage(
                  image: NetworkImage(imageUrl!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: imageUrl == null
            ? Icon(
                placeholderIcon,
                size: size * 0.4,
                color: Colors.grey,
              )
            : null,
      ),
    );
  }
}