import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../front/custom_snackbar.dart';
import '../front/app_colors.dart';
import '../front/custom_text_field.dart';
import '../front/custom_button.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _emailError;

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _emailError = null;
    });
    
    try {
      // First, check if the email exists
      List<String> signInMethods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(
        _emailController.text.trim(),
      );
      
      if (!mounted) return;

      // If signInMethods is empty, no account exists with this email
      if (signInMethods.isEmpty) {
        setState(() {
          _emailError = 'Aucun compte trouvé avec cet email';
        });
        
        CustomSnackbar.showError(
          context: context,
          message: 'Aucun compte trouvé avec cet email',
        );
        return;
      }

      // Send password reset email
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      
      if (!mounted) return;
      
      CustomSnackbar.showSuccess(
        context: context,
        message: 'Email de réinitialisation envoyé! Vérifiez votre boîte de réception.',
      );
      
      // Navigate back to login page after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          context.go('/');
        }
      });
    } on FirebaseAuthException catch (e) {
      setState(() {
        _emailError = 'Erreur: ${e.message}';
      });
      
      CustomSnackbar.showError(
        context: context,
        message: 'Erreur: ${e.message}',
      );
    } catch (e) {
      setState(() {
        _emailError = 'Une erreur inattendue s\'est produite';
      });
      
      CustomSnackbar.showError(
        context: context,
        message: 'Une erreur inattendue s\'est produite',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 5),
                          
                          // Reset Password Image
                          Container(
                            height: 160,
                            decoration: BoxDecoration(
                              color: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Image.asset(
                              "assets/images/forgot_password.png",
                              height: 120,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 5),
                          
                          // Title
                          Text(
                            "Mot de passe oublié",
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          
                          // Subtitle
                          Text(
                            "Entrez votre email pour recevoir un lien de réinitialisation",
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          
                          // Email Field
                          CustomTextField(
                            controller: _emailController,
                            labelText: "Email",
                            hintText: "Votre email",
                            keyboardType: TextInputType.emailAddress,
                            errorText: _emailError,
                          ),
                          const SizedBox(height: 24),
                          
                          // Send Reset Link Button
                          CustomButton(
                            text: 'Envoyer le lien',
                            onPressed: _sendResetEmail,
                            isLoading: _isLoading,
                            width: double.infinity,
                            height: 45,
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
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}