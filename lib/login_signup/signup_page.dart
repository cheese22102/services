import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'login_page.dart';
import 'verification_page.dart';
import 'signup2_page.dart'; // Importer la page de complétion de profil
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

  // Fonction pour afficher un message d'erreur
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

  // Fonction pour gérer l'inscription avec email et mot de passe
  Future<void> _signup() async {
    if (_formKey.currentState!.validate()) {
      if (_passwordController.text != _confirmPasswordController.text) {
        _showErrorDialog("Les mots de passe ne correspondent pas.");
        return;
      }
      try {
        // Créer un utilisateur avec email et mot de passe
        UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        User? user = userCredential.user;
        if (user != null) {
          // Envoyer un e-mail de vérification
          await user.sendEmailVerification();

          // Ajouter l'utilisateur à la collection Firestore avec un rôle "pending"
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'email': user.email,
            'role': 'pending', // Le rôle doit être défini plus tard
          });

          // Afficher un message pour informer l'utilisateur que l'e-mail de vérification a été envoyé
          _showErrorDialog("Un e-mail de vérification a été envoyé. Veuillez vérifier votre boîte de réception.");

          // Rediriger vers la page de vérification de l'e-mail
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const VerificationPage()),
          );
        }
      } on FirebaseAuthException catch (e) {
        String errorMessage = "Échec de l'inscription.";
        if (e.code == 'email-already-in-use') {
          errorMessage = "Cet e-mail est déjà utilisé.";
        } else if (e.code == 'weak-password') {
          errorMessage = "Le mot de passe est trop faible.";
        } else if (e.code == 'invalid-email') {
          errorMessage = "Format d'email invalide.";
        }
        _showErrorDialog(errorMessage);
      }
    }
  }

  // Fonction pour gérer la connexion avec Google
  Future<void> _signInWithGoogle() async {
    try {
      // Connexion avec Google
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return; // L'utilisateur a annulé la connexion

      // Obtenir l'authentification de Google
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Se connecter avec les informations de Google
      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        // Vérifier si l'utilisateur est un nouvel utilisateur
        bool isNewUser = userCredential.additionalUserInfo!.isNewUser;

        if (isNewUser) {
          // Si l'utilisateur est nouveau, le rediriger vers la page de complétion de profil
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'email': user.email,
            'role': 'pending',
          });

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const Signup2Page()),
          );
        } else {
          // Si l'utilisateur existe déjà, afficher un message d'erreur
          _showErrorDialog("Vous avez déjà un compte avec ce Google account.");
        }
      }
    } on FirebaseAuthException catch (e) {
      _showErrorDialog("Erreur : ${e.message}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text("Inscription"),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Image.asset("assets/images/register.png", height: 220),
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
                      "Créez un nouveau compte",
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
                          CustomTextField(
                            controller: _confirmPasswordController,
                            hint: "Confirmer le mot de passe",
                            icon: Icons.lock,
                            obscure: true,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    CustomButton(text: "S'inscrire", onPressed: _signup),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _signInWithGoogle,
                      child: SocialIcon(imagePath: "assets/images/google.jpg"),
                    ),
                    const SizedBox(height: 15),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Vous avez déjà un compte ?",
                          style: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginPage()),
                          ),
                          child: Text(
                            "Connectez-vous ici",
                            style: TextStyle(
                              color: Theme.of(context).textTheme.bodyMedium!.color,
                            ),
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
