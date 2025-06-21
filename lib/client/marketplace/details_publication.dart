import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../front/app_colors.dart';
import '../../front/custom_app_bar.dart';
import '../../front/custom_button.dart';
import '../../front/custom_snackbar.dart';
import '../../front/custom_dialog.dart';
import '../../utils/image_gallery_utils.dart';
import '../../front/app_spacing.dart';
import '../../front/app_typography.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';


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

  // Map related variables
  LatLng? _postLatLng;
  GoogleMapController? _mapController;
  bool _isGeocoding = true;
  String? _geocodingError;
  
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
    _mapController?.dispose(); // Dispose map controller
    super.dispose();
  }
  
  Future<void> _loadPostData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _isGeocoding = true; // Start geocoding
      _geocodingError = null;
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

      // Perform geocoding after post data is loaded
      await _geocodeLocation(postData['location']);

    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = "Erreur lors du chargement: $e";
      });
    }
  }

  Future<void> _geocodeLocation(String? locationString) async {
    if (locationString == null || locationString.isEmpty) {
      setState(() {
        _isGeocoding = false;
        _geocodingError = "Emplacement non spécifié.";
      });
      return;
    }

    try {
      List<Location> locations = await locationFromAddress(locationString);
      if (locations.isNotEmpty) {
        setState(() {
          _postLatLng = LatLng(locations.first.latitude, locations.first.longitude);
          _isGeocoding = false;
        });
      } else {
        setState(() {
          _isGeocoding = false;
          _geocodingError = "Impossible de trouver les coordonnées pour cet emplacement.";
        });
      }
    } catch (e) {
      setState(() {
        _isGeocoding = false;
        _geocodingError = "Erreur de géocodage: $e";
      });
    }
  }

  Future<void> _openInGoogleMaps() async {
    if (_postLatLng == null) {
      CustomSnackbar.show(
        context: context,
        message: "Coordonnées de l'emplacement non disponibles.",
        isError: true,
      );
      return;
    }

    final String googleMapsUrl = 
        'https://www.google.com/maps/search/?api=1&query=${_postLatLng!.latitude},${_postLatLng!.longitude}';
    
    final Uri uri = Uri.parse(googleMapsUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      CustomSnackbar.show(
        context: context,
        message: "Impossible d'ouvrir Google Maps.",
        isError: true,
      );
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
      
      // Navigate to chat screen
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
        backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightInputBackground, // Matched accueil_marketplace
        appBar: CustomAppBar(title: 'Détails de l\'annonce'), // backgroundColor removed
        body: Center(child: CircularProgressIndicator(color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)), // Use AppColors
      );
    }
    
    if (_hasError) {
      return Scaffold(
        backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightInputBackground, // Matched accueil_marketplace
        appBar: CustomAppBar(title: 'Détails de l\'annonce'), // backgroundColor removed
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: AppSpacing.iconXl, // Use AppSpacing
                color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint, // Use AppColors
              ),
              SizedBox(height: AppSpacing.md), // Use AppSpacing
              Text(
                'Erreur',
                style: AppTypography.h4(context).copyWith( // Use AppTypography
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, // Use AppColors
                ),
              ),
              SizedBox(height: AppSpacing.sm), // Use AppSpacing
              Text(
                _errorMessage,
                style: AppTypography.bodyMedium(context).copyWith( // Use AppTypography
                  color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint, // Use AppColors
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.lg), // Use AppSpacing
              CustomButton(
                text: 'Retour',
                onPressed: () => context.pop(),
                width: 150, // Keep fixed width for now
                height: AppSpacing.buttonMedium, // Use AppSpacing
                backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen, // Use AppColors
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
                        placeholder: (context, url) => Center(
                          child: CircularProgressIndicator(color: AppColors.primaryGreen), // Use AppColors
                        ),
                        errorWidget: (context, url, error) => Icon(
                          Icons.error,
                          color: AppColors.errorLightRed, // Use AppColors
                          size: AppSpacing.iconXl, // Use AppSpacing
                        ),
                      ),
                    ),
                  );
                },
              ),
              // Close button
              Positioned(
                top: AppSpacing.xxl, // Use AppSpacing
                right: AppSpacing.md, // Use AppSpacing
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.white, size: AppSpacing.iconLg), // Use AppSpacing
                  onPressed: _toggleFullScreen,
                ),
              ),
              // Image counter
              Positioned(
                bottom: AppSpacing.md, // Use AppSpacing
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
                          width: AppSpacing.sm, // Use AppSpacing
                          height: AppSpacing.sm, // Use AppSpacing
                          margin: EdgeInsets.symmetric(horizontal: AppSpacing.xs), // Use AppSpacing
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
      backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightInputBackground, // Matched accueil_marketplace
      appBar: CustomAppBar(
        title: 'Détails de l\'annonce',
        // backgroundColor removed
        actions: [
          IconButton(
            icon: Icon(
              Icons.share,
              color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, // Use AppColors
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
                  child: ClipRRect( // Added ClipRRect for consistent border radius
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd), // Use AppSpacing
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
                color: isDarkMode ? AppColors.darkCardBackground : AppColors.lightCardBackground, // Use AppColors
                child: Center(
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    size: AppSpacing.iconXl, // Use AppSpacing
                    color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint, // Use AppColors
                  ),
                ),
              ),
            
            // Product details
            Padding(
              padding: EdgeInsets.all(AppSpacing.lg), // Use AppSpacing
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and price
                  Text(
                    title,
                    style: AppTypography.h3(context).copyWith( // Use AppTypography
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, // Use AppColors
                    ),
                  ),
                  SizedBox(height: AppSpacing.sm), // Use AppSpacing
                  Text(
                    '$price DT',
                    style: AppTypography.h2(context).copyWith( // Use AppTypography
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen, // Use AppColors
                    ),
                  ),
                  SizedBox(height: AppSpacing.lg), // Use AppSpacing
                  
                  // Condition and category badges
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs), // Use AppSpacing
                        decoration: BoxDecoration(
                          color: condition == 'Neuf'
                              ? Colors.green.withOpacity(0.2)
                              : Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(AppSpacing.radiusLg), // Use AppSpacing
                        ),
                        child: Text(
                          condition,
                          style: AppTypography.labelSmall(context).copyWith( // Use AppTypography
                            fontWeight: FontWeight.w500,
                            color: condition == 'Neuf'
                                ? Colors.green.shade800
                                : Colors.orange.shade800,
                          ),
                        ),
                      ),
                      SizedBox(width: AppSpacing.sm), // Use AppSpacing
                      FutureBuilder<DocumentSnapshot>(
                        future: FirebaseFirestore.instance
                            .collection('services')
                            .doc(categoryId)
                            .get(),
                        builder: (context, snapshot) {
                          String categoryName = 'Catégorie inconnue';
                          
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return SizedBox(
                              width: AppSpacing.md, // Use AppSpacing
                              height: AppSpacing.md, // Use AppSpacing
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen, // Use AppColors
                              ),
                            );
                          }
                          
                          if (snapshot.hasData && snapshot.data!.exists) {
                            final serviceData = snapshot.data!.data() as Map<String, dynamic>?;
                            if (serviceData != null && serviceData.containsKey('name')) {
                              categoryName = serviceData['name'];
                            }
                          }
                          
                          return Container(
                            padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs), // Use AppSpacing
                            decoration: BoxDecoration(
                              color: isDarkMode 
                                  ? AppColors.darkCardBackground 
                                  : AppColors.lightCardBackground, // Use AppColors
                              borderRadius: BorderRadius.circular(AppSpacing.radiusLg), // Use AppSpacing
                            ),
                            child: Text(
                              categoryName,
                              style: AppTypography.labelSmall(context).copyWith( // Use AppTypography
                                fontWeight: FontWeight.w500,
                                color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, // Use AppColors
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.lg), // Use AppSpacing
                  
                  // Description section
                  Text(
                    'Description',
                    style: AppTypography.h4(context).copyWith( // Use AppTypography
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, // Use AppColors
                    ),
                  ),
                  SizedBox(height: AppSpacing.sm), // Use AppSpacing
                  Container(
                    padding: EdgeInsets.all(AppSpacing.md), // Use AppSpacing
                    decoration: BoxDecoration(
                      color: isDarkMode ? AppColors.darkCardBackground : AppColors.lightCardBackground, // Use AppColors
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd), // Use AppSpacing
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
                      style: AppTypography.bodyMedium(context).copyWith( // Use AppTypography
                        height: 1.5,
                        color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextPrimary, // Use AppColors
                      ),
                    ),
                  ),
                  // Seller info section
                  FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(postData['userId'])
                        .get(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator(color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)); // Use AppColors
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
                            style: AppTypography.h4(context).copyWith( // Use AppTypography
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, // Use AppColors
                            ),
                          ),
                          SizedBox(height: AppSpacing.sm), // Use AppSpacing
                          Container(
                            padding: EdgeInsets.all(AppSpacing.md), // Use AppSpacing
                            decoration: BoxDecoration(
                              color: isDarkMode ? AppColors.darkCardBackground : AppColors.lightCardBackground, // Use AppColors
                              borderRadius: BorderRadius.circular(AppSpacing.radiusMd), // Use AppSpacing
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start, // Align content to start
                              children: [
                                Row(
                                  children: [
                                    // Try a different approach for the avatar
                                    sellerPhotoUrl != null && sellerPhotoUrl.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(AppSpacing.radiusXl), // Use AppSpacing
                                        child: CachedNetworkImage(
                                          imageUrl: sellerPhotoUrl,
                                          width: AppSpacing.xxl, // Use AppSpacing
                                          height: AppSpacing.xxl, // Use AppSpacing
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(
                                            width: AppSpacing.xxl, // Use AppSpacing
                                            height: AppSpacing.xxl, // Use AppSpacing
                                            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                                            child: Center(child: CircularProgressIndicator(color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)), // Use AppColors
                                          ),
                                          errorWidget: (context, url, error) {
                                            return Container(
                                              width: AppSpacing.xxl, // Use AppSpacing
                                              height: AppSpacing.xxl, // Use AppSpacing
                                              decoration: BoxDecoration(
                                                color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                                                borderRadius: BorderRadius.circular(AppSpacing.radiusXl), // Use AppSpacing
                                              ),
                                              child: Icon(
                                                Icons.person,
                                                size: AppSpacing.iconLg, // Use AppSpacing
                                                color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint, // Use AppColors
                                              ),
                                            );
                                          },
                                        ),
                                      )
                                    : Container(
                                        width: AppSpacing.xxl, // Use AppSpacing
                                        height: AppSpacing.xxl, // Use AppSpacing
                                        decoration: BoxDecoration(
                                          color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                                          borderRadius: BorderRadius.circular(AppSpacing.radiusXl), // Use AppSpacing
                                        ),
                                        child: Icon(
                                          Icons.person,
                                          size: AppSpacing.iconLg, // Use AppSpacing
                                          color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint, // Use AppColors
                                        ),
                                      ),
                                    SizedBox(width: AppSpacing.md), // Use AppSpacing
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$firstName $lastName',
                                            style: AppTypography.bodyLarge(context).copyWith( // Use AppTypography
                                              fontWeight: FontWeight.w600,
                                              color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, // Use AppColors
                                            ),
                                          ),
                                          Text(
                                            'Membre depuis ${createdAt?.year ?? 'inconnu'}',
                                            style: AppTypography.bodySmall(context).copyWith( // Use AppTypography
                                              color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, // Use AppColors
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: AppSpacing.md), // Use AppSpacing
                                if (phoneNumber.isNotEmpty)
                                  SizedBox(
                                    width: double.infinity,
                                    child: CustomButton( // Use CustomButton
                                      text: 'Appeler le vendeur',
                                      onPressed: () {
                                        final Uri phoneUri = Uri(
                                          scheme: 'tel',
                                          path: phoneNumber,
                                        );
                                        launchUrl(phoneUri);
                                      },
                                      icon: const Icon(Icons.phone), // Pass Icon widget
                                      height: AppSpacing.buttonMedium, // Use AppSpacing
                                      backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen, // Use AppColors
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  SizedBox(height: AppSpacing.lg), // Add spacing after the seller section

                  // Map Section (moved here)
                  Text(
                    'Emplacement',
                    style: AppTypography.h4(context).copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  _isGeocoding
                      ? Center(
                          child: CircularProgressIndicator(color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen),
                        )
                      : _geocodingError != null
                          ? Center(
                              child: Text(
                                _geocodingError!,
                                style: AppTypography.bodyMedium(context).copyWith(
                                  color: AppColors.errorLightRed,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : _postLatLng != null
                              ? Container(
                                  height: 200, // Fixed height for the map
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                    border: Border.all(color: isDarkMode ? AppColors.darkBorder : AppColors.lightBorder),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                    child: GoogleMap(
                                      initialCameraPosition: CameraPosition(
                                        target: _postLatLng!,
                                        zoom: 15,
                                      ),
                                      onMapCreated: (controller) {
                                        _mapController = controller;
                                      },
                                      markers: {
                                        Marker(
                                          markerId: const MarkerId('postLocation'),
                                          position: _postLatLng!,
                                          infoWindow: InfoWindow(title: postData['location'] ?? 'Emplacement'),
                                        ),
                                      },
                                      zoomControlsEnabled: false,
                                      scrollGesturesEnabled: false,
                                      rotateGesturesEnabled: false,
                                      tiltGesturesEnabled: false,
                                      onTap: (_) => _openInGoogleMaps(), // Open in Google Maps on tap
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    'Emplacement non disponible.',
                                    style: AppTypography.bodyMedium(context).copyWith(
                                      color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint,
                                    ),
                                  ),
                                ),
                  
                  SizedBox(height: AppSpacing.xxl), // Space for bottom buttons, adjusted
                ],
              ),
            ),
          ],
        ),
      ),
      bottomSheet: Container(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md), // Use AppSpacing
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey.shade900 : Colors.white, // Match AppBar/BottomNav
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
                        height: AppSpacing.buttonMedium, // Use AppSpacing
                        backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen, // Use AppColors (replaced accentBlue)
                      ),
                    ),
                    SizedBox(width: AppSpacing.md), // Use AppSpacing
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
                        height: AppSpacing.buttonMedium, // Use AppSpacing
                        backgroundColor: AppColors.errorLightRed, // Use AppColors
                      ),
                    ),
                  ],
                )
              // Other users viewing the post - show favorite and contact buttons
              : Row(
                  children: [
                    // Contact button (now first)
                    Expanded(
                      child: CustomButton(
                        text: 'Contacter le vendeur',
                        onPressed: _contactSeller,
                        height: AppSpacing.buttonMedium, // Use AppSpacing
                        backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen, // Use AppColors
                      ),
                    ),
                    SizedBox(width: AppSpacing.md), // Use AppSpacing
                    // Favorite button (now second)
                    Container(
                      width: AppSpacing.buttonMedium, // Use AppSpacing for width
                      height: AppSpacing.buttonMedium, // Use AppSpacing for height
                      decoration: BoxDecoration(
                        color: isDarkMode ? AppColors.darkCardBackground : AppColors.lightCardBackground, // Use AppColors
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd), // Use AppSpacing
                      ),
                      child: _isCheckingFavorite
                          ? Center(
                              child: SizedBox(
                                width: AppSpacing.iconMd, // Use AppSpacing
                                height: AppSpacing.iconMd, // Use AppSpacing
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen, // Use AppColors
                                ),
                              ),
                            )
                          : IconButton(
                              icon: Icon(
                                _isFavorite ? Icons.favorite : Icons.favorite_border,
                                color: _isFavorite
                                    ? Colors.red // Favorite color is now red
                                    : (isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary), 
                              ),
                              onPressed: _toggleFavorite,
                            ),
                    ),
                  ],
                )
        ),
      ),
    );
  }
}
