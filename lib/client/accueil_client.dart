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
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              onPressed: () => context.push('/clientHome/request-service'),  // Fix the path to match route definition
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Demander un service'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('services')
                  .orderBy('name')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Une erreur est survenue'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final services = snapshot.data!.docs;

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
                    
                    // Also fix the service card navigation
                    return InkWell(
                      onTap: () => context.push('/clientHome/services/${service['name']}'),
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
          ),
        ],
      ),
      // Replace the current bottomNavigationBar with a proper BottomNavigationBar
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0, // Home page is selected
        onTap: (index) {
          if (index == 0) {
            // Already on home page, do nothing
          } else if (index == 1) {
            // Navigate to My Requests page
            context.go('/clientHome/my-requests');
          } else if (index == 2) {
            // Navigate to Marketplace
            context.go('/clientHome/marketplace');
          }
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
    );
  }
}