import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/dark_mode_switch.dart';
import '../client/page_notifications.dart';
import 'package:go_router/go_router.dart';

class Sidebar extends StatefulWidget {
  const Sidebar({super.key});

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  bool _isMarketplaceExpanded = false;

  final Future<DocumentSnapshot> _userDataFuture = FirebaseFirestore.instance
      .collection('users')
      .doc(FirebaseAuth.instance.currentUser!.uid)
      .get();

  Future<void> _logout() async {
    try {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();
      if (!mounted) return;
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur lors de la déconnexion")),
      );
    }
  }

  void _navigateToProfile() {
    Navigator.pop(context);
    context.go('/clientHome/profile');
  }

  void _navigateToNotifications() {
    Navigator.pop(context);
    context.go('/clientHome/notifications');
  }

  Widget _buildMarketplaceItem(String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      contentPadding: const EdgeInsets.only(left: 32.0),
      onTap: onTap,
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
          onTap: () {
            setState(() {
              _isMarketplaceExpanded = !_isMarketplaceExpanded;
            });
            Navigator.pop(context);
            context.go('/clientHome/marketplace');
          },
        ),
        if (_isMarketplaceExpanded) ...[
          _buildMarketplaceItem(
            'Mes favoris',
            Icons.favorite,
            () {
              Navigator.pop(context);
              context.go('/clientHome/marketplace/favorites');
            },
          ),
          _buildMarketplaceItem(
            'Mes produits',
            Icons.inventory,
            () {
              Navigator.pop(context);
              context.go('/clientHome/marketplace/my-products');
            },
          ),
          _buildMarketplaceItem(
            'Messages',
            Icons.chat,
            () {
              Navigator.pop(context);
              context.go('/clientHome/marketplace/chat');
            },
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
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
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.person),
                    title: const Text("Modifier le profil"),
                    onTap: _navigateToProfile,
                  ),
                  ListTile(
                    leading: const Icon(Icons.notifications),
                    title: const Text("Notifications"),
                    trailing: StreamBuilder<int>(
                      stream: NotificationsPage.getUnreadNotificationsCount(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data! > 0) {
                          return Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            child: Text(
                              '${snapshot.data}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    onTap: _navigateToNotifications,
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
}

class _UserHeader extends StatelessWidget {
  final Map<String, dynamic>? data;

  const _UserHeader({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final firstName = data?['firstname'] ?? "Prénom inconnu";
    final lastName = data?['lastname'] ?? "Nom inconnu";
    final email = data?['email'] ?? "Email inconnu";
    final avatarUrl = data?['avatarUrl'];
    final fullName = "$firstName $lastName";

    return UserAccountsDrawerHeader(
      decoration: const BoxDecoration(
        color: Color.fromARGB(255, 117, 117, 118),
      ),
      accountName: Text(
        fullName,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      accountEmail: Text(email),
      currentAccountPicture: CircleAvatar(
        backgroundColor: Colors.white,
        child: avatarUrl != null && avatarUrl.isNotEmpty
            ? ClipOval(
                child: Image.network(
                  avatarUrl,
                  width: 90,
                  height: 90,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.person,
                    size: 50,
                    color: Colors.green,
                  ),
                ),
              )
            : const Icon(
                Icons.person,
                size: 50,
                color: Colors.green,
              ),
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
