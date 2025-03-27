import 'package:flutter/material.dart';
import 'social_icon.dart';

class SocialLoginButtons extends StatelessWidget {
  final VoidCallback onGoogleTap;
  final VoidCallback onFacebookTap;
  final VoidCallback onAppleTap;

  const SocialLoginButtons({
    super.key,
    required this.onGoogleTap,
    required this.onFacebookTap,
    required this.onAppleTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('Or continue with'),
              ),
              Expanded(child: Divider()),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildSocialButton(
              onTap: onGoogleTap,
              imagePath: 'assets/images/google.png',
            ),
            const SizedBox(width: 16),
            _buildSocialButton(
              onTap: onFacebookTap,
              imagePath: 'assets/images/facebook.png',
            ),
            const SizedBox(width: 16),
            _buildSocialButton(
              onTap: onAppleTap,
              imagePath: 'assets/images/apple.png',
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSocialButton({
    required VoidCallback onTap,
    required String imagePath,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SocialIcon(imagePath: imagePath),
      ),
    );
  }
}