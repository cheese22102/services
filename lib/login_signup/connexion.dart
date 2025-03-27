import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/custom_button.dart';
import '../widgets/social_icon.dart';
import 'package:go_router/go_router.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/dark_mode_switch.dart';


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

// Add this getter near the top of your _LoginPageState class, after the variable declarations
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
      duration: const Duration(milliseconds: 500),
    );
    _loadSavedCredentials();
    _controller.forward();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _emailController.text = prefs.getString('savedEmail') ?? '';
      _passwordController.text = prefs.getString('savedPassword') ?? '';
      _rememberMe = prefs.getBool('rememberMe') ?? false;
    });
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString('savedEmail', _emailController.text);
      await prefs.setString('savedPassword', _passwordController.text);
    } else {
      // Clear saved credentials if "remember me" is unchecked
      await prefs.remove('savedEmail');
      await prefs.remove('savedPassword');
    }
    await prefs.setBool('rememberMe', _rememberMe);
  }

  Future<void> _login() async {
    // Reset error messages
    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!userCredential.user!.emailVerified) {
        throw FirebaseAuthException(
          code: 'email-not-verified',
          message: 'Veuillez vérifier votre email',
        );
      }

      await _saveCredentials();
      _redirectToHome(userCredential.user!);
    } on FirebaseAuthException catch (e) {
      _handleError(e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleError(FirebaseAuthException e) {
    String message = 'Erreur de connexion';
    
    // Field-specific error handling
    switch (e.code) {
      case 'user-not-found':
        setState(() => _emailError = 'Aucun compte associé à cet email');
        message = 'Utilisateur non trouvé';
        break;
      case 'wrong-password':
        setState(() => _passwordError = 'Mot de passe incorrect');
        message = 'Mot de passe incorrect';
        break;
      case 'invalid-email':
        setState(() => _emailError = 'Format d\'email invalide');
        message = 'Format d\'email invalide';
        break;
      case 'too-many-requests':
        message = 'Trop de tentatives. Veuillez réessayer plus tard';
        break;
      case 'email-not-verified':
        message = 'Email non vérifié. Veuillez vérifier votre boîte de réception';
        // Option to resend verification email
        _showResendVerificationDialog();
        return;
      default:
        message = e.message ?? 'Une erreur est survenue';
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _redirectToHome(User user) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!mounted) return;

    // Redirect based on role using GoRouter
    switch (doc.data()?['role']) {
      case 'admin':
        context.go('/admin');
        break;
      case 'client':
        context.go('/clientHome');
        break;
      case 'prestataire':
        context.go('/prestataireHome');
        break;
      default:
        context.go('/marketplace');
    }
  }

  void _showResendVerificationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Email non vérifié'),
        content: const Text('Votre adresse email n\'a pas été vérifiée. Souhaitez-vous recevoir un nouvel email de vérification?'),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Plus tard'),
          ),
          ElevatedButton(
            onPressed: () async {
              context.pop();
              try {
                await FirebaseAuth.instance.currentUser?.sendEmailVerification();
                if (!mounted) return;
                // Update to use the new route structure
                context.push('/verification');
                
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur: ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }

  // Add Google Sign-In method here
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
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
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();
  
        if (!doc.exists) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .set({
            'email': userCredential.user!.email,
            'profileCompleted': false,
            'createdAt': FieldValue.serverTimestamp(),
          });
          if (!mounted) return;
          context.go('/signup2');
          return;
        }
  
        if (doc.data()?['profileCompleted'] != true) {
          if (!mounted) return;
          context.go('/signup2');
          return;
        }
  
        _redirectToHome(userCredential.user!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google Sign-In Failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: const [DarkModeSwitch()],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                Center(
                  child: Image.asset(
                    "assets/images/login.png",
                    height: 180,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  "Connexion",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  "Veuillez vous connecter pour continuer",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Email Field
                LabeledTextField(
                  controller: _emailController,
                  label: 'Email',
                  icon: Icons.email,
                  validator: (value) {
                    if (value == null || value.isEmpty) return "L'email est requis";
                    return _emailError;
                  },
                ),
                const SizedBox(height: 16),

                // In the build method, update the password field:
                
                // Password Field
                LabeledTextField(
                  controller: _passwordController,
                  label: 'Mot de passe',
                  hint: 'Entrez votre mot de passe',
                  icon: Icons.lock,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: Theme.of(context).brightness == Brightness.dark 
                        ? Colors.grey[400] 
                        : Colors.grey[600],
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Le mot de passe est requis';
                    return _passwordError;
                  },
                ),
                const SizedBox(height: 16),

                // Remember Me & Forgot Password
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: (value) => setState(() => _rememberMe = value!),
                          activeColor: const Color(0xFF0066FF),
                        ),
                        const Text(
                          'Se souvenir de moi',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => context.push('/forgot-password'),  // Update this navigation
                      child: const Text(
                        'Mot de passe oublié ?',
                        style: TextStyle(
                          color: Color(0xFF0066FF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Login Button
                CustomButton(
                  text: 'Se connecter',
                  onPressed: _isLoading ? () {} : _login,
                ),
                const SizedBox(height: 32),

                // Social Login
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Ou continuer avec',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildSocialButton(
                      "assets/images/google.jpg",
                      _handleGoogleSignIn,
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Signup Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Vous n'avez pas de compte ? ",
                      style: TextStyle(color: Colors.grey),
                    ),
                    TextButton(
                      onPressed: () => context.go('/signup'),  // Add the leading slash here
                      child: Text(
                        'S\'inscrire',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF62B6CB) : const Color(0xFF1A5F7A),
                          fontWeight: FontWeight.bold,
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
    );
  }

  Widget _buildSocialButton(String imagePath, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: SocialIcon(imagePath: imagePath),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}