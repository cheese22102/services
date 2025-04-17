import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/dark_mode_switch.dart';
import 'provider_notifications_page.dart';
import 'package:go_router/go_router.dart';

class PrestataireSidebar extends StatefulWidget {
  const PrestataireSidebar({super.key});

  @override
  State<PrestataireSidebar> createState() => _PrestataireSidebarState();
}

class _PrestataireSidebarState extends State<PrestataireSidebar> {
  final Future<DocumentSnapshot> _userDataFuture = FirebaseFirestore.instance
      .collection('users')
      .doc(FirebaseAuth.instance.currentUser!.uid)
      .get();

  Future<void> _logout() async {
    try {
      // Remove Navigator.pop and use GoRouter only
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
    // Remove Navigator.pop and use GoRouter only
    context.go('/prestataireHome/profile');
  }

  void _navigateToNotifications() {
    // Remove Navigator.pop and use GoRouter only
    context.go('/prestataireHome/notifications');
  }

  void _navigateToServiceRequests() {
    // Remove Navigator.pop and use GoRouter only
    context.go('/prestataireHome/requests');
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
                      stream: ProviderNotificationsPage.getUnreadNotificationsCount(),
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
                  ListTile(
                    leading: const Icon(Icons.assignment),
                    title: const Text("Demandes de service"),
                    onTap: _navigateToServiceRequests,
                  ),
                  ListTile(
                    leading: const Icon(Icons.message),
                    title: const Text("Messages"),
                    onTap: () {
                      // Remove Navigator.pop and use GoRouter only
                      context.go('/prestataireHome/messages');
                    },
                  ),
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

  const _UserHeader({required this.data});

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