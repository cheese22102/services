import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../front/custom_snackbar.dart';
import '../front/app_colors.dart';
import '../front/custom_text_field.dart';
import '../front/custom_button.dart';
import '../front/page_transition.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  _ForgotPasswordPageState createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _emailError;
  late AnimationController _controller;
  
  // Add this getter to determine if dark mode is active
  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    // First validate the form without showing any loader
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    // Only after validation passes, set loading state
    setState(() {
      _isLoading = true;
      _emailError = null;
    });
    
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      CustomSnackbar.showSuccess(
        context: context,
        message: 'Un email de réinitialisation a été envoyé à ${_emailController.text}',
      );
      
      // Navigate back to login page
      context.go('/', extra: getSlideTransitionInfo(SlideDirection.rightToLeft));
      
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (e.code == 'user-not-found') {
        setState(() {
          _emailError = 'Aucun utilisateur trouvé avec cet email';
        });
        CustomSnackbar.showError(
          context: context,
          message: 'Aucun utilisateur trouvé avec cet email',
        );
      } else {
        setState(() {
          _emailError = 'Une erreur s\'est produite: ${e.message}';
        });
        CustomSnackbar.showError(
          context: context,
          message: 'Une erreur s\'est produite',
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _emailError = 'Une erreur inattendue s\'est produite';
      });
      CustomSnackbar.showError(
        context: context,
        message: 'Une erreur inattendue s\'est produite',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
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
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'Mot de passe oublié',
                    style: GoogleFonts.poppins(
                      fontSize: size.width * 0.07,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Entrez votre adresse email pour recevoir un lien de réinitialisation de mot de passe',
                    style: GoogleFonts.poppins(
                      fontSize: size.width * 0.04,
                      color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  
                  // Add image
                  Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: size.height * 0.03),
                      child: Image.asset(
                        'assets/images/motdepasseoublié.png',
                        height: size.height * 0.2,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  
                  // Email field
                  CustomTextField(
                    controller: _emailController,
                    labelText: 'Email',
                    hintText: 'Entrez votre adresse email',
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icon(
                      Icons.email_outlined,
                      color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    errorText: _emailError,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez entrer votre adresse email';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Veuillez entrer une adresse email valide';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: size.height * 0.04),
                  
                  // Reset button
                  CustomButton(
                    text: 'Réinitialiser le mot de passe',
                    onPressed: _isLoading ? null : _resetPassword,
                    isLoading: _isLoading,
                    width: double.infinity,
                    useFullScreenLoader: false, // Changed to false to prevent the full screen loader
                  ),
                  SizedBox(height: size.height * 0.03),
                  
                  // Back to login - Fixed overflow issue
                  Center(
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'Vous vous souvenez de votre mot de passe? ',
                          style: GoogleFonts.poppins(
                            fontSize: size.width * 0.035,
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
                            'Se connecter',
                            style: GoogleFonts.poppins(
                              fontSize: size.width * 0.035,
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
      ),
    );
  }
}