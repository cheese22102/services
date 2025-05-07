import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../front/app_colors.dart';
import '../../front/custom_app_bar.dart';
import '../../front/custom_button.dart';
import '../../front/marketplace_card.dart';  // Changed from zoom_product to marketplace_card
import '../../front/marketplace_search.dart';
import '../../front/custom_bottom_nav.dart';

class FavorisPage extends StatefulWidget {
  const FavorisPage({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _FavorisPageState createState() => _FavorisPageState();
}

class _FavorisPageState extends State<FavorisPage> {
  final int _selectedIndex = 2;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _user = FirebaseAuth.instance.currentUser;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: const CustomAppBar(
        title: 'Mes Favoris',
        showBackButton: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: MarketplaceSearch(
              controller: _searchController,
              onClear: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
              hintText: 'Rechercher dans les favoris...',
            ),
          ),
          
          Expanded(
            child: StreamBuilder<List<DocumentSnapshot>>(
              stream: _getFavorites(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: isDarkMode ? Colors.white54 : Colors.black38,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Une erreur est survenue',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final posts = snapshot.data?.where((post) {
                  final data = post.data() as Map<String, dynamic>?;
                  if (data == null) return false;
                  return data['title'].toString().toLowerCase().contains(_searchQuery);
                }).toList() ?? [];

                if (posts.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen).withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.favorite_border,
                            size: 64,
                            color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          "Aucun favori trouvé",
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Ajoutez des articles à vos favoris\npour les retrouver ici",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: MediaQuery.of(context).size.width * 0.8, // 80% of screen width
                          child: CustomButton(
                            text: 'Explorer le marketplace',
                            onPressed: () => context.go('/clientHome/marketplace'),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Changed from GridView to match the marketplace page style
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 0.8,  // Match the aspect ratio from marketplace page
                  ),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    final data = post.data() as Map<String, dynamic>;
                    
                    // Extract data safely
                    final String title = data['title'] as String? ?? 'Sans titre';
                    final double price = (data['price'] is num) 
                        ? (data['price'] as num).toDouble() 
                        : 0.0;
                    final String location = data['location'] as String? ?? 'Emplacement inconnu';
                    final String condition = data['condition'] as String? ?? 'État inconnu';
                    
                    // Safely extract the image URL
                    String imageUrl = 'https://via.placeholder.com/300';
                    if (data['images'] is List && (data['images'] as List).isNotEmpty) {
                      final firstImage = (data['images'] as List).first;
                      if (firstImage is String) {
                        imageUrl = firstImage;
                      }
                    }

                    // Use MarketplaceCard instead of ZoomProduct
                    return MarketplaceCard(
                      id: post.id,
                      title: title,
                      price: price,
                      location: location,
                      imageUrl: imageUrl,
                      condition: condition,
                      onTap: () {
                        context.push(
                          '/clientHome/marketplace/details/${post.id}',
                          extra: post,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _selectedIndex,
      ),
    );
  }
}
