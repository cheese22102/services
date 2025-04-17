import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'prestataire_sidebar.dart';
import 'provider_notifications_page.dart';

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
          // Add notifications button
          StreamBuilder<int>(
            stream: ProviderNotificationsPage.getUnreadNotificationsCount(),
            builder: (context, snapshot) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications),
                    onPressed: () => context.push('/prestataireHome/notifications'),
                    tooltip: 'Notifications',
                  ),
                  if (snapshot.hasData && snapshot.data! > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${snapshot.data}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      drawer: const PrestataireSidebar(),
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
            
            // View Profile button
            StreamBuilder<DocumentSnapshot>(
              stream: _providerRequestStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox.shrink();
                }
                
                final data = snapshot.data?.data() as Map<String, dynamic>?;
                final status = data?['status'] as String?;
                
                // Only show the button if the provider is approved
                if (status == 'approved') {
                  return ElevatedButton.icon(
                    onPressed: () => _viewProviderProfile(context),
                    icon: const Icon(Icons.visibility),
                    label: const Text('Voir mon profil prestataire'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            
            const SizedBox(height: 12),
            
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
            
            // Messages button
            ElevatedButton.icon(
              onPressed: () => context.push('/prestataireHome/messages'),
              icon: const Icon(Icons.message),
              label: const Text('Messages'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
  
  // Add this method to view the provider's own profile
  Future<void> _viewProviderProfile(BuildContext context) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    
    try {
      // Get provider data
      final providerData = await FirebaseFirestore.instance
          .collection('provider_requests')
          .doc(userId)
          .get();
          
      // Get user data
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (!mounted) return;
      
      // Get service name
      final serviceId = providerData.data()?['serviceId'];
      final serviceDoc = await FirebaseFirestore.instance
          .collection('services')
          .doc(serviceId)
          .get();
      final serviceName = serviceDoc.data()?['name'] ?? 'Service inconnu';
      
      if (!mounted) return;
      
      // Navigate to provider profile page with isOwnProfile flag using GoRouter
      context.push('/prestataireHome/providerProfile', extra: {
        'providerId': userId,
        'providerData': providerData.data() ?? {},
        'userData': userData.data() ?? {},
        'serviceName': serviceName,
        'isOwnProfile': true, // This flag will hide contact buttons and review options
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }
}
