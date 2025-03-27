// Remove unused imports
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../utils/auth_helper.dart';
import '../../widgets/sidebar.dart';
import 'package:go_router/go_router.dart';

class ClientHomePage extends StatefulWidget {
  const ClientHomePage({super.key});

  @override
  State<ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<ClientHomePage> {
  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    if (!mounted) return;
    await AuthHelper.checkUserRole(context, 'client');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const Sidebar(),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        title: const Text('Services Disponibles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_rounded),
            onPressed: () => context.push('/clientHome/notifications'),
          ),
          // Remove the shopping cart icon button from app bar
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('services')
            .snapshots(),
        builder: (context, snapshot) {
          // Add debug print
          print('Services data: ${snapshot.data?.docs.length ?? 0} items');
          
          if (snapshot.hasError) {
            print('Error fetching services: ${snapshot.error}');
            return const Center(child: Text('Une erreur est survenue'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final services = snapshot.data?.docs ?? [];
          
          if (services.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.engineering, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Aucun service disponible',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: services.length,
            itemBuilder: (context, index) {
              final service = services[index].data() as Map<String, dynamic>;
              
              return InkWell(
                onTap: () => context.push('/clientHome/services/${service['name']}'), // Ajout du préfixe clientHome
                child: Card(
                  elevation: 4,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      service['imageUrl'] != null
                          ? Image.network(
                              service['imageUrl'],
                              height: 48,
                              width: 48,
                              fit: BoxFit.cover,
                            )
                          : const Icon(
                              Icons.home_repair_service,
                              size: 48,
                            ),
                      const SizedBox(height: 8),
                      Text(
                        service['name'],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      // Modified bottom navigation bar
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
          onPressed: () => context.go('/clientHome/marketplace'), // Déjà corrigé
          icon: const Icon(Icons.shopping_cart),
          label: const Text("Marketplace"),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ),
    );
  }
}