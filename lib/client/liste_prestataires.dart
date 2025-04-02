import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../chat/conversation_service_page.dart';
import 'provider_profile_page.dart';

class ServiceProvidersPage extends StatelessWidget {
  final String serviceName;

  const ServiceProvidersPage({
    super.key,
    required this.serviceName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Prestataires - $serviceName'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('provider_requests')
            .where('status', isEqualTo: 'approved')
            .where('services', arrayContains: serviceName)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Une erreur est survenue'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final providers = snapshot.data?.docs ?? [];

          if (providers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_off, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun prestataire disponible pour $serviceName',
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: providers.length,
            itemBuilder: (context, index) {
              final providerData = providers[index].data() as Map<String, dynamic>;
              final providerId = providerData['userId'] as String;

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('users')
                    .doc(providerId)
                    .get(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const SizedBox();
                  }

                  final userData = userSnapshot.data!.data() as Map<String, dynamic>;

                  return Card(
                    margin: const EdgeInsets.all(8),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProviderProfilePage(
                              providerId: providerId,
                              providerData: providerData,
                              userData: userData,
                              serviceName: serviceName,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 30,
                                  backgroundImage: userData['avatarUrl'] != null
                                      ? NetworkImage(userData['avatarUrl'])
                                      : null,
                                  child: userData['avatarUrl'] == null
                                      ? Text(
                                          (userData['firstname'] ?? '?')[0].toUpperCase(),
                                          style: const TextStyle(fontSize: 24),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${userData['firstname']} ${userData['lastname']}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Zone: ${providerData['workingArea']}',
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      Text(
                                        'Tarif: ${providerData['rateRange']['min']} - ${providerData['rateRange']['max']} DT/h',
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (providerData['bio'] != null && providerData['bio'].toString().isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                'Bio:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[800],
                                ),
                              ),
                              Text(
                                providerData['bio'],
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.person),
                                  label: const Text('Voir profil'),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ProviderProfilePage(
                                          providerId: providerId,
                                          providerData: providerData,
                                          userData: userData,
                                          serviceName: serviceName,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.message),
                                  label: const Text('Contacter'),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ConversationServicePage(
                                          otherUserId: providerId,
                                          otherUserName: '${userData['firstname']} ${userData['lastname']}',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}