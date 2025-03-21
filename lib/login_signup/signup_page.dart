import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'login_page.dart';
import 'verification_page.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import '../widgets/social_icon.dart';
import'../widgets/password_strength_indicator.dart';

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
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Erreur d'inscription"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Fermer"),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Succès"),
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
    setState(() => _isLoading = true);
    
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

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
    } catch (e) {
      _showErrorDialog("Une erreur s'est produite lors de la connexion avec Google");
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        message = "Cette adresse email est déjà utilisée par un autre compte";
        break;
      case 'weak-password':
        message = "Le mot de passe est trop faible. Utilisez au moins 6 caractères avec des lettres et des chiffres";
        break;
      case 'invalid-email':
        message = "Format d'adresse email invalide";
        break;
      case 'operation-not-allowed':
        message = "La création de compte est temporairement désactivée";
        break;
      case 'network-request-failed':
        message = "Problème de connexion réseau. Vérifiez votre connexion internet";
        break;
      case 'too-many-requests':
        message = "Trop de tentatives. Veuillez réessayer plus tard";
        break;
      default:
        message = "Une erreur s'est produite: ${e.message}";
    }
    _showErrorDialog(message);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.green.withOpacity(0.3),
                  Colors.white,
                ],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 20),
                      Image.asset(
                        "assets/images/register.png",
                        height: 180,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        "Créer un compte",
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 30),
                      
                      // Champ email
                      CustomTextField(
                        controller: _emailController,
                        hint: "Adresse email",
                        icon: Icons.email,
                        obscure: false,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'L\'adresse email est requise';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                            return 'Format d\'email invalide';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),
                      
                      // Champ mot de passe
                      // Dans le widget TextFormField pour le mot de passe
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Mot de passe',
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Champ obligatoire';
                          if (value.length < 8) return 'Le mot de passe doit contenir au moins 8 caractères';
                          if (!RegExp(r'[A-Z]').hasMatch(value)) return 'Au moins une majuscule requise';
                          if (!RegExp(r'[0-9]').hasMatch(value)) return 'Au moins un chiffre requis';
                          if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) 
                            return 'Au moins un caractère spécial requis';
                          return null;
                        },
                        onChanged: (value) => setState(() {}),
                      ),
                      PasswordStrengthIndicator(password: _passwordController.text),
                      const SizedBox(height: 16),
                      const SizedBox(height: 20),
                      
                      // Champ confirmation mot de passe
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          hintText: "Confirmer le mot de passe",
                          prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword = !_obscureConfirmPassword;
                              });
                            },
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.grey.withOpacity(0.1),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez confirmer votre mot de passe';
                          }
                          if (value != _passwordController.text) {
                            return 'Les mots de passe ne correspondent pas';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 30),
                      
                      // Bouton d'inscription
                      CustomButton(
                        text: "S'inscrire",
                        onPressed: _signupWithEmail,
                        icon: Icons.person_add,
                      ),
                      const SizedBox(height: 20),
                      
                      // Séparateur
                      Row(
                        children: [
                          Expanded(child: Divider(color: Colors.grey[400])),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              "Ou continuer avec",
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ),
                          Expanded(child: Divider(color: Colors.grey[400])),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // Connexion Google
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[300]!),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: InkWell(
                              onTap: _signInWithGoogle,
                              child: const Padding(
                                padding: EdgeInsets.all(12),
                                child: SocialIcon(
                                  imagePath: "assets/images/google.jpg",
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      
                      // Lien vers la page de connexion
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Vous avez déjà un compte ? ",
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const LoginPage()),
                            ),
                            child: const Text(
                              "Se connecter",
                              style: TextStyle(
                                color: Colors.green,
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
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                ),
              ),
            ),
        ],
      ),
    );
  }
}