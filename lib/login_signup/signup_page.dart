import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'login_page.dart';
import 'verification_page.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import '../widgets/social_icon.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  bool _isLoading = false;

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Erreur d'inscription"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  Future<void> _signupWithEmail() async {
    if (_formKey.currentState!.validate()) {
      if (_passwordController.text != _confirmPasswordController.text) {
        _showErrorDialog("Les mots de passe ne correspondent pas.");
        return;
      }
      
      setState(() => _isLoading = true);

      try {
        final UserCredential userCredential = 
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        if (userCredential.user != null) {
          await _handleNewUser(userCredential.user!);
        }
      } on FirebaseAuthException catch (e) {
        _handleSignupError(e);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleNewUser(User user) async {
    await user.sendEmailVerification();
    
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'email': user.email,
      'createdAt': FieldValue.serverTimestamp(),
      'role': 'pending',
    });

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const VerificationPage()),
    );
  }

  Future<void> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = 
          await googleUser.authentication;
      
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = 
          await FirebaseAuth.instance.signInWithCredential(credential);
      
      if (userCredential.user != null) {
        await _handleGoogleUser(userCredential);
      }
    } on FirebaseAuthException catch (e) {
      _showErrorDialog("Erreur Google : ${e.message}");
    }
  }

  Future<void> _handleGoogleUser(UserCredential userCredential) async {
    final user = userCredential.user!;
    final isNewUser = userCredential.additionalUserInfo!.isNewUser;

    if (isNewUser) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': user.email,
        'role': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      Navigator.pushReplacementNamed(context, '/signup2');
    } else {
      _showErrorDialog("Un compte existe déjà avec cet email Google");
    }
  }

  void _handleSignupError(FirebaseAuthException e) {
    String message = "Échec de l'inscription";
    switch (e.code) {
      case 'email-already-in-use':
        message = "Cet email est déjà utilisé";
        break;
      case 'weak-password':
        message = "Le mot de passe est trop faible";
        break;
      case 'invalid-email':
        message = "Format d'email invalide";
        break;
    }
    _showErrorDialog(message);
  }

 @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Inscription")),
      body: Stack(
        children: [
          _buildBackground(),
          _buildSignupForm(),
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).primaryColor.withOpacity(0.2),
            Theme.of(context).scaffoldBackgroundColor,
          ],
        ),
      ),
    );
  }

  Widget _buildSignupForm() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Image.asset("assets/images/register.png", height: 200),
              const SizedBox(height: 30),
              CustomTextField(
                controller: _emailController,
                hint: "Adresse email",
                icon: Icons.email,
                obscure: false,
              ),
              const SizedBox(height: 20),
              CustomTextField(
                controller: _passwordController,
                hint: "Mot de passe",
                icon: Icons.lock,
                obscure: true,
              ),
              const SizedBox(height: 20),
              CustomTextField(
                controller: _confirmPasswordController,
                hint: "Confirmer le mot de passe",
                icon: Icons.lock_outline,
                obscure: true,
              ),
              const SizedBox(height: 30),
              CustomButton(
                text: "S'inscrire",
                onPressed: _signupWithEmail,
                icon: Icons.person_add, // Ajoutez cette ligne

              ),
              const SizedBox(height: 20),
              const Text("Ou continuer avec"),
              const SizedBox(height: 15),
              GestureDetector(
                onTap: _signInWithGoogle,
                child: const SocialIcon(imagePath: "assets/images/google.jpg"),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                ),
                child: Text(
                  "Déjà un compte ? Connectez-vous",
                  style: TextStyle(color: Theme.of(context).primaryColor),
                ),
              ),
            ],
          ),
        ),
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
}