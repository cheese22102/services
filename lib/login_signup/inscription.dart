import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';
import '../front/custom_snackbar.dart';
import '../front/app_colors.dart';
import '../front/custom_text_field.dart';
import '../front/custom_button.dart';
import '../front/loading_overlay.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../front/password_strength_indicator.dart'; // Add this import
import '../front/page_transition.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> with TickerProviderStateMixin {
  late AnimationController _controller;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _emailError;
  String? _passwordError;
  
  // Add this getter to determine if dark mode is active
  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _passwordController.addListener(() {
      setState(() {});  // This will rebuild the widget when password changes
    });
  }

  @override
  void dispose() {
    // Make sure to hide any active loaders when the component is disposed
    try {
      LoadingOverlay.hide();
    } catch (e) {
      // Ignore errors when trying to hide the overlay during disposal
    }
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _signupWithEmail() async {
    if (!_formKey.currentState!.validate()) {
      // If validation fails, ensure loading state is reset
      setState(() => _isLoading = false);
      return;
    }
    
    // Reset error states
    setState(() {
      _isLoading = true;
      _emailError = null;
      _passwordError = null;
    });
    
    // Show loading overlay with message
    try {
      LoadingOverlay.show(context, message: 'Création de votre compte');
      
      // Add a small delay to ensure the loader is visible
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Create user with email and password
      final UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      
      // Send email verification
      await userCredential.user!.sendEmailVerification();
      
      // Get FCM token for notifications
      String? fcmToken;
      try {
        fcmToken = await FirebaseMessaging.instance.getToken();
      } catch (e) {
        // Handle FCM token error silently
        print("Error getting FCM token: $e");
      }
      
      // Create user document in Firestore
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'email': _emailController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'role': 'client',
        'emailVerified': false,
        'fcmToken': fcmToken,
        'tokenLastUpdated': FieldValue.serverTimestamp(),
      });

      // Hide loading overlay before checking mounted state
      _safeHideOverlay();
      
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      
      CustomSnackbar.showSuccess(
        context: context,
        message: "Votre compte a été créé avec succès. Veuillez vérifier votre email pour activer votre compte.",
      );
      context.push('/verification');
    } on FirebaseAuthException catch (e) {
      // Hide loading overlay
      _safeHideOverlay();
      
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      
      String errorMessage = "Une erreur s'est produite lors de l'inscription.";
      
      if (e.code == 'weak-password') {
        errorMessage = 'Le mot de passe fourni est trop faible.';
        setState(() => _passwordError = errorMessage);
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'Un compte existe déjà pour cet email.';
        setState(() => _emailError = errorMessage);
      } else if (e.code == 'invalid-email') {
        errorMessage = 'L\'email fourni n\'est pas valide.';
        setState(() => _emailError = errorMessage);
      } else if (e.message != null && e.message!.contains('PASSWORD_DOES_NOT_MEET_REQUIREMENTS')) {
        errorMessage = 'Le mot de passe doit contenir au moins une majuscule.';
        setState(() => _passwordError = errorMessage);
      }
      
      CustomSnackbar.showError(
        context: context,
        message: errorMessage,
      );
    } catch (e) {
      // Hide loading overlay
      _safeHideOverlay();
      
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      
      CustomSnackbar.showError(
        context: context,
        message: "Une erreur s'est produite lors de l'inscription.",
      );
    }
  }

  // Add this helper method to safely hide the overlay
  void _safeHideOverlay() {
    try {
      LoadingOverlay.hide();
    } catch (e) {
      print("Error hiding overlay: $e");
    }
  }

  Future<void> _signInWithGoogle() async {
    // Reset error states
    setState(() {
      _isLoading = true;
      _emailError = null;
      _passwordError = null;
    });
    
    // Show loading overlay with message
    try {
      LoadingOverlay.show(context, message: 'Connexion avec Google...');
      
      // Add a small delay to ensure the loader is visible
      await Future.delayed(const Duration(milliseconds: 300));
      
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User cancelled the sign-in flow
        _safeHideOverlay();
        
        if (!mounted) return;
        
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = 
          await FirebaseAuth.instance.signInWithCredential(credential);
      
      if (userCredential.user != null) {
        // Check if this is a new user
        final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;
        
        // Get FCM token for notifications
        String? fcmToken;
        try {
          fcmToken = await FirebaseMessaging.instance.getToken();
        } catch (e) {
          // Handle FCM token error silently
          print("Error getting FCM token: $e");
        }
        
        // Get or create user document
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();
            
        if (!userDoc.exists || isNewUser) {
          // Create new user document
          await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
            'email': userCredential.user!.email,
            'displayName': userCredential.user!.displayName,
            'photoURL': userCredential.user!.photoURL,
            'createdAt': FieldValue.serverTimestamp(),
            'lastLogin': FieldValue.serverTimestamp(),
            'role': 'client', // Default role
            'fcmToken': fcmToken,
          });
          
          // Hide loader before navigation
          LoadingOverlay.hide();
          
          if (!mounted) return;
          
          setState(() => _isLoading = false);
          
          CustomSnackbar.showSuccess(
            context: context,
            message: 'Compte créé avec succès! Veuillez compléter votre profil.',
          );
          context.go('/signup2');
          return;
        } else {
          // Update last login
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .update({
            'lastLogin': FieldValue.serverTimestamp(),
            'fcmToken': fcmToken,
          });
          
          // Check if profile is complete
          final userData = userDoc.data();
          if (userData == null || 
              userData['firstname'] == null || 
              userData['lastname'] == null) {
            
            // Hide loader before navigation
            LoadingOverlay.hide();
            
            if (!mounted) return;
            
            setState(() => _isLoading = false);
            
            CustomSnackbar.showInfo(
              context: context,
              message: 'Veuillez compléter votre profil',
            );
            context.go('/signup2');
            return;
          }
          
          // Hide loader before navigation
          LoadingOverlay.hide();
          
          if (!mounted) return;
          
          setState(() => _isLoading = false);
          
          // Check user role and redirect
          final role = userData['role'];
          if (role == 'admin') {
            CustomSnackbar.showSuccess(
              context: context,
              message: 'Bienvenue, administrateur!',
            );
            context.go('/admin');
          } else if (role == 'prestataire') {
            CustomSnackbar.showSuccess(
              context: context,
              message: 'Bienvenue, prestataire!',
            );
            context.go('/prestataireHome');
          } else {
            CustomSnackbar.showSuccess(
              context: context,
              message: 'Connexion réussie!',
            );
            context.go('/clientHome');
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      // Hide loading overlay
      LoadingOverlay.hide();
      
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      
      CustomSnackbar.showError(
        context: context,
        message: "Erreur Google : ${e.message}",
      );
    } catch (e) {
      // Hide loading overlay
      LoadingOverlay.hide();
      
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      
      CustomSnackbar.showError(
        context: context,
        message: "Une erreur s'est produite lors de la connexion avec Google",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDarkMode ? AppColors.darkGradient : AppColors.lightGradient,
          stops: AppColors.gradientStops,
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent, // Make scaffold transparent
        body: SafeArea(
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
                          
                          // Signup Image
                          Container(
                            height: 160,
                            decoration: BoxDecoration(
                              color: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Image.asset(
                              "assets/images/login.png",
                              height: 120,
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 5),
                          
                          // App Title
                          Text(
                            "Services Pro",
                            style: GoogleFonts.poppins(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          
                          // Subtitle
                          Text(
                            "Créez un compte pour commencer",
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
                            labelText: 'Email',
                            hintText: 'Entrez votre adresse email',
                            keyboardType: TextInputType.emailAddress,
                            errorText: _emailError,
                            prefixIcon: Icon(
                              Icons.email_outlined,
                              color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                _safeHideOverlay();
                                setState(() => _isLoading = false);
                                CustomSnackbar.showError(
                                  context: context,
                                  message: 'Veuillez entrer votre email',
                                );
                                return 'Veuillez entrer votre email';
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                _safeHideOverlay();
                                setState(() => _isLoading = false);
                                CustomSnackbar.showError(
                                  context: context,
                                  message: 'Veuillez entrer un email valide',
                                );
                                return 'Veuillez entrer un email valide';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Find the Password Field section in your code and add the password strength indicator after it
                          // This should be around line 370-400 in your file
                          
                          // Password Field
                          CustomTextField(
                            controller: _passwordController,
                            labelText: 'Mot de passe',
                            hintText: 'Créez un mot de passe sécurisé (min. 6 caractères avec 1 majuscule)',
                            obscureText: _obscurePassword,
                            errorText: _passwordError,
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            validator: (value) {
                              // Validator remains the same
                              if (value == null || value.isEmpty) {
                                _safeHideOverlay();
                                setState(() => _isLoading = false);
                                CustomSnackbar.showError(
                                  context: context,
                                  message: 'Veuillez entrer votre mot de passe',
                                );
                                return 'Veuillez entrer votre mot de passe';
                              }
                              if (value.length < 6) {
                                _safeHideOverlay();
                                setState(() => _isLoading = false);
                                CustomSnackbar.showError(
                                  context: context,
                                  message: 'Le mot de passe doit contenir au moins 6 caractères',
                                );
                                return 'Le mot de passe doit contenir au moins 6 caractères';
                              }
                              if (!value.contains(RegExp(r'[A-Z]'))) {
                                _safeHideOverlay();
                                setState(() => _isLoading = false);
                                CustomSnackbar.showError(
                                  context: context,
                                  message: 'Le mot de passe doit contenir au moins une majuscule',
                                );
                                return 'Le mot de passe doit contenir au moins une majuscule';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Add the password strength indicator here
                          PasswordStrengthIndicator(
                            password: _passwordController.text,
                            isDarkMode: isDarkMode,
                          ),
                          const SizedBox(height: 16),
                          
                          // Confirm Password Field
                          CustomTextField(
                            controller: _confirmPasswordController,
                            labelText: 'Confirmer le mot de passe',
                            hintText: 'Saisissez à nouveau votre mot de passe',
                            obscureText: _obscureConfirmPassword,
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                                color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword = !_obscureConfirmPassword;
                                });
                              },
                            ),
                            validator: (value) {
                              // Validator remains the same
                              if (value == null || value.isEmpty) {
                                _safeHideOverlay();
                                setState(() => _isLoading = false);
                                CustomSnackbar.showError(
                                  context: context,
                                  message: 'Veuillez confirmer votre mot de passe',
                                );
                                return 'Veuillez confirmer votre mot de passe';
                              }
                              if (value != _passwordController.text) {
                                _safeHideOverlay();
                                setState(() => _isLoading = false);
                                CustomSnackbar.showError(
                                  context: context,
                                  message: 'Les mots de passe ne correspondent pas',
                                );
                                return 'Les mots de passe ne correspondent pas';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          
                          // Signup Button
                          CustomButton(
                            text: "S'inscrire",
                            onPressed: () {
                              // First check if form is valid before showing loader
                              if (_formKey.currentState!.validate()) {
                                _signupWithEmail();
                              } else {
                                // Ensure loading state is reset if validation fails
                                _safeHideOverlay();
                                setState(() => _isLoading = false);
                              }
                            },
                            isLoading: _isLoading,
                            width: double.infinity,
                            height: 45,
                            useFullScreenLoader: true,
                            backgroundColor: isDarkMode 
                                ? CustomTextField.getBorderColor(context) // Utiliser la couleur de bordure en mode sombre
                                : null, // Garder la couleur par défaut en mode clair
                          ),
                          const SizedBox(height: 12), // Same spacing as login button
                          
                          // Divider
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: isDarkMode ? AppColors.darkTextSecondary.withOpacity(0.3) : AppColors.lightTextSecondary.withOpacity(0.3),
                                  thickness: 1,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'Ou',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: isDarkMode ? AppColors.darkTextSecondary.withOpacity(0.3) : AppColors.lightTextSecondary.withOpacity(0.3),
                                  thickness: 1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Social Login Buttons
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // Google Button
                              Expanded(
                                child: CustomButton(
                                  text: 'Google',
                                  onPressed: _isLoading ? null : _signInWithGoogle,
                                  isPrimary: false,
                                  isLoading: _isLoading,
                                  icon: Image.asset(
                                    'assets/images/google.png',
                                    height: 20,
                                    width: 20,
                                    color: isDarkMode ? Colors.white : null,
                                    colorBlendMode: isDarkMode ? BlendMode.srcIn : null,
                                  ),
                                  height: 45,
                                  useFullScreenLoader: true,
                                  backgroundColor: isDarkMode ? AppColors.darkInputBackground : Colors.white,
                                  textColor: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Facebook Button
                              Expanded(
                                child: CustomButton(
                                  text: 'Facebook',
                                  onPressed: _isLoading ? null : () {
                                    CustomSnackbar.showInfo(
                                      context: context,
                                      message: 'La connexion avec Facebook sera bientôt disponible',
                                    );
                                  },
                                  isPrimary: false,
                                  icon: Image.asset(
                                    isDarkMode 
                                        ? 'assets/images/facebook_dark.png' 
                                        : 'assets/images/facebook.png',
                                    height: 20,
                                    width: 20,
                                  ),
                                  height: 45,
                                  backgroundColor: isDarkMode ? AppColors.darkInputBackground : Colors.white,
                                  textColor: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          
                          // Login Link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Vous avez déjà un compte?',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  context.go('/', extra: getSlideTransitionInfo(SlideDirection.rightToLeft));
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.only(left: 8),
                                  minimumSize: const Size(50, 30),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Se connecter',
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
      ));
  }
}