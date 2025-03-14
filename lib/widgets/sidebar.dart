import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../profile_edit_page.dart'; // Assurez-vous que ce fichier existe
import '../login_signup/login_page.dart'; // Assurez-vous que ce fichier existe
import '../widgets/dark_mode_switch.dart'; // Importez correctement votre widget DarkModeSwitch

class Sidebar extends StatefulWidget {
  const Sidebar({super.key});

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  Future<Map<String, dynamic>?> _getUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      return userDoc.data() as Map<String, dynamic>?;
    }
    return null;
  }

  // Fonction de déconnexion
  Future<void> _logout() async {
    try {
      // Fermer le Drawer pour obtenir un contexte valide du Scaffold parent
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    } catch (e) {
      if (!mounted) return;
      // Affichage du SnackBar avec un contexte valide
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur lors de la déconnexion")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: FutureBuilder<Map<String, dynamic>?>(
        future: _getUserData(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("Erreur de chargement des données"));
          }

          Map<String, dynamic> userData = snapshot.data!;

          // Utilisation d'opérateurs null-aware pour gérer les valeurs nulles
          String firstName = userData['firstName'] ?? "Prénom inconnu";
          String lastName = userData['lastName'] ?? "Nom inconnu";
          String email = userData['email'] ?? "Email inconnu";

          String fullName = "$firstName $lastName"; // Combinaison du prénom et du nom

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              UserAccountsDrawerHeader(
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 117, 117, 118), // Couleur de fond
                ),
                accountName: Text(
                  fullName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                accountEmail: Text(email),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.person, size: 50, color: Colors.green),
                ),
                otherAccountsPictures: [
                  // Enveloppement dans un Builder pour obtenir le bon contexte
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: Builder(
                      builder: (context) => DarkModeSwitch(), // Note : pas de const ici
                    ),
                  ),
                ],
              ),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text("Modifier le profil"),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileEditPage()),
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.exit_to_app),
                title: const Text("Se déconnecter"),
                onTap: _logout,
              ),
            ],
          );
        },
      ),
    );
  }
}
