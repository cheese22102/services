import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import './details_post_page.dart';
import '../widgets/zoom_product.dart';
import '../widgets/sidebar.dart';
import '../widgets/zoom_product.dart'; // Le widget ZoomProduct

class MesProduitsPage extends StatefulWidget {
  const MesProduitsPage({super.key});

  @override
  State<MesProduitsPage> createState() => _MesProduitsPageState();
}

class _MesProduitsPageState extends State<MesProduitsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Center(child: Text('Vous devez être connecté'));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Produits'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Posts Publiés'),
            Tab(text: 'En Attente'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PostsList(isValidated: true),
          _PostsList(isValidated: false),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/ajout-marketplace'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _PostsList extends StatelessWidget {
  final bool isValidated;

  const _PostsList({required this.isValidated});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('marketplace')
          .where('userId', isEqualTo: user?.uid)
          .where('isValidated', isEqualTo: isValidated)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = snapshot.data?.docs ?? [];

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isValidated ? Icons.check_circle : Icons.pending,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  isValidated 
                      ? "Aucun post publié" 
                      : "Aucun post en attente de validation",
                  style: TextStyle(
                    fontSize: 18,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            final data = post.data() as Map<String, dynamic>;

            return PostCard(
              post: post,
              isValidated: isValidated,
            );
          },
        );
      },
    );
  }
}

class PostCard extends StatelessWidget {
  final QueryDocumentSnapshot post;
  final bool isValidated;

  const PostCard({
    super.key,
    required this.post,
    required this.isValidated,
  });

  @override
  Widget build(BuildContext context) {
    final data = post.data() as Map<String, dynamic>;
    final List<dynamic> images = data['images'] ?? [];
    final String imageUrl = images.isNotEmpty ? images[0] : "";

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ZoomProduct(
                        imageUrl: imageUrl,
                        title: data['title'] ?? '',
                        price: data['price'] != null 
                            ? double.tryParse(data['price'].toString()) ?? 0 
                            : 0,
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / 
                                  loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.error),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isValidated ? Colors.green : Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isValidated ? 'Publié' : 'En attente',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Product details section
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data['title'] ?? '',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  data['description'] ?? '',
                  style: Theme.of(context).textTheme.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${data['price']} DT',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PostDetailsPage(post: post),
                          ),
                        );
                      },
                      child: const Text('Voir détails'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}