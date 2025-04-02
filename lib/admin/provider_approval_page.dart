import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../notifications_service.dart';
import 'package:go_router/go_router.dart';

// Move VerificationItem class outside
class VerificationItem {
  final String title;
  final String description;
  bool isVerified;

  VerificationItem({
    required this.title,
    required this.description,
    this.isVerified = false,
  });
}

// Change to StatefulWidget
class ProviderApprovalPage extends StatefulWidget {
  const ProviderApprovalPage({super.key});

  @override
  State<ProviderApprovalPage> createState() => _ProviderApprovalPageState();
}

class _ProviderApprovalPageState extends State<ProviderApprovalPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  String _searchQuery = '';
  final List<VerificationItem> _checkList = [
    VerificationItem(
      title: 'Identité',
      description: 'Vérifier la validité de la pièce d\'identité',
    ),
    VerificationItem(
      title: 'Coordonnées professionnelles',
      description: 'Vérifier la validité des coordonnées',
    ),
    VerificationItem(
      title: 'Certifications',
      description: 'Vérifier l\'authenticité des certifications',
    ),
    VerificationItem(
      title: 'Zone de travail',
      description: 'Vérifier la cohérence de la zone d\'intervention',
    ),
    VerificationItem(
      title: 'Tarifs',
      description: 'Vérifier la cohérence des tarifs proposés',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Validation des Prestataires'),
      ),
      body: Column(
        children: [
          // Add search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Rechercher par nom ou prénom...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          // List of requests
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('provider_requests')
                  .where('isVerified', isEqualTo: false)
                  .where('status', isEqualTo: 'pending')  // Only show pending requests
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Une erreur est survenue'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final requests = snapshot.data?.docs ?? [];
                
                // Filter requests based on search query
                final filteredRequests = requests.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final fullName = '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.toLowerCase();
                  return _searchQuery.isEmpty || fullName.contains(_searchQuery);
                }).toList();

                if (filteredRequests.isEmpty) {
                  return const Center(
                    child: Text('Aucune demande en attente'),
                  );
                }

                return ListView.builder(
                  itemCount: filteredRequests.length,
                  itemBuilder: (context, index) {
                    final data = filteredRequests[index].data() as Map<String, dynamic>;
                    final providerId = filteredRequests[index].id;
                    
                    return Card(
                      margin: const EdgeInsets.all(8),
                      child: ListTile(
                        title: Text('${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Email: ${data['professionalEmail']}'),
                            Text('Services: ${(data['services'] as List).join(", ")}'),
                            Text('Téléphone: ${data['professionalPhone']}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.visibility),
                              onPressed: () => _showProviderDetails(context, data, providerId),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showProviderDetails(BuildContext context, Map<String, dynamic> data, String providerId) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Détails du Prestataire'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Provider details
                Text('Email: ${data['professionalEmail']}'),
                const SizedBox(height: 8),
                Text('Téléphone: ${data['professionalPhone']}'),
                const SizedBox(height: 8),
                Text('Adresse: ${data['professionalAddress']}'),
                const SizedBox(height: 8),
                Text('Zone de travail: ${data['workingArea']}'),
                const SizedBox(height: 8),
                Text('Bio: ${data['bio']}'),
                const SizedBox(height: 8),
                Text('Services: ${(data['services'] as List).join(", ")}'),
                const SizedBox(height: 8),
                Text('Tarifs: ${data['rateRange']['min']} - ${data['rateRange']['max']} DT/h'),
                
                const Divider(height: 32),
                const Text('Liste de vérification:', 
                  style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                
                ..._checkList.map((item) => CheckboxListTile(
                  title: Text(item.title),
                  subtitle: Text(item.description),
                  value: item.isVerified,
                  onChanged: (bool? value) {
                    setState(() {
                      item.isVerified = value ?? false;
                    });
                  },
                )).toList(),

                const Divider(height: 32),
                const Text('Commentaire:', 
                  style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _commentController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Ajouter un commentaire si refusé...',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),
                const Text('Documents:', style: TextStyle(fontWeight: FontWeight.bold)),
                Image.network(data['idCardUrl'], height: 200),
                if (data['certificationFiles'] != null && 
                    (data['certificationFiles'] as List).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Certifications:', style: TextStyle(fontWeight: FontWeight.bold)),
                  ...List.generate(
                    (data['certificationFiles'] as List).length,
                    (index) => Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Image.network(
                        data['certificationFiles'][index],
                        height: 200,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              // Replace Navigator.pop with context.pop
              onPressed: () => context.pop(),
              child: const Text('Fermer'),
            ),
            TextButton(
              onPressed: () => _rejectProvider(context, providerId),
              child: const Text('Refuser', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: _isCheckListComplete() 
                  ? () => _approveProvider(context, providerId)
                  : null,
              child: const Text('Approuver'),
            ),
          ],
        ),
      ),
    );
  }

  bool _isCheckListComplete() {
    return _checkList.every((item) => item.isVerified);
  }

  Future<void> _rejectProvider(BuildContext context, String providerId) async {
    if (!_isCheckListComplete()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez compléter toute la checklist')),
      );
      return;
    }

    try {
      // Update provider request status
      await FirebaseFirestore.instance
          .collection('provider_requests')
          .doc(providerId)
          .update({
        'status': 'rejected',
        'rejectionReason': _commentController.text,
        'reviewedAt': Timestamp.now(),
        'reviewedBy': FirebaseAuth.instance.currentUser?.uid,
      });

      // Send notification using NotificationsService
      await NotificationsService.sendProviderStatusNotification(
        providerId: providerId,
        status: 'rejected',
        rejectionReason: _commentController.text,
      );

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demande rejetée')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _approveProvider(BuildContext context, String providerId) async {
    if (!_isCheckListComplete()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez compléter toute la checklist')),
      );
      return;
    }

    try {
      // Update provider request status
      await FirebaseFirestore.instance
          .collection('provider_requests')
          .doc(providerId)
          .update({
        'isVerified': true,
        'status': 'approved',
        'reviewedAt': Timestamp.now(),
        'reviewedBy': FirebaseAuth.instance.currentUser?.uid,
      });

      // Send notification using NotificationsService
      await NotificationsService.sendProviderStatusNotification(
        providerId: providerId,
        status: 'approved',
      );

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prestataire approuvé avec succès')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }
}