import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'login_signup/login_page.dart';
import '../widgets/sidebar.dart';
import 'marketplace/marketplace_page.dart'; // Assurez-vous que cette page existe

class ClientHomePage extends StatefulWidget {
  const ClientHomePage({super.key});

  @override
  State<ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<ClientHomePage> {
  // Fonction pour gérer la déconnexion
  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur lors de la déconnexion")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar avec icône de menu pour ouvrir le Drawer
      appBar: AppBar(
        title: const Text('Accueil Client'),
        backgroundColor: Colors.green,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              Scaffold.of(context).openDrawer(); // Ouvre le Drawer
            },
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
            tooltip: "Se déconnecter",
          ),
        ],
      ),
      // Le Drawer (Sidebar) qui contient les options
      drawer: const Sidebar(),
      // Corps de la page
      body: const Center(
        child: Text(
          'Bienvenue sur votre espace client !',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      // Footer contenant le bouton Marketplace
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MarketplacePage()),
            );
          },
          icon: const Icon(Icons.store),
          label: const Text("Marketplace"),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ),
    );
  }
}