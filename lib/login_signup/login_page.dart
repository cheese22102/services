import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'signup_page.dart';
import 'forgot_password_page.dart';
import '../client_home_page.dart';
import '../prestataire_home_page.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/custom_button.dart';
import '../widgets/social_icon.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _showErrorDialog(String message) {
    if (!mounted) return; // Prevent calling setState or showDialog if the widget is unmounted
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Erreur de connexion"),
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

  /// 🔥 **Fonction pour récupérer le rôle et rediriger l'utilisateur**
  Future<void> _redirectToHomePage(User user) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        String role = userDoc['role'];
        if (role == "client") {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ClientHomePage()),
          );
        } else if (role == "prestataire") {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const PrestataireHomePage()),
          );
        } else {
          _showErrorDialog("Rôle inconnu. Contactez l'administrateur.");
        }
      } else {
        _showErrorDialog("Utilisateur introuvable.");
      }
    } catch (e) {
      if (mounted) {
      _showErrorDialog("Erreur lors de la récupération des données utilisateur.");
    }
    }
  }

  /// ✅ **Connexion avec Email/Mot de passe**
  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      try {
        UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        if (userCredential.user!.emailVerified) {
          _redirectToHomePage(userCredential.user!);
        } else {
          _showErrorDialog("Veuillez vérifier votre e-mail avant de vous connecter.");
        }
      } on FirebaseAuthException catch (e) {
        String errorMessage = "Échec de la connexion.";
        if (e.code == 'user-not-found') {
          errorMessage = "Aucun utilisateur trouvé pour cet email.";
        } else if (e.code == 'wrong-password') {
          errorMessage = "Le mot de passe est incorrect.";
        }
        _showErrorDialog(errorMessage);
      }
    }
  }

  /// 🔥 **Connexion avec Google**
  Future<void> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return; // L'utilisateur a annulé la connexion

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        if (!userDoc.exists) {
          // Si l'utilisateur est nouveau, l'envoyer vers la page d'inscription pour compléter son profil
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SignupPage()),
          );
        } else {
          // Si l'utilisateur existe déjà, rediriger selon son rôle
          _redirectToHomePage(user);
        }
      }
    } on FirebaseAuthException catch (e) {
      _showErrorDialog("Erreur de connexion : ${e.message}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: const Text("Connexion")),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Image.asset("assets/images/login.png", height: 220),
              Container(
                padding: const EdgeInsets.all(30),
                width: double.infinity,
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height - 400,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(45)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      "Connectez-vous à votre compte",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge!.color,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          CustomTextField(
                            controller: _emailController,
                            hint: "Adresse e-mail",
                            icon: Icons.email,
                            obscure: false,
                          ),
                          CustomTextField(
                            controller: _passwordController,
                            hint: "Mot de passe",
                            icon: Icons.lock,
                            obscure: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    CustomButton(text: "Se connecter", onPressed: _login),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _signInWithGoogle,
                      child: SocialIcon(imagePath: "assets/images/google.jpg"),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const ForgotPasswordPage()),
                        );
                      },
                      child: const Text("Mot de passe oublié ?"),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Vous n'avez pas de compte ?",
                          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const SignupPage()),
                          ),
                          child: Text(
                            "Inscrivez-vous ici",
                            style: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
