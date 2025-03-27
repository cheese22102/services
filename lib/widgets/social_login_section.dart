import 'package:flutter/material.dart';
import 'social_icon.dart';

class SocialLoginSection extends StatelessWidget {
  final VoidCallback onGoogleTap;
  final bool isDark;

  const SocialLoginSection({
    super.key,
    required this.onGoogleTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Divider(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Ou continuer avec',
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ),
            Expanded(
              child: Divider(
                color: isDark ? Colors.grey[700] : Colors.grey[300],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: isDark 
                  ? Colors.black12
                  : Colors.grey.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onGoogleTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 24,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SocialIcon(
                      imagePath: "assets/images/google.jpg",
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Google',
                      style: TextStyle(
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}