import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../front/custom_snackbar.dart';
import '../front/app_colors.dart';
import '../front/custom_button.dart';

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
        CustomSnackbar.showSuccess(
          context: context,
          message: 'Email vérifié avec succès!',
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
      CustomSnackbar.showSuccess(
        context: context,
        message: 'Email de vérification renvoyé!',
      );
    } catch (e) {
      if (!mounted) return;
      CustomSnackbar.showError(
        context: context,
        message: 'Erreur: ${e.toString()}',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDarkMode ? AppColors.darkGradient : AppColors.lightGradient,
            stops: AppColors.gradientStops,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  color: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 5),
                        
                        // Verification Image
                        Container(
                          height: 160,
                          decoration: BoxDecoration(
                            color: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Image.asset(
                            "assets/images/email_verification.png",
                            height: 120,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 5),
                        
                        // Title
                        Text(
                          "Vérification Email",
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        
                        // Subtitle
                        Text(
                          "Un email de vérification a été envoyé à",
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        // Email display
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: (isDarkMode ? Colors.green[800]! : Colors.green).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: (isDarkMode ? Colors.green[700]! : Colors.green[300])!,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _user.email ?? '',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.green[400] : Colors.green,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Instructions
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.blueGrey.shade800 : Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                "Veuillez suivre les instructions dans l'email pour vérifier votre compte.",
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: isDarkMode ? Colors.white70 : Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Une fois vérifié, vous serez automatiquement redirigé.",
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: isDarkMode ? Colors.white70 : Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        
                        // Resend Button
                        CustomButton(
                          text: _canResend 
                              ? 'Renvoyer l\'email' 
                              : 'Renvoyer l\'email (${_timeoutSeconds}s)',
                          onPressed: _canResend && !_isLoading 
                              ? () { _resendVerification(); } 
                              : () {}, // Provide an empty function instead of null
                          isLoading: _isLoading,
                          width: double.infinity,
                          height: 45,
                          isPrimary: _canResend,
                          useFullScreenLoader: true, // Enable full-screen loader
                        ),
                        const SizedBox(height: 16),
                        
                        // Warning about spam
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.orange.shade900.withOpacity(0.3) : Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDarkMode ? Colors.orange.shade800 : Colors.orange.shade300,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: isDarkMode ? Colors.orange.shade300 : Colors.orange.shade800,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Si vous ne trouvez pas l\'email, vérifiez votre dossier spam.',
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    color: isDarkMode ? Colors.orange.shade100 : Colors.orange.shade900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Back to Login Link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Retour à',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                _timer?.cancel();
                                context.go('/');
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.only(left: 8),
                                minimumSize: const Size(50, 30),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'la connexion',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode ? const Color(0xFF8BC34A) : const Color(0xFF4D8C3F),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // Navigate based on profile completion
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