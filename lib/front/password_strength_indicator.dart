import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PasswordStrengthIndicator extends StatelessWidget {
  final String password;
  final bool isDarkMode;

  const PasswordStrengthIndicator({
    Key? key,
    required this.password,
    required this.isDarkMode,
  }) : super(key: key);

  double _calculateStrength() {
    if (password.isEmpty) return 0.0;
    
    double strength = 0.0;
    
    // Length check - more granular scoring
    if (password.length >= 6) strength += 0.15;
    if (password.length >= 8) strength += 0.1;
    if (password.length >= 10) strength += 0.05;
    
    // Character type checks
    if (RegExp(r'[A-Z]').hasMatch(password)) strength += 0.2; // Uppercase
    if (RegExp(r'[a-z]').hasMatch(password)) strength += 0.2; // Lowercase
    if (RegExp(r'[0-9]').hasMatch(password)) strength += 0.2; // Numbers
    
    // Special characters - more value for security
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength += 0.15;
    
    // Penalize common patterns
    if (RegExp(r'123|abc|qwerty|password|azerty').hasMatch(password.toLowerCase())) {
      strength -= 0.1;
    }
    
    return strength > 1.0 ? 1.0 : (strength < 0.0 ? 0.0 : strength);
  }

  Color _getStrengthColor() {
    final strength = _calculateStrength();
    
    if (strength < 0.3) return Colors.red.shade700;
    if (strength < 0.6) return Colors.orange.shade700;
    if (strength < 0.8) return Colors.amber.shade600;
    return Colors.green.shade600;
  }

  String _getStrengthText() {
    final strength = _calculateStrength();
    
    if (strength < 0.3) return 'Faible';
    if (strength < 0.6) return 'Moyen';
    if (strength < 0.8) return 'Bon';
    return 'Fort';
  }

  List<Map<String, dynamic>> _getPasswordCriteria() {
    return [
      {
        'title': 'Au moins 6 caractères',
        'met': password.length >= 6,
        'icon': password.length >= 6 ? Icons.check_circle : Icons.cancel,
      },
      {
        'title': 'Au moins une majuscule',
        'met': RegExp(r'[A-Z]').hasMatch(password),
        'icon': RegExp(r'[A-Z]').hasMatch(password) ? Icons.check_circle : Icons.cancel,
      },
      {
        'title': 'Au moins une minuscule',
        'met': RegExp(r'[a-z]').hasMatch(password),
        'icon': RegExp(r'[a-z]').hasMatch(password) ? Icons.check_circle : Icons.cancel,
      },
      {
        'title': 'Au moins un chiffre',
        'met': RegExp(r'[0-9]').hasMatch(password),
        'icon': RegExp(r'[0-9]').hasMatch(password) ? Icons.check_circle : Icons.cancel,
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) {
      return const SizedBox.shrink();
    }

    final criteria = _getPasswordCriteria();
    final strength = _calculateStrength();
    final strengthColor = _getStrengthColor();
    final strengthText = _getStrengthText();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode 
            ? Colors.grey.shade900.withOpacity(0.5) 
            : Colors.grey.shade100.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: strengthColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Strength meter
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Force du mot de passe: $strengthText',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode 
                            ? Colors.grey.shade300 
                            : Colors.grey.shade800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: strength,
                        backgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
                        color: strengthColor,
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: strengthColor.withOpacity(0.1),
                ),
                child: Center(
                  child: Text(
                    '${(strength * 100).toInt()}%',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: strengthColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Requirements grid
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: criteria.map((criterion) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    criterion['icon'] as IconData,
                    color: criterion['met'] 
                        ? Colors.green.shade600 
                        : Colors.red.shade400,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    criterion['title'] as String,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: isDarkMode 
                          ? Colors.grey.shade400 
                          : Colors.grey.shade700,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
          
          // Suggestion for stronger password if weak
          if (strength < 0.5) ...[
            const SizedBox(height: 8),
            Text(
              'Conseil: Ajoutez des caractères spéciaux (!@#\$) pour renforcer votre mot de passe.',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: isDarkMode 
                    ? Colors.amber.shade300 
                    : Colors.amber.shade800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}