import 'package:flutter/material.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  final String password;
  
  const PasswordStrengthIndicator({super.key, required this.password});

  double get _strength {
    if (password.isEmpty) return 0;
    double strength = 0;
    if (password.length >= 8) strength += 0.3;
    if (password.contains(RegExp(r'[A-Z]'))) strength += 0.3;
    if (password.contains(RegExp(r'[0-9]'))) strength += 0.2;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength += 0.2;
    return strength.clamp(0, 1);
  }

  String get _text {
    if (_strength < 0.3) return 'Faible';
    if (_strength < 0.6) return 'Moyen';
    return 'Fort';
  }

  Color get _color {
    if (_strength < 0.3) return Colors.red;
    if (_strength < 0.6) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: _strength,
          backgroundColor: Colors.grey[200],
          color: _color,
          minHeight: 8,
        ),
        const SizedBox(height: 4),
        Text(
          'Force du mot de passe: $_text',
          style: TextStyle(
            color: _color,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}