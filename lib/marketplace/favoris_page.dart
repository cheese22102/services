import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:plateforme_services/marketplace/details_post_page.dart';
import 'package:plateforme_services/widgets/zoom_product.dart';
import '../widgets/sidebar.dart';

class FavorisPage extends StatefulWidget {
  const FavorisPage({super.key});

  @override
  _FavorisPageState createState() => _FavorisPageState();
}

class _FavorisPageState extends State<FavorisPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _user = FirebaseAuth.instance.currentUser;
  String _searchQuery = '';

  Stream<List<DocumentSnapshot>> _getFavorites() {
    return _firestore
        .collection('users')
        .doc(_user?.uid)
        .collection('favoris')
        .snapshots()
        .asyncMap((favorites) async {
      List<Future<DocumentSnapshot>> futures = [];
      for (var fav in favorites.docs) {
        futures.add(_firestore.collection('marketplace').doc(fav.id).get());
      }
      return await Future.wait(futures);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const Sidebar(),
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Mes Favoris', style: TextStyle(fontWeight: FontWeight.bold)),
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
                hintText: 'Rechercher dans les favoris...',
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
            child: StreamBuilder<List<DocumentSnapshot>>(
              stream: _getFavorites(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final posts = snapshot.data!.where((post) {
                  final data = post.data() as Map<String, dynamic>;
                  return data['title'].toString().toLowerCase().contains(_searchQuery);
                }).toList();

                if (posts.isEmpty) {
                  return const Center(child: Text("Aucun favori trouvé"));
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