import 'package:flutter/material.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  final String password;
<<<<<<< Updated upstream
  
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
=======

  const PasswordStrengthIndicator({super.key, required this.password});

  double _calculateStrength() {
    int score = 0;
    
    if (password.isEmpty) return 0;
    if (password.length < 6) return 0.2;
    
    // Basic length contribution
    score += password.length >= 8 ? 2 : 1;
    
    // Complexity checks
    if (RegExp(r'[A-Z]').hasMatch(password)) score += 2; // Uppercase
    if (RegExp(r'[a-z]').hasMatch(password)) score += 2; // Lowercase
    if (RegExp(r'[0-9]').hasMatch(password)) score += 2; // Numbers
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) score += 2; // Special chars
    
    // Calculate final strength (max score is 10)
    return (score / 10).clamp(0.0, 1.0);
  }

  String _getStrengthText() {
    double strength = _calculateStrength();
    if (strength <= 0.2) return 'Très faible';
    if (strength <= 0.4) return 'Faible';
    if (strength <= 0.6) return 'Moyen';
    if (strength <= 0.8) return 'Fort';
    return 'Très fort';
  }

  Color _getStrengthColor() {
    double strength = _calculateStrength();
    if (strength <= 0.2) return Colors.red;
    if (strength <= 0.4) return Colors.orange;
    if (strength <= 0.6) return Colors.yellow;
    if (strength <= 0.8) return Colors.lightGreen;
>>>>>>> Stashed changes
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
<<<<<<< Updated upstream
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
=======
        Expanded(
          flex: 7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _calculateStrength(),
                  backgroundColor: Colors.grey[300],
                  color: _getStrengthColor(),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _getStrengthText(),
                style: TextStyle(
                  color: _getStrengthColor(),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: Text(
            _getPasswordRequirements(),
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
>>>>>>> Stashed changes
          ),
        ),
      ],
    );
  }

  String _getPasswordRequirements() {
    List<String> missing = [];
    
    if (!RegExp(r'[A-Z]').hasMatch(password)) missing.add('majuscule');
    if (!RegExp(r'[a-z]').hasMatch(password)) missing.add('minuscule');
    if (!RegExp(r'[0-9]').hasMatch(password)) missing.add('chiffre');
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) 
      missing.add('caractère spécial');
    if (password.length < 8) missing.add('8 caractères');
    
    if (missing.isEmpty) return 'Excellent!';
    return 'Manque: ${missing.join(', ')}';
  }
}