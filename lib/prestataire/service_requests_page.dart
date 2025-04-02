import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../notifications_service.dart';
import 'package:go_router/go_router.dart';

class ServiceRequestsPage extends StatefulWidget {
  const ServiceRequestsPage({super.key});

  @override
  State<ServiceRequestsPage> createState() => _ServiceRequestsPageState();
}

class _ServiceRequestsPageState extends State<ServiceRequestsPage> {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  
  @override
  Widget build(BuildContext context) {
    if (currentUserId == null) {
      return const Scaffold(
        body: Center(child: Text('Vous devez être connecté pour voir les demandes')),
      );
    }
    
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Demandes de service'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Nouvelles'),
              Tab(text: 'Acceptées'),
              Tab(text: 'Historique'),
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
      ),
    );
  }
  
  Widget _buildRequestsList(dynamic status) {
    Query query = FirebaseFirestore.instance
        .collection('service_requests')
        .where('providerId', isEqualTo: currentUserId)
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
            final clientId = request['clientId'] as String;
            final serviceName = request['serviceName'] as String;
            final description = request['description'] as String;
            final requestDate = (request['requestDate'] as Timestamp).toDate();
            final formattedDate = DateFormat('dd/MM/yyyy à HH:mm').format(requestDate);
            
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(clientId)
                  .get(),
              builder: (context, clientSnapshot) {
                if (!clientSnapshot.hasData) {
                  return const Card(
                    margin: EdgeInsets.all(8),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                
                final clientData = clientSnapshot.data!.data() as Map<String, dynamic>;
                final clientName = '${clientData['firstname']} ${clientData['lastname']}';
                
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
                              backgroundImage: clientData['avatarUrl'] != null
                                  ? NetworkImage(clientData['avatarUrl'])
                                  : null,
                              child: clientData['avatarUrl'] == null
                                  ? Text(clientData['firstname'][0])
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    clientName,
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
                            if (request['status'] == 'pending') ...[
                              TextButton(
                                onPressed: () => _rejectRequest(requestId, clientId, clientName),
                                child: const Text('Refuser'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () => _acceptRequest(requestId, clientId, clientName),
                                child: const Text('Accepter'),
                              ),
                            ] else if (request['status'] == 'accepted') ...[
                              TextButton(
                                onPressed: () => _completeRequest(requestId, clientId, clientName),
                                child: const Text('Marquer comme terminé'),
                              ),
                            ],
                            const SizedBox(width: 8),
                            // Update the contact button in the _buildRequestsList method
                            ElevatedButton.icon(
                              icon: const Icon(Icons.chat),
                              label: const Text('Contacter'),
                              onPressed: () {
                                context.push(
                                  '/prestataireHome/chat/conversation/$clientId',
                                  extra: {
                                    'otherUserName': clientName,
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
        label = 'Nouvelle';
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
  
  Future<void> _acceptRequest(String requestId, String clientId, String clientName) async {
    try {
      await FirebaseFirestore.instance
          .collection('service_requests')
          .doc(requestId)
          .update({'status': 'accepted'});
          
      // Send notification to client
      await NotificationsService.sendNotification(
        userId: clientId,
        title: 'Demande acceptée',
        body: 'Votre demande de service a été acceptée',
        data: {
          'type': 'service_request_accepted',
          'requestId': requestId,
        },
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demande acceptée avec succès')),
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
  
  Future<void> _rejectRequest(String requestId, String clientId, String clientName) async {
    try {
      await FirebaseFirestore.instance
          .collection('service_requests')
          .doc(requestId)
          .update({'status': 'cancelled'});
          
      // Send notification to client
      await NotificationsService.sendNotification(
        userId: clientId,
        title: 'Demande refusée',
        body: 'Votre demande de service a été refusée',
        data: {
          'type': 'service_request_rejected',
          'requestId': requestId,
        },
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demande refusée')),
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
  
  Future<void> _completeRequest(String requestId, String clientId, String clientName) async {
    try {
      await FirebaseFirestore.instance
          .collection('service_requests')
          .doc(requestId)
          .update({'status': 'completed'});
          
      // Send notification to client
      await NotificationsService.sendNotification(
        userId: clientId,
        title: 'Service terminé',
        body: 'Votre service a été marqué comme terminé',
        data: {
          'type': 'service_request_completed',
          'requestId': requestId,
        },
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Service marqué comme terminé')),
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