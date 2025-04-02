import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';

class PrestataireHomePage extends StatefulWidget {
  const PrestataireHomePage({super.key});

  @override
  State<PrestataireHomePage> createState() => _PrestataireHomePageState();
}

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
        actions: [
          // Add logout button in app bar
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _logout(context),
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      // Remove the drawer since there's no sidebar for this page
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Provider status card
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Statut de votre compte prestataire',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildProviderStatus(),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Service Requests button
            ElevatedButton.icon(
              onPressed: () => context.push('/prestataireHome/requests'),
              icon: const Icon(Icons.assignment),
              label: const Text('Voir les demandes de service'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Add logout button at the bottom as well
            ElevatedButton.icon(
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout),
              label: const Text('Déconnexion'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                backgroundColor: Colors.red.shade100,
                foregroundColor: Colors.red.shade900,
              ),
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
