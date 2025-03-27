import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/zoom_product.dart';
import '../../widgets/bottom_navbar.dart';
import '../../widgets/search_bar.dart';


class FavorisPage extends StatefulWidget {
  const FavorisPage({super.key});

  @override
  _FavorisPageState createState() => _FavorisPageState();
}

class _FavorisPageState extends State<FavorisPage> {
  // Add this property
  final int _selectedIndex = 1;  // Set to 1 since Favoris is the second tab

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
      List<DocumentSnapshot> validPosts = [];
      for (var fav in favorites.docs) {
        final postDoc = await _firestore.collection('marketplace').doc(fav.id).get();
        if (postDoc.exists && postDoc.data() != null) {
          validPosts.add(postDoc);
        } else {
          // Optionally: Remove the invalid reference from favorites
          await _firestore
              .collection('users')
              .doc(_user?.uid)
              .collection('favoris')
              .doc(fav.id)
              .delete();
        }
      }
      return validPosts;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Mes Favoris',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.black38 : Colors.white38,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back),
          ),
          onPressed: () => context.go('/clientHome/marketplace'),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Replace the old search bar with CustomSearchBar
          CustomSearchBar(
            onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            hintText: 'Rechercher dans les favoris...',
          ),
          
          Expanded(
            child: StreamBuilder<List<DocumentSnapshot>>(
              stream: _getFavorites(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  );
                }

                final posts = snapshot.data!.where((post) {
                  final data = post.data() as Map<String, dynamic>?;
                  if (data == null) return false;
                  return data['title'].toString().toLowerCase().contains(_searchQuery);
                }).toList();

                if (posts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.favorite_border,
                            size: 64,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "Aucun favori trouvé",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Ajoutez des articles à vos favoris\npour les retrouver ici",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    final data = post.data() as Map<String, dynamic>;
                    final images = List<String>.from(data['images'] ?? []);
                    final imageUrl = images.isNotEmpty ? images[0] : '';

                    return InkWell(
                      onTap: () => context.push(
                        '/clientHome/marketplace/details/${post.id}',
                        extra: post,
                      ),
                      child: ZoomProduct(
                        imageUrl: imageUrl,
                        title: data['title'] ?? 'Sans titre',
                        price: data['price'] != null 
                            ? double.tryParse(data['price'].toString()) ?? 0 
                            : 0,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      // Add the bottom navigation bar
      bottomNavigationBar: MarketplaceBottomNav(
        selectedIndex: _selectedIndex,
      ),
    );
  }
}
