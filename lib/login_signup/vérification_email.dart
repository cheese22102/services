import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../front/custom_snackbar.dart';
import '../front/app_colors.dart';
import '../front/custom_button.dart';
import '../front/page_transition.dart';
import '../front/loading_overlay.dart'; // Add this import for LoadingOverlay

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
    if (!_canResend) {
      // Show snackbar to indicate user needs to wait
      CustomSnackbar.showInfo(
        context: context,
        message: 'Veuillez attendre $_timeoutSeconds secondes avant de renvoyer un email',
      );
      return;
    }

    // Set loading state
    setState(() => _isLoading = true);
    
    // Show loading overlay with message
    LoadingOverlay.show(context, message: 'Envoi de l\'email...');
    
    try {
      // Add a small delay to ensure the loader is visible
      await Future.delayed(const Duration(milliseconds: 300));
      
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
      // Hide the loading overlay
      LoadingOverlay.hide();
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightInputBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          onPressed: () {
            context.go('/', extra: getSlideTransitionInfo(SlideDirection.rightToLeft));
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: size.width * 0.06,
              vertical: size.height * 0.02,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'Vérification Email',
                  style: GoogleFonts.poppins(
                    fontSize: 28, // Consistent font size
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16), // Consistent spacing
                Text(
                  'Un email de vérification a été envoyé à ${_user.email}',
                  style: GoogleFonts.poppins(
                    fontSize: 16, // Consistent font size
                    color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  textAlign: TextAlign.center, // Center align for better readability
                ),
                
                // Add image - using the same image as forgot password page
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24), // Consistent spacing
                    child: Image.asset(
                      'assets/images/emailverif.png',
                      height: 150, // Consistent image height
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                
                // Instructions
                Text(
                  'Veuillez vérifier votre boîte de réception et cliquer sur le lien de vérification.',
                  style: GoogleFonts.poppins(
                    fontSize: 16, // Consistent font size
                    color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  textAlign: TextAlign.center, // Center align for better readability
                ),
                const SizedBox(height: 24), // Consistent spacing
                
                // Countdown text
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isDarkMode 
                          ? Colors.grey.shade800.withOpacity(0.5)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _canResend
                            ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      _canResend 
                        ? 'Vous pouvez renvoyer l\'email maintenant'
                        : 'Vous pourrez renvoyer l\'email dans $_timeoutSeconds secondes',
                      style: GoogleFonts.poppins(
                        fontSize: 14, // Consistent font size
                        fontWeight: _canResend ? FontWeight.w600 : FontWeight.normal,
                        color: _canResend
                            ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                            : (isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(height: 24), // Consistent spacing
                
                // Resend button
                CustomButton(
                  text: 'Renvoyer l\'email de vérification',
                  onPressed: _canResend ? _resendVerification : null,
                  isLoading: _isLoading,
                  width: double.infinity,
                  height: 50, // Consistent button height
                  useFullScreenLoader: true,
                  backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen, // Consistent primary color
                ),
                const SizedBox(height: 24), // Consistent spacing
                
                // Back to login
                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Retourner à ',
                        style: GoogleFonts.poppins(
                          fontSize: 14, // Consistent font size
                          color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          context.go('/', extra: getSlideTransitionInfo(SlideDirection.rightToLeft));
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'la page de connexion',
                          style: GoogleFonts.poppins(
                            fontSize: 14, // Consistent font size
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // Add this getter to determine if dark mode is active
  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;
  
  // Navigate based on profile completion
  Future<void> _navigateBasedOnProfile() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user.uid)
          .get();
      
      if (!mounted) return;
      
      if (!userDoc.exists || userDoc.data()?['firstname'] == null) {
        context.go('/signup2');
      } else {
        final role = userDoc.data()?['role'];
        if (role == 'admin') {
          context.go('/admin');
        } else if (role == 'prestataire') {
          context.go('/prestataireHome');
        } else {
          context.go('/clientHome');
        }
      }
    } catch (e) {
      debugPrint('Error navigating based on profile: $e');
      if (mounted) {
        context.go('/');
      }
    }
  }
  
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
