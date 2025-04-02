import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/zoom_product.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/bottom_navbar.dart';


class MesProduitsPage extends StatefulWidget {
  const MesProduitsPage({super.key});

  @override
  State<MesProduitsPage> createState() => _MesProduitsPageState();
}


class _MesProduitsPageState extends State<MesProduitsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final user = FirebaseAuth.instance.currentUser;
  // Add this variable
  final int _selectedIndex = 3; // My Products tab is index 3

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // Changed to 3 for the new tab
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (user == null) {
      return const Center(child: Text('Vous devez être connecté'));
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Mes Produits',
          style: TextStyle(
            fontWeight: FontWeight.bold,
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
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          labelColor: Theme.of(context).colorScheme.primary,
          unselectedLabelColor: isDark ? Colors.white60 : Colors.black54,
          tabs: const [
            Tab(text: 'Posts Publiés'),
            Tab(text: 'En Attente'),
            Tab(text: 'Refusés'), // Added the third tab
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.05),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            _PostsList(type: PostListType.published),
            _PostsList(type: PostListType.pending),
            _RejectedPostsList(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/clientHome/marketplace/add'),
        icon: const Icon(Icons.add),
        label: const Text('Nouveau Produit'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      // Add this at the bottom of the Scaffold
      bottomNavigationBar: MarketplaceBottomNav(
        selectedIndex: _selectedIndex,
      ),
    );
  }
}

class _PostsList extends StatelessWidget {
  final PostListType type;

  const _PostsList({required this.type});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isValidated = type == PostListType.published;

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
          return Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
          );
        }

        final posts = snapshot.data?.docs ?? [];

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
                    isValidated ? Icons.inventory_2_outlined : Icons.pending_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  isValidated ? "Aucun produit publié" : "Aucun produit en attente",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isValidated 
                      ? "Commencez à vendre en ajoutant\nvotre premier produit"
                      : "Vos produits en attente de validation\napparaîtront ici",
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

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            final data = post.data() as Map<String, dynamic>;
            final images = List<String>.from(data['images'] ?? []);
            final imageUrl = images.isNotEmpty ? images[0] : '';

            return CustomCard(
              title: '',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      AspectRatio(
                        aspectRatio: 16 / 9,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: GestureDetector(
                            onTap: () => context.push(
                              '/clientHome/marketplace/details/${post.id}',
                              extra: post,
                            ),
                            child: Hero(
                              tag: 'product_${post.id}',
                              child: ZoomProduct(
                                imageUrl: imageUrl,
                                title: data['title'] ?? '',
                                price: data['price'] != null 
                                    ? double.tryParse(data['price'].toString()) ?? 0 
                                    : 0,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isValidated 
                                ? Colors.green.withOpacity(0.9)
                                : Colors.orange.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isValidated ? Icons.check_circle : Icons.pending,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isValidated ? 'Publié' : 'En attente',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
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
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 16),
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
                            CustomButton(
                              onPressed: () => context.push(
                                '/clientHome/marketplace/details/${post.id}',
                                extra: post,
                              ),
                              text: 'Voir détails',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

enum PostListType { published, pending, rejected }

class _RejectedPostsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('marketplace_rejections')
          .where('userId', isEqualTo: user?.uid)
          .orderBy('rejectedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: Theme.of(context).colorScheme.primary,
            ),
          );
        }

        final rejectedPosts = snapshot.data?.docs ?? [];

        if (rejectedPosts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.block_outlined,
                    size: 64,
                    color: Colors.red[700],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Aucune publication refusée",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Les publications refusées\napparaîtront ici",
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

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rejectedPosts.length,
          itemBuilder: (context, index) {
            final rejection = rejectedPosts[index].data() as Map<String, dynamic>;

            return CustomCard(
              title: '',
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.cancel_outlined,
                          color: Colors.red[700],
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Publication Refusée',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      rejection['postTitle'] ?? 'Sans titre',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.red[200]!,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Raison du refus:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red[700],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            rejection['rejectionReason'] ?? 'Aucune raison fournie',
                            style: TextStyle(
                              color: Colors.red[900],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Refusé le ${_formatDate(rejection['rejectedAt'])}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Date inconnue';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} à ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}