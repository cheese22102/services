import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../login_signup/profile_edit_page.dart';
import '../login_signup/login_page.dart';
import '../widgets/dark_mode_switch.dart';
import 'package:plateforme_services/marketplace/favoris_page.dart';
import 'package:plateforme_services/marketplace/mes_produits_page.dart';
import 'package:plateforme_services/chat/chat_list_screen.dart';

class Sidebar extends StatefulWidget {
  const Sidebar({super.key});

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  bool _isMarketplaceExpanded = false; // To manage the expansion of the Marketplace section

  // Future to load user data (we use currentUser! because we assume a signed in user)
  final Future<DocumentSnapshot> _userDataFuture = FirebaseFirestore.instance
      .collection('users')
      .doc(FirebaseAuth.instance.currentUser!.uid)
      .get();

  // Function to log out
  Future<void> _logout() async {
    try {
      // Close the drawer if open
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur lors de la déconnexion")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // Fixed header with user data
          FutureBuilder<DocumentSnapshot>(
            future: _userDataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const LinearProgressIndicator(minHeight: 150);
              }
              final data = snapshot.data?.data() as Map<String, dynamic>?;
              return _UserHeader(data: data);
            },
          ),
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text("Modifier le profil"),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const ProfileEditPage()),
                      );
                    },
                  ),
                  const Divider(thickness: 1.2),
                  _buildMarketplaceSection(),
                  const Divider(thickness: 1.2),
                  ListTile(
                    leading: const Icon(Icons.exit_to_app),
                    title: const Text("Se déconnecter"),
                    onTap: _logout,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketplaceSection() {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.shopping_cart),
          title: const Text('Marketplace'),
          trailing: AnimatedRotation(
            duration: const Duration(milliseconds: 300),
            turns: _isMarketplaceExpanded ? 0.5 : 0,
            child: const Icon(Icons.arrow_drop_down),
          ),
          onTap: () => setState(() => _isMarketplaceExpanded = !_isMarketplaceExpanded),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _isMarketplaceExpanded
              ? _buildMarketplaceSubItems()
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildMarketplaceSubItems() {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0), // Indentation for sub-items
      child: Column(
        children: [
          _buildSubItem(Icons.chat, 'Mes conversations', const ChatListScreen()),
          _buildSubItem(Icons.list_alt, 'Mes posts', const MesProduitsPage()),
          _buildSubItem(Icons.star, 'Favoris', const FavorisPage()),
        ],
      ),
    );
  }

  ListTile _buildSubItem(IconData icon, String title, Widget page) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(title),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12.0),
      visualDensity: const VisualDensity(vertical: -2),
      onTap: () {
        Navigator.pop(context); // Close the drawer
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      },
    );
  }
}

class _UserHeader extends StatelessWidget {
  final Map<String, dynamic>? data;

  const _UserHeader({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final firstName = data?['firstname'] ?? "Prénom inconnu";
    final lastName = data?['lastname'] ?? "Nom inconnu";
    final email = data?['email'] ?? "Email inconnu";
    final fullName = "$firstName $lastName";

    return UserAccountsDrawerHeader(
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 117, 117, 118),
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
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Builder(
            builder: (context) => DarkModeSwitch(),
          ),
        ),
      ],
    );
  }
}
