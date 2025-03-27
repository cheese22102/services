import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:badges/badges.dart' as badges;
import 'provider_notifications_page.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'provider_chat_list.dart';
import 'package:go_router/go_router.dart';

class PrestataireHomePage extends StatefulWidget {
  const PrestataireHomePage({super.key});

  @override
  State<PrestataireHomePage> createState() => _PrestataireHomePageState();
}

// Add to imports

class _PrestataireHomePageState extends State<PrestataireHomePage> {
  late Stream<DocumentSnapshot> _providerRequestStream;

  @override
  void initState() {
    super.initState();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    _providerRequestStream = FirebaseFirestore.instance
        .collection('provider_requests')
        .doc(userId)
        .snapshots();
    _saveFCMToken();
  }

  Future<void> _saveFCMToken() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'fcmToken': token});
      }
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  Future<void> _logout(BuildContext context) async {
    try {
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

  Widget _buildProviderStatus() {
    return StreamBuilder<DocumentSnapshot>(
      stream: _providerRequestStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        final data = snapshot.data?.data() as Map<String, dynamic>?;
        
        if (data == null) {
          return ElevatedButton.icon(
            onPressed: () => context.go('/prestataireHome/registration'),
            icon: const Icon(Icons.app_registration),
            label: const Text('Compléter mon profil prestataire'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          );
        }

        final status = data['status'] as String?;
        
        switch (status) {
          case 'pending':
            return const Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text(
                  'Votre demande est en cours d\'examen',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 8),
                Text(
                  'Vous serez notifié dès qu\'une décision sera prise',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            );
            
          case 'rejected':
            return Column(
              children: [
                const Text(
                  'Votre demande précédente a été refusée',
                  style: TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => context.go('/prestataireHome/registration'),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Soumettre une nouvelle demande'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            );
            
          case 'approved':
            return const Text(
              'Votre compte prestataire est actif',
              style: TextStyle(
                color: Colors.green,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            );
            
          default:
            return ElevatedButton.icon(
              onPressed: () => context.go('/prestataireHome/registration'),
              icon: const Icon(Icons.app_registration),
              label: const Text('Compléter mon profil prestataire'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accueil Prestataire'),
        backgroundColor: Colors.green,
        actions: [
          StreamBuilder<int>(
            stream: ProviderChatListScreen.getTotalUnreadCount(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return badges.Badge(
                showBadge: unreadCount > 0,
                badgeContent: Text(
                  unreadCount.toString(),
                  style: const TextStyle(color: Colors.white),
                ),
                position: badges.BadgePosition.topEnd(top: 0, end: 0),
                child: IconButton(
                  icon: const Icon(Icons.chat),
                  onPressed: () => context.go('/prestataireHome/chat'),
                ),
              );
            },
          ),
          StreamBuilder<int>(
            stream: ProviderNotificationsPage.getUnreadNotificationsCount(),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              return badges.Badge(
                showBadge: unreadCount > 0,
                badgeContent: Text(
                  unreadCount.toString(),
                  style: const TextStyle(color: Colors.white),
                ),
                position: badges.BadgePosition.topEnd(top: 0, end: 0),
                child: IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: () => context.go('/prestataireHome/notifications'),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: "Se déconnecter",
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Bienvenue sur votre espace prestataire !',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _buildProviderStatus(),
          ],
        ),
      ),
    );
  }
}