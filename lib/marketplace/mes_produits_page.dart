import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:plateforme_services/marketplace/details_post_page.dart';
import 'package:plateforme_services/widgets/zoom_product.dart';
import '../widgets/sidebar.dart';

class MesProduitsPage extends StatefulWidget {
  const MesProduitsPage({super.key});

  @override
  _MesProduitsPageState createState() => _MesProduitsPageState();
}

class _MesProduitsPageState extends State<MesProduitsPage> {
  final User? _user = FirebaseAuth.instance.currentUser;
  String _searchQuery = '';

  Stream<QuerySnapshot> _getUserPosts() {
    return FirebaseFirestore.instance
        .collection('marketplace')
        .where('userId', isEqualTo: _user?.uid)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const Sidebar(),
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Mes Produits', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                hintText: 'Rechercher mes produits...',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getUserPosts(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final posts = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['title'].toString().toLowerCase().contains(_searchQuery);
                }).toList();

                if (posts.isEmpty) {
                  return const Center(child: Text("Aucun produit trouvé"));
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    final data = post.data() as Map<String, dynamic>;
                    final images = List<String>.from(data['images'] ?? []);

                    return InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PostDetailsPage(post: post),
                        ),
                      ),
                      child: ZoomProduct(
                        imageUrl: images.isNotEmpty ? images[0] : '',
                        title: data['title'] ?? 'Sans titre',
                        price: data['price']?.toDouble() ?? 0,
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