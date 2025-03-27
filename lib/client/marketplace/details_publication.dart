import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_dialog.dart';
import '../../widgets/custom_button.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PostDetailsPage extends StatefulWidget {
  final DocumentSnapshot post;
  
  const PostDetailsPage({super.key, required this.post});

  @override
  State<PostDetailsPage> createState() => _PostDetailsPageState();
}

class _PostDetailsPageState extends State<PostDetailsPage> {
  late Map<String, dynamic> postData;
  bool _isFullScreen = false;

  // Ajoutons un contrôleur de page pour maintenir l'état du carrousel
  late PageController _pageController;
  
  // Initialize the ValueNotifier directly instead of using late
  final ValueNotifier<int> _imageIndexNotifier = ValueNotifier<int>(0);
  
  @override
  void initState() {
    super.initState();
    // Add error handling for data extraction
    try {
      postData = widget.post.data() as Map<String, dynamic>? ?? {};
      print("Post data loaded: ${postData['title']}"); // Debug print
    } catch (e) {
      print("Error loading post data: $e");
      postData = {};
    }
    
    // Initialiser le contrôleur de page
    _pageController = PageController(initialPage: 0);
    // No need to initialize _imageIndexNotifier here since we're doing it directly above
  }
  
  @override
  void dispose() {
    // Libérer les ressources du contrôleur
    _pageController.dispose();
    _imageIndexNotifier.dispose();
    super.dispose();
  }
  
  Future<String> _getUserName(String userId) async {
    try {
      var userDoc =
          await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists) {
        var userData = userDoc.data();
        if (userData != null &&
            userData['firstname'] != null &&
            userData['lastname'] != null) {
          return "${userData['firstname']} ${userData['lastname']}";
        }
      }
      return "Unknown User";
    } catch (e) {
      print("Error loading user info: $e");
      return "Error loading user info";
    }
  }

  Future<void> _toggleFavorite() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final favoritesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('favoris')
        .doc(widget.post.id);

    final doc = await favoritesRef.get();
    if (doc.exists) {
      await favoritesRef.delete();
    } else {
      await favoritesRef.set({'timestamp': FieldValue.serverTimestamp()});
    }
  }
  
  // Méthode pour afficher l'image en plein écran avec le même contrôleur
  void _showFullScreenImage(List<String> imageUrls, int initialIndex) {
    // Synchroniser la position du carrousel
    if (_pageController.hasClients) {
      _pageController.jumpToPage(initialIndex);
    }
    
    setState(() {
      _isFullScreen = true;
    });
  }

  void _exitFullScreen() {
    setState(() {
      _isFullScreen = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    String postUserId = postData['userId'] ?? '';
    String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    
    // Get image URLs
    List<String> imageUrls = [];
    if (postData['images'] != null) {
      try {
        if (postData['images'] is List) {
          imageUrls = List<String>.from(postData['images']);
        } else {
          print("Images is not a List: ${postData['images'].runtimeType}");
        }
      } catch (e) {
        print("Error processing images: $e");
      }
    }

    // Si en mode plein écran, afficher la visionneuse d'images en plein écran
    if (_isFullScreen && imageUrls.isNotEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Colors.black38,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white),
            ),
            onPressed: _exitFullScreen,
          ),
        ),
        body: GestureDetector(
          onTap: () {
            // Toggle visibility of controls if needed
          },
          child: PageView.builder(
            controller: _pageController, // Utiliser le même contrôleur
            itemCount: imageUrls.length,
            onPageChanged: (index) {
              // Use the ValueNotifier here too instead of setState
              _imageIndexNotifier.value = index;
            },
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: Hero(
                    tag: 'image_$index', // Utiliser l'index comme tag pour éviter les conflits
                    child: CachedNetworkImage( // Utiliser CachedNetworkImage pour optimiser le chargement
                      imageUrl: imageUrls[index],
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                      errorWidget: (context, url, error) => const Center(
                        child: Icon(Icons.error_outline, size: 50, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        // Le reste du code pour la barre de navigation reste inchangé
      );
    }

    // Normal view with new design
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
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
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(currentUserId)
                .collection('favoris')
                .doc(widget.post.id)
                .snapshots(),
            builder: (context, snapshot) {
              final isFavorite = snapshot.data?.exists ?? false;
              return Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black38 : Colors.white38,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.red : (isDark ? Colors.white : Colors.black),
                  ),
                  onPressed: _toggleFavorite,
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<String>(
        future: _getUserName(postData['userId'] ?? ''),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text("Error loading user information"));
          }
          String userName = snapshot.data ?? "Unknown User";

          return CustomScrollView(
            slivers: [
              // Image carousel as SliverAppBar for parallax effect
              SliverAppBar(
                automaticallyImplyLeading: false,
                expandedHeight: size.height * 0.4,
                pinned: true,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                flexibleSpace: FlexibleSpaceBar(
                  background: imageUrls.isNotEmpty
                      ? Stack(
                          children: [
                            // Main image carousel
                            PageView.builder(
                              controller: _pageController, // Utiliser le même contrôleur
                              itemCount: imageUrls.length,
                              onPageChanged: (index) {
                                // Update the notifier instead of using setState
                                _imageIndexNotifier.value = index;
                                // Still need to update _currentImageIndex for fullscreen mode
                              },
                              itemBuilder: (context, index) {
                                return GestureDetector(
                                  onTap: () => _showFullScreenImage(imageUrls, index),
                                  child: Hero(
                                    tag: 'image_$index', // Utiliser l'index comme tag
                                    child: CachedNetworkImage( // Utiliser CachedNetworkImage
                                      imageUrl: imageUrls[index],
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Center(
                                        child: CircularProgressIndicator(
                                          color: isDark ? Colors.white70 : Colors.black45,
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Center(
                                        child: Icon(
                                          Icons.error_outline,
                                          size: 50,
                                          color: isDark ? Colors.white : Colors.black54,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            
                            // Le reste du code pour l'overlay et les indicateurs reste inchangé
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              height: 100,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.7),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            
                            // Dots indicator
                            if (imageUrls.length > 1)
                              Positioned(
                                bottom: 20,
                                left: 0,
                                right: 0,
                                child: ValueListenableBuilder<int>(
                                  valueListenable: _imageIndexNotifier,
                                  builder: (context, currentIndex, _) {
                                    return Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: List.generate(
                                        imageUrls.length,
                                        (index) => AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          margin: const EdgeInsets.symmetric(horizontal: 4),
                                          width: currentIndex == index ? 12 : 8,
                                          height: currentIndex == index ? 12 : 8,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: currentIndex == index
                                                ? Colors.white
                                                : Colors.white.withOpacity(0.5),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        )
                      : Container(
                          color: isDark ? Colors.grey[800] : Colors.grey[200],
                          child: Center(
                            child: Icon(
                              Icons.image_not_supported_outlined,
                              size: 80,
                              color: isDark ? Colors.grey[600] : Colors.grey[400],
                            ),
                          ),
                        ),
                ),
              ),
              
              // Content
              SliverToBoxAdapter(
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title and Price Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                postData['title'] ?? 'No Title',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: isDark 
                                    ? [const Color(0xFF62B6CB), const Color(0xFF1A5F7A)]
                                    : [const Color(0xFF1A5F7A), const Color(0xFF0F3F54)],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF1A5F7A).withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Text(
                                "${postData['price']} TND",
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Product State with icon
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[800] : Colors.grey[200],
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 18,
                                color: isDark ? Colors.white70 : Colors.black87,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "État: ${postData['etat'] ?? 'Unknown'}",
                                style: TextStyle(
                                  color: isDark ? Colors.white70 : Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Description Section with card style
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[850] : Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.description_outlined,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Description",
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 24),
                              Text(
                                postData['description'] ?? "No description provided.",
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Seller Information Card
                                        CustomCard(
                                          title: "Informations du vendeur",
                                          child: Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 25,
                                                backgroundColor: Theme.of(context).colorScheme.primary,
                                                child: const Icon(Icons.person, color: Colors.white, size: 30),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      userName,
                                                      style: const TextStyle(
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              if (currentUserId != postUserId)
                                                CustomButton(
                                                  width: 120,
                                                  onPressed: () {
                                                    context.push(
                                                      '/clientHome/chat/conversation/${postData['userId']}',
                                                      extra: {
                                                        'postId': widget.post.id,
                                                        'otherUserName': userName,
                                                      },
                                                    );
                                                  },
                                                  text: "Contacter",
                                                ),
                                            ],
                                          ),
                                        ),
                                        
                                        // Add some space at the bottom for floating action buttons
                                        SizedBox(height: currentUserId == postUserId ? 80 : 20),
                                      ],
                                    ),
                                  ),
          ),
                              ),
                            ],
                          );
                        },
                      ),
                      floatingActionButton: currentUserId == postUserId
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  FloatingActionButton(
                                    heroTag: "edit",
                                    onPressed: _navigateToEdit,
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    child: const Icon(Icons.edit),
                                  ),
                                  const SizedBox(width: 16),
                                  FloatingActionButton(
                                    heroTag: "delete",
                                    onPressed: () => _showDeleteConfirmation(context),
                                    backgroundColor: Theme.of(context).colorScheme.error,
                                    child: const Icon(Icons.delete),
                                  ),
                                ],
                              ),
                            )
                          : null,
                    );
                  }

                  // Update delete confirmation to use CustomDialog
                  Future<void> _showDeleteConfirmation(BuildContext context) async {
                    CustomDialog.showWithActions(
                      context,
                      "Confirmer la suppression",
                      "Êtes-vous sûr de vouloir supprimer cette publication ? Cette action est irréversible.",
                      [
                        TextButton(
                          onPressed: () => context.pop(),
                          child: const Text("Annuler"),
                        ),
                        TextButton(
                          onPressed: () async {
                            context.pop();
                            await FirebaseFirestore.instance
                                .collection('marketplace')
                                .doc(widget.post.id)
                                .delete();
                            if (mounted) {
                              context.go('/clientHome/marketplace');
                              CustomDialog.show(
                                context,
                                "Succès",
                                "Publication supprimée avec succès",
                              );
                            }
                          },
                          child: Text(
                            "Supprimer",
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                          ),
                        ),
                      ],
                    );
                  }

                  Future<void> _navigateToEdit() async {
                    final result = await context.push('/clientHome/marketplace/edit/${widget.post.id}', extra: widget.post);
                    if (result != null) {
                      setState(() => postData = result as Map<String, dynamic>);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Publication mise à jour")),
                        );
                      }
                    }
                  }
                }