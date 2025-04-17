import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';
import '../front/custom_snackbar.dart';
import '../front/custom_dialog.dart';
import '../front/app_colors.dart';
import '../front/custom_text_field.dart';
import '../front/custom_button.dart';
import '../front/loading_overlay.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../front/page_transition.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  late AnimationController _controller;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = false;
  bool _obscurePassword = true;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  String? _emailError;
  String? _passwordError;
  
  // Add this getter to determine if dark mode is active
  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('email');
    final savedPassword = prefs.getString('password');
    final rememberMe = prefs.getBool('rememberMe');

    if (rememberMe == true && savedEmail != null && savedPassword != null) {
      setState(() {
        _emailController.text = savedEmail;
        _passwordController.text = savedPassword;
        _rememberMe = true;
      });
    }
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('email', _emailController.text);
      await prefs.setString('password', _passwordController.text);
      await prefs.setBool('rememberMe', true);
    } else {
      await prefs.remove('email');
      await prefs.remove('password');
      await prefs.setBool('rememberMe', false);
    }
  }

  Future<void> _login() async {
    // Set loading state first so we can show validation errors
    setState(() {
      _isLoading = true;
      _emailError = null;
      _passwordError = null;
    });

    // Check form validation
    if (!_formKey.currentState!.validate()) {
      // If validation fails, reset loading state and return
      setState(() => _isLoading = false);
      return;
    }
    
    // Show loading overlay only if validation passes
    LoadingOverlay.show(context, message: 'Connexion en cours');

    try {
      // Add a small delay to ensure the loader is visible
      await Future.delayed(const Duration(milliseconds: 300));
      
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      // Save credentials if remember me is checked
      await _saveCredentials();

      // Get user data from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!userDoc.exists) {
        // User document doesn't exist, create it
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'email': userCredential.user!.email,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        });
      } else {
        // Update last login
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .update({
          'lastLogin': FieldValue.serverTimestamp(),
        });
      }

      // Subscribe to FCM topic for the user
      await FirebaseMessaging.instance.subscribeToTopic('user_${userCredential.user!.uid}');

      // Check if email is verified
      if (!userCredential.user!.emailVerified) {
        if (!mounted) return;
        CustomSnackbar.showError(
          context: context,
          message: 'Veuillez vérifier votre email avant de vous connecter',
        );
        context.go('/verification');
        return;
      }

      // Check if profile is complete
      final userData = userDoc.data();
      if (userData == null || userData['firstname'] == null || userData['lastname'] == null) {
        if (!mounted) return;
        CustomSnackbar.showInfo(
          context: context,
          message: 'Veuillez compléter votre profil',
        );
        context.go('/signup2');
        return;
      }

      // Check user role and redirect
      final role = userData['role'];
      if (role == 'admin') {
        if (!mounted) return;
        CustomSnackbar.showSuccess(
          context: context,
          message: 'Bienvenue, administrateur!',
        );
        context.go('/admin');
      } else if (role == 'prestataire') {
        if (!mounted) return;
        CustomSnackbar.showSuccess(
          context: context,
          message: 'Bienvenue, prestataire!',
        );
        context.go('/prestataireHome');
      } else {
        if (!mounted) return;
        CustomSnackbar.showSuccess(
          context: context,
          message: 'Connexion réussie!',
        );
        context.go('/clientHome');
      }
    } on FirebaseAuthException catch (e) {
      _handleAuthError(e);
    } catch (e) {
      setState(() {
        _emailError = 'Une erreur inattendue s\'est produite: $e';
      });
      CustomSnackbar.showError(
        context: context,
        message: 'Une erreur inattendue s\'est produite',
      );
    } finally {
      // Hide the loading overlay
      LoadingOverlay.hide();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Add this method to handle Firebase Auth errors
  void _handleAuthError(FirebaseAuthException e) {
    String message = 'Une erreur s\'est produite lors de la connexion';
    
    switch (e.code) {
      case 'user-not-found':
        message = 'Aucun utilisateur trouvé avec cet email';
        setState(() => _emailError = message);
        break;
      case 'wrong-password':
        message = 'Mot de passe incorrect';
        setState(() => _passwordError = message);
        break;
      case 'invalid-email':
        message = 'Format d\'email invalide';
        setState(() => _emailError = message);
        break;
      case 'user-disabled':
        message = 'Ce compte a été désactivé';
        setState(() => _emailError = message);
        break;
      case 'too-many-requests':
        message = 'Trop de tentatives de connexion. Veuillez réessayer plus tard';
        break;
      default:
        message = 'Erreur: ${e.message}';
        break;
    }
    
    CustomSnackbar.showError(
      context: context,
      message: message,
    );
  }

  Future<void> _signInWithGoogle() async {
    // Set loading state at the beginning
    if (mounted) {
      setState(() {
        _isLoading = true;
        _emailError = null;
        _passwordError = null;
      });
    }
    
    // Show loading overlay
    LoadingOverlay.show(context, message: 'Connexion avec Google');

    try {
      // Add a small delay to ensure the loader is visible
      await Future.delayed(const Duration(milliseconds: 300));
      
      UserCredential? userCredential;
      
      // Use different sign-in methods for web and mobile
      if (kIsWeb) {
        // Web implementation
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        
        // Add scopes if needed
        googleProvider.addScope('https://www.googleapis.com/auth/contacts.readonly');
        googleProvider.addScope('https://www.googleapis.com/auth/userinfo.email');
        googleProvider.addScope('https://www.googleapis.com/auth/userinfo.profile');
        
        // Sign in with popup for web
        userCredential = await FirebaseAuth.instance.signInWithPopup(googleProvider);
      } else {
        // Mobile implementation - with better error handling
        try {
          final GoogleSignInAccount? gUser = await _googleSignIn.signIn();
          
          // If user cancels the Google sign-in dialog
          if (gUser == null) {
            // Make sure to hide the loader if user cancels
            LoadingOverlay.hide();
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
            return;
          }
          
          // Obtain auth details from request
          final GoogleSignInAuthentication gAuth = await gUser.authentication;
          
          // Create a new credential for user
          final credential = GoogleAuthProvider.credential(
            accessToken: gAuth.accessToken,
            idToken: gAuth.idToken,
          );
          
          // Sign in with credential
          userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
        } catch (googleError) {
          // Make sure to hide the loader
          LoadingOverlay.hide();
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            CustomSnackbar.showError(
              context: context,
              message: 'Erreur de connexion Google: ${googleError.toString()}',
            );
          }
          return;
        }
      }
      
      // Check if this is a new user
      final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;
      
      // Get or create user document
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();
          
      if (!userDoc.exists || isNewUser) {
        // Create new user document
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'email': userCredential.user!.email,
          'photoURL': userCredential.user!.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'role': 'client', // Default role
        });
        
        // Hide loader before navigation
        LoadingOverlay.hide();
        
        if (!mounted) return;
        CustomSnackbar.showSuccess(
          context: context,
          message: 'Compte créé avec succès! Veuillez compléter votre profil.',
        );
        context.go('/signup2');
        return;
      } else {
        // Update last login time for existing user
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .update({
          'lastLogin': FieldValue.serverTimestamp(),
        });
        
        // Subscribe to FCM topic for the user
        try {
          await FirebaseMessaging.instance.subscribeToTopic('user_${userCredential.user!.uid}');
        } catch (e) {
          // Continue even if FCM subscription fails
        }
        
        // Check if profile is complete
        final userData = userDoc.data();
        if (userData == null || userData['firstname'] == null || userData['lastname'] == null) {
          // Hide loader before navigation
          LoadingOverlay.hide();
          
          if (!mounted) return;
          CustomSnackbar.showInfo(
            context: context,
            message: 'Veuillez compléter votre profil',
          );
          context.go('/signup2');
          return;
        }
        
        // Check user role and redirect
        final role = userData['role'];
        
        // Hide loader before navigation
        LoadingOverlay.hide();
        
        if (!mounted) return;
        
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
    } on FirebaseAuthException catch (e) {
      // Hide loader on error
      LoadingOverlay.hide();
      _handleAuthError(e);
    } catch (e) {
      // Hide loader on error
      LoadingOverlay.hide();
      if (mounted) {
        CustomDialog.showError(
          context: context,
          title: 'Erreur de connexion',
          message: 'Une erreur s\'est produite lors de la connexion avec Google: $e',
        );
      }
    } finally {
      // This might not be called if we navigate away, so we need to hide the loader before navigation
      LoadingOverlay.hide();
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
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0), // Added vertical padding
                child: Card(
                  elevation: 4, // Increased elevation for better visibility
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
                          
                          // Login Image
                          Container(
                            height: 160, // Reduced from 240
                            decoration: BoxDecoration(
                              color: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Image.asset(
                              "assets/images/login.png",
                              height: 120, // Reduced from 150
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 5), // Reduced spacing
                          
                          // App Title
                          Text(
                            "Services Pro",
                            style: GoogleFonts.poppins(
                              fontSize: 22, // Reduced from 24
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4), // Reduced from 8
                          
                          // Subtitle
                          Text(
                            "Veuillez vous connecter pour continuer",
                            style: GoogleFonts.poppins(
                              fontSize: 13, // Reduced from 14
                              color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16), // Reduced from 24
                          
                          // Email Field
                          CustomTextField(
                            controller: _emailController,
                            labelText: 'Email',
                            hintText: 'Entrez votre adresse email',
                            keyboardType: TextInputType.emailAddress,
                            errorText: _emailError,
                            prefixIcon: Icon(
                              Icons.email_outlined,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                // Reset loading state when validation fails
                                if (_isLoading) {
                                  setState(() => _isLoading = false);
                                  LoadingOverlay.hide();
                                }
                                return 'Veuillez entrer votre email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // Password Field
                          CustomTextField(
                            controller: _passwordController,
                            labelText: 'Mot de passe',
                            hintText: 'Entrez votre mot de passe',
                            obscureText: _obscurePassword,
                            errorText: _passwordError,
                            prefixIcon: Icon(
                              Icons.lock_outline,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                // Reset loading state when validation fails
                                if (_isLoading) {
                                  setState(() => _isLoading = false);
                                  LoadingOverlay.hide();
                                }
                                return 'Veuillez entrer votre mot de passe';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 4), // Reduced from 8
                          
                          // Forgot Password Link
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                context.go('/forgot-password');
                              },
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(50, 30),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Mot de passe oublié?',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: isDarkMode ? Colors.white70 : const Color(0xFF4D8C3F),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Remember Me Checkbox
                          Row(
                            children: [
                              SizedBox(
                                height: 20, // Reduced from 24
                                width: 20, // Reduced from 24
                                child: Checkbox(
                                  value: _rememberMe,
                                  onChanged: (value) {
                                    setState(() {
                                      _rememberMe = value!;
                                    });
                                  },
                                  activeColor: const Color(0xFF4D8C3F),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Se souvenir de moi',
                                style: GoogleFonts.poppins(
                                  fontSize: 13, // Reduced from 14
                                  color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16), // Reduced from 24
                          
                          // Login Button
                          CustomButton(
                            text: 'Se connecter',
                            onPressed: _login,
                            isLoading: _isLoading,
                            width: double.infinity,
                            height: 45, // Reduced from default 50
                            useFullScreenLoader: true, // Enable full-screen loader
                            backgroundColor: isDark 
                                ? CustomTextField.getBorderColor(context) // Utiliser la couleur de bordure en mode sombre
                                : null, // Garder la couleur par défaut en mode clair
                          ),
                          const SizedBox(height: 12), // Reduced from 16
                          
                          // Divider
                          Row(
                            children: [
                              Expanded(
                                child: Divider(
                                  color: isDarkMode ? Colors.white24 : Colors.black12,
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
                                  color: isDarkMode ? Colors.white24 : Colors.black12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Social Login Buttons - Row with Google and Facebook
                          Row(
                            children: [
                              // Google Sign In Button
                              Expanded(
                                child: CustomButton(
                                  text: 'Google',
                                  onPressed: _signInWithGoogle,
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
                                  useFullScreenLoader: true, // Enable full-screen loader
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Facebook Sign In Button
                              Expanded(
                                child: CustomButton(
                                  text: 'Facebook',
                                  onPressed: () {
                                    if (mounted) {  // Add this check
                                      CustomSnackbar.showInfo(
                                        context: context,
                                        message: 'Connexion Facebook à venir',
                                      );
                                    }
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
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          
                          // Sign Up Link
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Pas de compte?',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  context.go('/signup', extra: getSlideTransitionInfo(SlideDirection.leftToRight));
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.only(left: 8),
                                  minimumSize: const Size(50, 30),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Inscrivez vous',
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
}