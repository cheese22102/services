import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';

class ProviderListPage extends StatefulWidget {
  const ProviderListPage({super.key});

  @override
  State<ProviderListPage> createState() => _ProviderListPageState();
}

class _ProviderListPageState extends State<ProviderListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Validation des Prestataires'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'), // Update navigation to use GoRouter
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Rechercher par email ou téléphone...',
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
                  .collection('providers')
                  .where('status', isEqualTo: 'pending')  // Only show pending requests
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Une erreur est survenue'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Aucune demande en attente'));
                }

                final requests = snapshot.data!.docs;
                
                // Filter by search query if needed
                final filteredRequests = _searchQuery.isEmpty
                    ? requests
                    : requests.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return data['professionalEmail'].toString().toLowerCase().contains(_searchQuery) ||
                               data['professionalPhone'].toString().toLowerCase().contains(_searchQuery);
                      }).toList();

                return ListView.builder(
                  itemCount: filteredRequests.length,
                  itemBuilder: (context, index) {
                    final requestData = filteredRequests[index].data() as Map<String, dynamic>;
                    final requestId = filteredRequests[index].id;
                    
                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: ListTile(
                        title: Text('Demande de ${requestData['professionalEmail'] ?? 'Inconnu'}'),
                        subtitle: Text('Téléphone: ${requestData['professionalPhone'] ?? 'Non spécifié'}'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        // Add the onTap handler to navigate to the provider details page
                        onTap: () {
                          context.push('/admin/providers/$requestId');
                        },
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
}