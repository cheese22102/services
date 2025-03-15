import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
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
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _loadSavedCredentials();
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
    }
    await prefs.setBool('rememberMe', _rememberMe);
  }

  Future<void> _login() async {
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
  try {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return;

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
        CustomDialog.show(
          context, 
          'Compte non enregistré',
          'Ce compte Google n\'est pas associé à un utilisateur existant.',
        );
        return;
      }

      _redirectToHome(userCredential.user!);
    }
  } catch (e) {
    CustomDialog.show(context, 'Erreur Google', 'Échec de connexion: ${e.toString()}');
  }
}

  void _handleError(FirebaseAuthException e) {
    String message = 'Erreur de connexion';
    switch (e.code) {
      case 'user-not-found': message = 'Utilisateur non trouvé'; break;
      case 'wrong-password': message = 'Mot de passe incorrect'; break;
      case 'email-not-verified': message = 'Email non vérifié'; break;
    }
    CustomDialog.show(context, 'Erreur', message);
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
      child: Column(
        children: [
          Hero(
            tag: 'auth-hero',
            child: Image.asset('assets/images/login.png', height: 250),
          ),
          Padding(
            padding: const EdgeInsets.all(25),
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
                    children: [
                      CustomTextField(
                        controller: _emailController,
                        hint: 'Adresse email',
                        icon: Icons.email,
                        obscure: false,
                        validator: (value) => value!.contains('@') ? null : 'Email invalide',
                      ),
                      const SizedBox(height: 20),
                      CustomTextField(
                        controller: _passwordController,
                        hint: 'Mot de passe',
                        icon: Icons.lock,
                        obscure: true,
                        validator: (value) => value!.length >= 6 ? null : 'Minimum 6 caractères',
                      ),
                      _buildRememberMe(),
                      const SizedBox(height: 30),
                      CustomButton(
                        text: 'Se connecter',
                        onPressed: _login,
                        icon: Icons.login,
                      ),
                      _buildForgotPassword(),
                      const SizedBox(height: 20),
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
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }

  Widget _buildRememberMe() {
    return Row(
      children: [
        Checkbox(
          value: _rememberMe,
          onChanged: (value) => setState(() => _rememberMe = value ?? false),
        ),
        Text('Se souvenir de moi', style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  Widget _buildForgotPassword() {
    return TextButton(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
      ),
      child: const Text('Mot de passe oublié ?'),
    );
  }

  Widget _buildGoogleLogin() {
    return Column(
      children: [
        const Text('Ou continuer avec', style: TextStyle(fontSize: 16)),
        const SizedBox(height: 15),
        GestureDetector(
          onTap: _handleGoogleSignIn,
          child: const SocialIcon(imagePath: "assets/images/google.jpg"),
        ),
      ],
    );
  }

  Widget _buildSignupLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('Pas de compte ? ', style: Theme.of(context).textTheme.bodyMedium),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SignupPage()),
          ),
          child: Text('Inscrivez-vous', 
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}