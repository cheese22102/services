import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../chat/conversation_service_page.dart';

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
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundImage: userData['avatarUrl'] != null
                            ? NetworkImage(userData['avatarUrl'])
                            : null,
                        child: userData['avatarUrl'] == null
                            ? Text(
                                (userData['firstname'] ?? '?')[0].toUpperCase(),
                              )
                            : null,
                      ),
                      title: Text('${userData['firstname']} ${userData['lastname']}'),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Zone: ${providerData['workingArea']}'),
                          Text(
                            'Tarif: ${providerData['rateRange']['min']} - ${providerData['rateRange']['max']} DT/h'
                          ),
                          Text('Bio: ${providerData['bio']}'),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.message),
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