import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'login_signup/login_page.dart'; // Assurez-vous que le chemin est correct

class PrestataireHomePage extends StatelessWidget {
  const PrestataireHomePage({super.key});

  // Fonction de déconnexion
  Future<void> _logout(BuildContext context) async {
    try {
      // Déconnexion de Firebase
      await FirebaseAuth.instance.signOut();
      
      // Déconnexion du compte Google
      await GoogleSignIn().signOut();

      // Redirection vers la page de login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    } catch (e) {
      // Si une erreur se produit, afficher un message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur lors de la déconnexion")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accueil Prestataire'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: "Se déconnecter",
          ),
        ],
      ),
      body: const Center(
        child: Text(
          'Bienvenue sur votre espace prestataire !',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
