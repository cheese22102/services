import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import '../widgets/custom_button.dart';
import '../widgets/auth_page_template.dart';

class VerificationPage extends StatefulWidget {
  const VerificationPage({super.key});

  @override
  _VerificationPageState createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  late User _user;
  bool _isLoading = false;
  Timer? _timer;
  int _timeoutSeconds = 60; // Countdown for resend button
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser!;
    _startVerificationCheck();
    _startResendTimeout();
  }

  void _startVerificationCheck() {
    // Check every 3 seconds
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _checkVerification());
  }

  void _startResendTimeout() {
    setState(() => _canResend = false);
    Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (_timeoutSeconds > 0) {
        setState(() => _timeoutSeconds--);
      } else {
        setState(() => _canResend = true);
        timer.cancel();
      }
    });
  }

  Future<void> _checkVerification() async {
    try {
      await _user.reload();
      final currentUser = FirebaseAuth.instance.currentUser!;
      
      if (currentUser.emailVerified) {
        _timer?.cancel();
        
        // Update Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({'emailVerified': true});
        
        if (!mounted) return;
        
        // Show success message before redirecting
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email vérifié avec succès!'),
            backgroundColor: Colors.green,
          ),
        );

        // Small delay to show the success message
        await Future.delayed(const Duration(seconds: 1));
        
        if (!mounted) return;
        _navigateBasedOnProfile();
      }
    } catch (e) {
      debugPrint('Error checking verification: $e');
    }
  }

  Future<void> _resendVerification() async {
    if (!_canResend) return;

    setState(() => _isLoading = true);
    try {
      await _user.sendEmailVerification();
      _timeoutSeconds = 60;
      _startResendTimeout();
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email de vérification renvoyé!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return AuthPageTemplate(
      title: "Vérification Email",
      subtitle: "Veuillez vérifier votre adresse email",
      imagePath: "assets/images/email_verification.png", // Make sure to add this image
      showBackButton: false, // Disable back button to prevent skipping verification
      children: [
        const SizedBox(height: 20),
        
        // Email display
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: (isDark ? Colors.green[800]! : Colors.green).withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: (isDark ? Colors.green[700]! : Colors.green[300])!,
              width: 1,
            ),
          ),
          child: Text(
            _user.email ?? '',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.green[400] : Colors.green,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Instructions
        Text(
          'Nous avons envoyé un email de vérification à votre adresse. '
          'Veuillez cliquer sur le lien dans l\'email pour activer votre compte.',
          style: TextStyle(
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
        
        const SizedBox(height: 32),
        
        // Resend button with countdown
        CustomButton(
          text: _canResend 
            ? "Renvoyer l'email"
            : "Renvoyer l'email (${_timeoutSeconds}s)",
          onPressed: _canResend && !_isLoading ? _resendVerification : null,
          isLoading: _isLoading,
        ),
        
        const SizedBox(height: 24),
        
        // Check spam folder note
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: (isDark ? Colors.orange[900] : Colors.orange[50])!,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.orange[300]!,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.orange[700],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Si vous ne trouvez pas l\'email, vérifiez votre dossier spam.',
                  style: TextStyle(
                    color: isDark ? Colors.orange[100] : Colors.orange[900],
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Add this method
  Future<void> _navigateBasedOnProfile() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(_user.uid)
        .get();

    if (!mounted) return;

    if (doc.exists) {
      final data = doc.data();
      final role = data?['role'] ?? 'client';
      final profileCompleted = data?['profileCompleted'] ?? false;

      if (profileCompleted) {
        if (!mounted) return;
        context.go(role == 'client' ? '/clientHome' : '/prestataireHome');
        return;
      }
    }
    
    if (!mounted) return;
    context.go('/signup2');
  }
}