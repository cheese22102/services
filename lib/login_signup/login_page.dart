import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import '../widgets/social_icon.dart';
import '../widgets/custom_dialog.dart';
import 'signup_page.dart';
import 'forgot_password_page.dart';
import '../main.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
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

  void _redirectToHome(User user) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const AuthWrapper(),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
      ),
    );
  }

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
        // Vérification de l'existence dans Firestore
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();

        if (!doc.exists) {
          await FirebaseAuth.instance.signOut();
          CustomDialog.showWithActions(
  context, 
  'Compte non enregistré',
  'Ce compte Google n\'est pas associé à un utilisateur existant. Voulez-vous créer un compte?',
  [
    TextButton(
      onPressed: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SignupPage()),
        );
      },
      child: const Text('S\'inscrire'),
    ),
    TextButton(
      onPressed: () => Navigator.pop(context),
      child: const Text('Annuler'),
    ),
  ],
);
          return;
        }

        _redirectToHome(userCredential.user!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Échec de connexion: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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

  void _showResendVerificationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Email non vérifié'),
        content: const Text('Votre adresse email n\'a pas été vérifiée. Souhaitez-vous recevoir un nouvel email de vérification?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await FirebaseAuth.instance.currentUser?.sendEmailVerification();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Email de vérification envoyé!'),
                    backgroundColor: Colors.green,
                  ),
                );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => Stack(
          children: [
            _buildAnimatedBackground(context),
            _buildLoginForm(),
            if (_isLoading) _buildLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).primaryColor.withOpacity(0.8),
            Theme.of(context).scaffoldBackgroundColor,
          ],
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: SafeArea(
        child: Column(
          children: [
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.5),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: _controller,
                curve: Curves.easeOut,
              )),
              child: FadeTransition(
                opacity: _controller,
                child: Hero(
                  tag: 'auth-hero',
                  child: Image.asset('assets/images/login.png', height: 220),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
              child: Card(
                elevation: 5,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bienvenue',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Connectez-vous pour continuer',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 30),
                        CustomTextField(
                          controller: _emailController,
                          hint: 'Adresse email',
                          icon: Icons.email,
                          obscure: false,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez entrer votre email';
                            }
                            if (!value.contains('@')) {
                              return 'Email invalide';
                            }
                            return _emailError;
                          },
                          onChanged: (_) {
                            if (_emailError != null) {
                              setState(() => _emailError = null);
                            }
                          },
                        ),
                        const SizedBox(height: 20),
                        Stack(
                          alignment: Alignment.centerRight,
                          children: [
                            CustomTextField(
                              controller: _passwordController,
                              hint: 'Mot de passe',
                              icon: Icons.lock,
                              obscure: _obscurePassword,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Veuillez entrer votre mot de passe';
                                }
                                if (value.length < 6) {
                                  return 'Minimum 6 caractères';
                                }
                                return _passwordError;
                              },
                              onChanged: (_) {
                                if (_passwordError != null) {
                                  setState(() => _passwordError = null);
                                }
                              },
                            ),
                            Positioned(
                              right: 10,
                              child: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                  color: Theme.of(context).primaryColor,
                                ),
                                onPressed: () {
                                  setState(() => _obscurePassword = !_obscurePassword);
                                },
                              ),
                            ),
                          ],
                        ),
                        _buildRememberMe(),
                        const SizedBox(height: 20),
                        SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.5),
                            end: Offset.zero,
                          ).animate(CurvedAnimation(
                            parent: _controller,
                            curve: Curves.easeOut,
                          )),
                          child: CustomButton(
                            text: 'Se connecter',
                            onPressed: _login,
                            icon: Icons.login,
                          ),
                        ),
                        _buildForgotPassword(),
                        _buildGoogleLogin(),
                        _buildSignupLink(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 15),
              const Text('Connexion en cours...'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRememberMe() {
    return Row(
      children: [
        Theme(
          data: ThemeData(
            checkboxTheme: CheckboxThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          child: Checkbox(
            value: _rememberMe,
            onChanged: (value) => setState(() => _rememberMe = value ?? false),
            activeColor: Theme.of(context).primaryColor,
          ),
        ),
        Text(
          'Se souvenir de moi', 
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.center,
      child: TextButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
        ),
        child: Text(
          'Mot de passe oublié ?',
          style: TextStyle(
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleLogin() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 15),
          child: Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 15),
                child: Text('Ou continuer avec', style: TextStyle(fontSize: 16, color: Colors.grey)),
              ),
              Expanded(child: Divider()),
            ],
          ),
        ),
        GestureDetector(
          onTap: _handleGoogleSignIn,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset("assets/images/google.jpg", height: 24),
                const SizedBox(width: 10),
                const Text(
                  'Se connecter avec Google',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSignupLink() {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Pas de compte ? ', style: Theme.of(context).textTheme.bodyMedium),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SignupPage()),
            ),
            child: Text(
              'Inscrivez-vous', 
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
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