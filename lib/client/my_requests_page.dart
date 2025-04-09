import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../notifications_service.dart';
import 'package:go_router/go_router.dart';
class MyRequestsPage extends StatefulWidget {
  const MyRequestsPage({super.key});

  @override
  State<MyRequestsPage> createState() => _MyRequestsPageState();
}

class _MyRequestsPageState extends State<MyRequestsPage> {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  
  @override
  Widget build(BuildContext context) {
    if (currentUserId == null) {
      return const Scaffold(
        body: Center(child: Text('Vous devez être connecté pour voir vos demandes')),
      );
    }
    
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Mes demandes de service'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'En attente'),
              Tab(text: 'Acceptées'),
              Tab(text: 'Terminées/Annulées'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildRequestsList('pending'),
            _buildRequestsList('accepted'),
            _buildRequestsList(['completed', 'cancelled']),
          ],
        ),
        // Ajout de la barre de navigation en bas
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: 1, // L'index actuel est 1 car nous sommes sur la page des demandes
          onTap: (index) {
            if (index == 0) {
              // Navigation vers la page d'accueil client
              context.go('/clientHome');
            } else if (index == 2) {
              // Navigation vers la marketplace
              context.go('/clientHome/marketplace');
            }
            // Si index == 1, nous sommes déjà sur la page des demandes, donc ne rien faire
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Accueil',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment),
              label: 'Mes demandes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.shopping_cart),
              label: 'Marketplace',
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRequestsList(dynamic status) {
    Query query = FirebaseFirestore.instance
        .collection('service_requests')
        .where('clientId', isEqualTo: currentUserId)
        .orderBy('createdAt', descending: true);
    
    if (status is List) {
      query = query.where('status', whereIn: status);
    } else {
      query = query.where('status', isEqualTo: status);
    }
    
    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Une erreur est survenue'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data?.docs ?? [];
        
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.assignment_outlined, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  status is List 
                      ? 'Aucune demande terminée ou annulée'
                      : 'Aucune demande ${status == "pending" ? "en attente" : "acceptée"}',
                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index].data() as Map<String, dynamic>;
            final requestId = requests[index].id;
            
            // Add null checks for all fields
            final providerId = request['providerId'] as String? ?? '';
            final serviceName = request['serviceName'] as String? ?? '';
            final description = request['description'] as String? ?? '';
            
            // Handle potential null timestamp
            final requestDate = request['requestDate'] is Timestamp 
                ? (request['requestDate'] as Timestamp).toDate() 
                : DateTime.now();
            final formattedDate = DateFormat('dd/MM/yyyy à HH:mm').format(requestDate);
            
            // Skip this item if providerId is empty
            if (providerId.isEmpty) {
              return const SizedBox.shrink();
            }
            
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(providerId)
                  .get(),
              builder: (context, providerSnapshot) {
                if (!providerSnapshot.hasData) {
                  return const Card(
                    margin: EdgeInsets.all(8),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                
                // Add null check for provider data
                final providerData = providerSnapshot.data!.data() as Map<String, dynamic>?;
                if (providerData == null) {
                  return Card(
                    margin: const EdgeInsets.all(8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Prestataire non trouvé (ID: $providerId)'),
                    ),
                  );
                }
                
                // Add null checks for provider name fields
                final firstName = providerData['firstname'] as String? ?? '';
                final lastName = providerData['lastname'] as String? ?? '';
                final providerName = '$firstName $lastName'.trim();
                
                return Card(
                  margin: const EdgeInsets.all(8),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundImage: providerData['avatarUrl'] != null
                                  ? NetworkImage(providerData['avatarUrl'])
                                  : null,
                              child: providerData['avatarUrl'] == null
                                  ? Text(providerData['firstname'][0])
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    providerName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  Text(
                                    serviceName,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            _buildStatusChip(request['status']),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Description: $description',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Date prévue: $formattedDate',
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (request['status'] == 'pending')
                              TextButton(
                                onPressed: () => _cancelRequest(requestId),
                                child: const Text('Annuler'),
                              ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.chat),
                              label: const Text('Contacter'),
                              onPressed: () {
                                context.push(
                                  '/clientHome/chat/conversation/$providerId',
                                  extra: {
                                    'otherUserName': providerName,
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
  
  Widget _buildStatusChip(String status) {
    Color color;
    String label;
    
    switch (status) {
      case 'pending':
        color = Colors.orange;
        label = 'En attente';
        break;
      case 'accepted':
        color = Colors.green;
        label = 'Acceptée';
        break;
      case 'completed':
        color = Colors.blue;
        label = 'Terminée';
        break;
      case 'cancelled':
        color = Colors.red;
        label = 'Annulée';
        break;
      default:
        color = Colors.grey;
        label = 'Inconnu';
    }
    
    return Chip(
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
        ),
      ),
      backgroundColor: color,
      padding: const EdgeInsets.all(4),
    );
  }
  
  Future<void> _cancelRequest(String requestId) async {
    try {
      // Get provider ID before updating the request
      final requestDoc = await FirebaseFirestore.instance
          .collection('service_requests')
          .doc(requestId)
          .get();
      
      final requestData = requestDoc.data();
      if (requestData == null) return;
      
      final providerId = requestData['providerId'] as String;
      final serviceName = requestData['serviceName'] as String;
      
      // Update request status
      await FirebaseFirestore.instance
          .collection('service_requests')
          .doc(requestId)
          .update({'status': 'cancelled'});
      
      // Send notification to provider
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .get();
      
      final userData = userDoc.data();
      if (userData != null) {
        final clientName = '${userData['firstname']} ${userData['lastname']}';
        
        // Send notification using your existing notification service
        await NotificationsService.sendNotification(
          userId: providerId,
          title: 'Demande annulée',
          body: 'Le client $clientName a annulé sa demande de $serviceName',
          data: {
            'type': 'service_request_cancelled',
            'requestId': requestId,
          },
        );
      }
          
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demande annulée avec succès')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }
  
  // Add a method to rate completed services
  Future<void> _rateService(String requestId, String providerId, String providerName) async {
    double rating = 3.0; // Default rating
    String comment = '';
    
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Évaluer $providerName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Comment évaluez-vous ce service?'),
            const SizedBox(height: 16),
            StatefulBuilder(
              builder: (context, setState) => Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 36,
                    ),
                    onPressed: () {
                      setState(() {
                        rating = index + 1.0;
                      });
                    },
                  );
                }),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Commentaire (optionnel)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              onChanged: (value) {
                comment = value;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(), // Changed from Navigator.pop
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => context.pop({ // Changed from Navigator.pop
              'rating': rating,
              'comment': comment,
            }),
            child: const Text('Soumettre'),
          ),
        ],
      ),
    );
    
    if (result != null) {
      try {
        // Save the review
        await FirebaseFirestore.instance
            .collection('provider_reviews')
            .add({
              'providerId': providerId,
              'clientId': currentUserId,
              'requestId': requestId,
              'rating': result['rating'],
              'comment': result['comment'],
              'createdAt': FieldValue.serverTimestamp(),
            });
        
        // Update provider's average rating
        final reviewsSnapshot = await FirebaseFirestore.instance
            .collection('provider_reviews')
            .where('providerId', isEqualTo: providerId)
            .get();
        
        double totalRating = 0;
        for (var doc in reviewsSnapshot.docs) {
          totalRating += (doc.data()['rating'] as num).toDouble();
        }
        
        final averageRating = totalRating / reviewsSnapshot.docs.length;
        
        await FirebaseFirestore.instance
            .collection('provider_requests')
            .doc(providerId)
            .update({
              'averageRating': averageRating,
              'reviewCount': reviewsSnapshot.docs.length,
            });
        
        // Send notification to provider
        await NotificationsService.sendNotification(
          userId: providerId,
          title: 'Nouvelle évaluation',
          body: 'Vous avez reçu une évaluation de ${result['rating']} étoiles',
          data: {
            'type': 'new_review',
            'requestId': requestId,
            'rating': result['rating'],
          },
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Merci pour votre évaluation!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e')),
          );
        }
      }
    }
  }
}