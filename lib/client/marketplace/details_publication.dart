import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../front/app_colors.dart';
import '../../front/custom_app_bar.dart';
import '../../front/custom_button.dart';
import '../../front/custom_snackbar.dart';
import '../../front/custom_dialog.dart';
import '../../utils/image_gallery_utils.dart';


class PostDetailsPage extends StatefulWidget {
  final String postId;
  
  const PostDetailsPage({Key? key, required this.postId}) : super(key: key);

  @override
  State<PostDetailsPage> createState() => _PostDetailsPageState();
}

class _PostDetailsPageState extends State<PostDetailsPage> {
  bool _isFullScreen = false;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  Map<String, dynamic> postData = {};
  DocumentSnapshot? post;
  bool _isFavorite = false;
  bool _isCheckingFavorite = true;
  
  // Page controller for image carousel
  late PageController _pageController;
  
  // Track current image index
  final ValueNotifier<int> _imageIndexNotifier = ValueNotifier<int>(0);
  
  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _loadPostData();
    _checkIfFavorite(); // Add this line
  }

  // Add this method
  Future<void> _checkIfFavorite() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() => _isCheckingFavorite = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('favoris')
          .doc(widget.postId)
          .get();

      if (mounted) {
        setState(() {
          _isFavorite = doc.exists;
          _isCheckingFavorite = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCheckingFavorite = false);
      }
    }
  }

  // Add this method
  Future<void> _toggleFavorite() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      CustomSnackbar.show(
        context: context,
        message: "Vous devez être connecté pour ajouter aux favoris",
        isError: true,
      );
      return;
    }

    setState(() => _isCheckingFavorite = true);

    try {
      final favorisRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('favoris')
          .doc(widget.postId);

      if (_isFavorite) {
        await favorisRef.delete();
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: "Retiré des favoris",
            isError: false,
          );
        }
      } else {
        await favorisRef.set({
          'addedAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          CustomSnackbar.show(
            context: context,
            message: "Ajouté aux favoris",
            isError: false,
          );
        }
      }

      setState(() {
        _isFavorite = !_isFavorite;
        _isCheckingFavorite = false;
      });
    } catch (e) {
      setState(() => _isCheckingFavorite = false);
      if (mounted) {
        CustomSnackbar.show(
          context: context,
          message: "Erreur lors de la modification des favoris",
          isError: true,
        );
      }
    }
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    _imageIndexNotifier.dispose();
    super.dispose();
  }
  
  Future<void> _loadPostData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('marketplace')
          .doc(widget.postId)
          .get();
      
      if (!docSnapshot.exists) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = "Cette publication n'existe plus";
        });
        return;
      }
      
      setState(() {
        post = docSnapshot;
        postData = docSnapshot.data() as Map<String, dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = "Erreur lors du chargement: $e";
      });
    }
  }

  void _toggleFullScreen() {
    setState(() {
      _isFullScreen = !_isFullScreen;
    });
  }

     Future<void> _contactSeller() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      CustomSnackbar.show(
        context: context,
        message: "Vous devez être connecté pour contacter le vendeur",
        isError: true,
      );
      return;
    }

    if (currentUser.uid == postData['userId']) {
      CustomSnackbar.show(
        context: context,
        message: "Vous ne pouvez pas contacter votre propre annonce",
        isError: true,
      );
      return;
    }

    // Show loading indicator
    setState(() => _isLoading = true);

    try {
      // Get seller name for the chat
      String sellerName = 'Vendeur';
      final sellerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(postData['userId'])
          .get();
      
      if (sellerDoc.exists) {
        final sellerData = sellerDoc.data() as Map<String, dynamic>;
        sellerName = '${sellerData['firstname'] ?? ''} ${sellerData['lastname'] ?? ''}'.trim();
        sellerName = sellerName.trim().isNotEmpty ? sellerName : 'Vendeur';
      }
      
      // Navigate to chat screen - no need to pass postId anymore
      if (mounted) {
        setState(() => _isLoading = false);
        context.push('/clientHome/marketplace/chat/conversation/${postData['userId']}', extra: {
          'otherUserName': sellerName,
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomSnackbar.show(
          context: context,
          message: "Erreur: $e",
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: const CustomAppBar(title: 'Détails de l\'annonce'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_hasError) {
      return Scaffold(
        backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: const CustomAppBar(title: 'Détails de l\'annonce'),
        body: Center(
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
                'Erreur',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white54 : Colors.black45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              CustomButton(
                text: 'Retour',
                onPressed: () => context.pop(),
                width: 150,
              ),
            ],
          ),
        ),
      );
    }
    
    // Extract post data
    final List<String> images = List<String>.from(postData['images'] ?? []);
    final String title = postData['title'] ?? 'Sans titre';
    final double price = (postData['price'] is num) 
        ? (postData['price'] as num).toDouble() 
        : 0.0;
    final String description = postData['description'] ?? 'Aucune description';
    final String condition = postData['condition'] ?? 'État inconnu';
    final String categoryId = postData['category'] ?? '';
    
    // Full screen image view
    if (_isFullScreen && images.isNotEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _toggleFullScreen,
          child: Stack(
            children: [
              PageView.builder(
                controller: _pageController,
                itemCount: images.length,
                onPageChanged: (index) {
                  _imageIndexNotifier.value = index;
                },
                itemBuilder: (context, index) {
                  return Center(
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 3.0,
                      child: CachedNetworkImage(
                        imageUrl: images[index],
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.error,
                          color: Colors.white,
                          size: 50,
                        ),
                      ),
                    ),
                  );
                },
              ),
              // Close button
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: _toggleFullScreen,
                ),
              ),
              // Image counter
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
                        images.length,
                        (index) => Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
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
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: CustomAppBar(
        title: 'Détails de l\'annonce',
        actions: [
          IconButton(
            icon: Icon(
              Icons.share,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            onPressed: () {
              // Share functionality
              CustomSnackbar.show(
                context: context,
                message: "Fonctionnalité de partage à venir",
                isError: false,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Adaptable image gallery based on number of images
            if (images.isNotEmpty)
              GestureDetector(
                onTap: _toggleFullScreen,
                child: Container(
                  // Adjust height based on number of images
                  height: images.length <= 2 ? 250 : 
                         images.length <= 4 ? 350 : 
                         400, // More height for 5+ images
                  width: double.infinity,
                  child: ClipRect(
                    child: ImageGalleryUtils.buildImageGallery(
                      context,
                      images,
                      isDarkMode: isDarkMode,
                      fixedHeight: images.length <= 2 ? 250 : 
                                  images.length <= 4 ? 350 : 
                                  400, // Match the container height
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 250,
                width: double.infinity,
                color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                child: Center(
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    size: 64,
                    color: isDarkMode ? Colors.white38 : Colors.black26,
                  ),
                ),
              ),
            
            // Product details
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and price
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$price DT',
                    style: GoogleFonts.poppins(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Location and date
                  // Around line 547, look for a Row that might contain text or widgets that are too wide
                  // Replace that Row with this version that uses Expanded to prevent overflow
                  
              
                  
                  // Replace it with:
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 20,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          postData['location'] ?? 'Emplacement non spécifié',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Condition and category badges
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: condition == 'Neuf'
                              ? Colors.green.withOpacity(0.2)
                              : Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          condition,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: condition == 'Neuf'
                                ? Colors.green.shade800
                                : Colors.orange.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('services')
                            .doc(categoryId)
                            .get(),
                        builder: (context, snapshot) {
                          String categoryName = 'Catégorie inconnue';
                          
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            );
                          }
                          
                          if (snapshot.hasData && snapshot.data!.exists) {
                            final serviceData = snapshot.data!.data() as Map<String, dynamic>?;
                            if (serviceData != null && serviceData.containsKey('name')) {
                              categoryName = serviceData['name'];
                            }
                          }
                          
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDarkMode 
                                  ? Colors.grey.shade800 
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              categoryName,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isDarkMode ? Colors.white70 : Colors.black54,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Description section
                  Text(
                    'Description',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey.shade900 : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      description,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        height: 1.5,
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Seller info section
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(postData['userId'])
                        .get(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      String firstName = 'Utilisateur';
                      String lastName = '';
                      String? sellerPhotoUrl;
                      String phoneNumber = '';
                      DateTime? createdAt;
                      
                      if (snapshot.hasData && snapshot.data!.exists) {
                        final userData = snapshot.data!.data() as Map<String, dynamic>?;
                        if (userData != null) {
                          firstName = userData['firstname'] ?? 'Utilisateur';
                          lastName = userData['lastname'] ?? '';
                          sellerPhotoUrl = userData['avatarUrl'];
                          phoneNumber = userData['phone'] ?? '';
                          createdAt = (userData['createdAt'] as Timestamp?)?.toDate();
                          
                
                        }
                      }
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vendeur',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.grey.shade900 : Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    // Try a different approach for the avatar
                                    sellerPhotoUrl != null && sellerPhotoUrl.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(30),
                                        child: CachedNetworkImage(
                                          imageUrl: sellerPhotoUrl,
                                          width: 60,
                                          height: 60,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(
                                            width: 60,
                                            height: 60,
                                            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                                            child: const Center(child: CircularProgressIndicator()),
                                          ),
                                          errorWidget: (context, url, error) {
                                            return Container(
                                              width: 60,
                                              height: 60,
                                              decoration: BoxDecoration(
                                                color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                                                borderRadius: BorderRadius.circular(30),
                                              ),
                                              child: Icon(
                                                Icons.person,
                                                size: 30,
                                                color: isDarkMode ? Colors.white54 : Colors.black38,
                                              ),
                                            );
                                          },
                                        ),
                                      )
                                    : Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(30),
                                        ),
                                        child: Icon(
                                          Icons.person,
                                          size: 30,
                                          color: isDarkMode ? Colors.white54 : Colors.black38,
                                        ),
                                      ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$firstName $lastName',
                                            style: GoogleFonts.poppins(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: isDarkMode ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                          Text(
                                            'Membre depuis ${createdAt?.year ?? 'inconnu'}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              color: isDarkMode ? Colors.white70 : Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                if (phoneNumber.isNotEmpty)
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        final Uri phoneUri = Uri(
                                          scheme: 'tel',
                                          path: phoneNumber,
                                        );
                                        launchUrl(phoneUri);
                                      },
                                      icon: const Icon(Icons.phone),
                                      label: Text(
                                        'Appeler le vendeur',
                                        style: GoogleFonts.poppins(),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  
                  const SizedBox(height: 100), // Space for bottom buttons
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey.shade900 : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: FirebaseAuth.instance.currentUser?.uid == postData['userId']
              // User is viewing their own post - show edit and delete buttons
              ? Row(
                  children: [
                    // Edit button
                    Expanded(
                      child: CustomButton(
                        text: 'Modifier',
                        onPressed: () {
                          // Navigate to edit page with post data
                          context.push('/clientHome/marketplace/edit/${widget.postId}', extra: post);
                        },
                        height: 50,
                        backgroundColor: isDarkMode ? Colors.blue.shade700 : Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Delete button
                    Expanded(
                      child: CustomButton(
                        text: 'Supprimer',
                        onPressed: () async {
                          // Show confirmation dialog before deleting
                          final bool? confirmed = await CustomDialog.showConfirmation(
                            context: context,
                            title: 'Supprimer l\'annonce',
                            message: 'Êtes-vous sûr de vouloir supprimer cette annonce ? Cette action est irréversible.',
                            confirmText: 'Supprimer',
                            cancelText: 'Annuler',
                          );
                          
                          // Only proceed if user confirmed
                          if (confirmed == true) {
                            try {
                              // Delete post from Firestore
                              await FirebaseFirestore.instance
                                  .collection('marketplace')
                                  .doc(widget.postId)
                                  .delete();
                              
                              if (mounted) {
                                // Navigate to marketplace home
                                context.go('/clientHome/marketplace');
                              }
                            } catch (e) {
                              if (mounted) {
                                CustomSnackbar.show(
                                  context: context,
                                  message: "Erreur lors de la suppression: $e",
                                  isError: true,
                                );
                              }
                            }
                          }
                        },
                       
                      ),
                    ),
                  ],
                )
              // Other users viewing the post - show favorite and contact buttons
              : Row(
                  children: [
                    // Favorite button
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: _isCheckingFavorite
                          ? const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          : IconButton(
                              icon: Icon(
                                _isFavorite ? Icons.favorite : Icons.favorite_border,
                                color: _isFavorite
                                    ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                                    : (isDarkMode ? Colors.white70 : Colors.black54),
                              ),
                              onPressed: _toggleFavorite,
                            ),
                    ),
                    const SizedBox(width: 16),
                    // Contact button
                    Expanded(
                      child: CustomButton(
                        text: 'Contacter le vendeur',
                        onPressed: _contactSeller,
                        height: 50,
                      ),
                    ),
                  ],
                )
        ),
      ),
    );
  }
}
