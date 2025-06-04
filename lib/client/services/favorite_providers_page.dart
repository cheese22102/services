import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart'; // Added
import 'package:go_router/go_router.dart';
import '../../front/app_colors.dart';
import '../../front/custom_app_bar.dart';
import '../../front/app_spacing.dart'; // Added
import '../../front/app_typography.dart'; // Added
import '../../front/marketplace_search.dart'; // Added for search bar consistency
import 'dart:async';

class FavoriteProvidersPage extends StatefulWidget {
  const FavoriteProvidersPage({super.key});

  @override
  State<FavoriteProvidersPage> createState() => _FavoriteProvidersPageState();
}

class _FavoriteProvidersPageState extends State<FavoriteProvidersPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _favoriteProviders = [];
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  Position? _currentPosition; // Added for location
  
  // Add a StreamSubscription to listen for changes
  StreamSubscription<QuerySnapshot>? _favoritesSubscription;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation(); // Fetch location on init
    _setupFavoritesListener();
  }

  @override
  void dispose() {
    _searchController.dispose();
    // Cancel the subscription when the widget is disposed
    _favoritesSubscription?.cancel();
    super.dispose();
  }
  
  // Set up a listener for changes to the favorites collection
  void _setupFavoritesListener() {
    if (currentUserId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final favoritesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('prestataires_favoris');
        
    _favoritesSubscription = favoritesRef.snapshots().listen((snapshot) {
      _loadFavoriteProviders();
    }, onError: (error) {
      print('Error listening to favorites: $error');
    });
    
    // Initial load
    _loadFavoriteProviders();
  }

  Future<void> _loadFavoriteProviders() async {
    if (currentUserId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Get user's favorite providers from the prestataires_favoris subcollection
      final favoritesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('prestataires_favoris')
          .get();

      if (favoritesSnapshot.docs.isEmpty) {
        setState(() {
          _isLoading = false;
          _favoriteProviders = [];
        });
        return;
      }

      // Fetch provider data for each favorite
      List<Map<String, dynamic>> providers = [];
      
      // Use Future.wait to load providers in parallel
      final futures = favoritesSnapshot.docs.map((doc) async {
        final providerId = doc.id;
        final serviceName = doc.data()['serviceName'] as String? ?? '';
        
        try {
          // Get provider data
          final providerDoc = await FirebaseFirestore.instance
              .collection('providers')
              .doc(providerId)
              .get();
              
          if (providerDoc.exists) {
            final providerData = providerDoc.data() ?? {};
            final userId = providerData['userId'] as String?;
            
            if (userId != null) {
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .get();
                  
              if (userDoc.exists) {
                final userData = userDoc.data() ?? {};
                
                // Get provider's services
                List<String> services = [];
                if (providerData.containsKey('services') && 
                    providerData['services'] is List) {
                  services = List<String>.from(providerData['services']);
                }
                
                // Get provider's rating from the new rating field
                double rating = 0.0;
                int reviewCount = 0;
                
                if (providerData.containsKey('rating')) {
                  rating = (providerData['rating'] as num?)?.toDouble() ?? 0.0;
                }
                if (providerData.containsKey('reviewCount')) {
                  reviewCount = (providerData['reviewCount'] as num?)?.toInt() ?? 0;
                }
                
                if (providerData.containsKey('ratings') && 
                    providerData['ratings'] is Map<String, dynamic>) {
                  final ratings = providerData['ratings'] as Map<String, dynamic>;
                  if (ratings.containsKey('overall')) {
                    rating = (ratings['overall'] as num?)?.toDouble() ?? 0.0;
                  }
                  if (ratings.containsKey('reviewCount')) {
                    reviewCount = (ratings['reviewCount'] as num?)?.toInt() ?? 0;
                  }
                }
                
                return {
                  'providerId': providerId,
                  'firstName': userData['firstname'] ?? '',
                  'lastName': userData['lastname'] ?? '',
                  'photoURL': userData['avatarUrl'] ?? '', // Changed to avatarUrl
                  'services': services,
                  'rating': rating,
                  'reviewCount': reviewCount,
                  'description': providerData['bio'] ?? 'Aucune description',
                  'serviceName': serviceName,
                  'exactLocation': providerData['exactLocation'], // Added exactLocation
                };
              }
            }
          }
        } catch (e) {
          print('Error loading provider $providerId: $e');
        }
        return null;
      }).toList();
      
      // Wait for all futures to complete and filter out null results
      final results = await Future.wait(futures);
      providers = results.whereType<Map<String, dynamic>>().toList();
      
      if (mounted) {
        setState(() {
          _favoriteProviders = providers;
          _isLoading = false;
        });
      }
      
    } catch (e) {
      print('Error loading favorite providers: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _currentPosition = null; // Explicitly set to null if service not enabled
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _currentPosition = null; // Explicitly set to null if permission denied
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _currentPosition = null; // Explicitly set to null if permission denied forever
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    } catch (e) {
      print('Error getting current location: $e');
      if (mounted) {
        setState(() {
          _currentPosition = null; // Set to null on error
        });
      }
    }
  }

  double _calculateDistance(GeoPoint providerLocation) {
    if (_currentPosition == null) return double.infinity;
    
    final double lat1 = _currentPosition!.latitude;
    final double lon1 = _currentPosition!.longitude;
    final double lat2 = providerLocation.latitude;
    final double lon2 = providerLocation.longitude;
    
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000; // Convert to km
  }

  List<Map<String, dynamic>> _getFilteredProviders() {
    if (_searchQuery.isEmpty) {
      return _favoriteProviders;
    }
    
    return _favoriteProviders.where((provider) {
      final name = '${provider['firstName']} ${provider['lastName']}'.toLowerCase();
      final services = (provider['services'] as List<String>?)
          ?.map((s) => s.toLowerCase())
          .join(' ') ?? '';
      
      return name.contains(_searchQuery.toLowerCase()) || 
             services.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightInputBackground, // Consistent background
      appBar: CustomAppBar(
        title: 'Prestataires favoris',
        showBackButton: true,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md), // Consistent padding
            child: MarketplaceSearch( // Use MarketplaceSearch
              controller: _searchController,
              hintText: 'Rechercher un prestataire...',
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
              onClear: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                });
              },
            ),
          ),
          
          // Provider list with RefreshIndicator
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadFavoriteProviders,
              color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                      ),
                    )
                  : _buildProvidersList(isDarkMode),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProvidersList(bool isDarkMode) {
    final filteredProviders = _getFilteredProviders();
    
    if (filteredProviders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: AppSpacing.xxxl, // Corrected from iconLarge * 2 (64.0)
              color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, // Use AppColors
            ),
            AppSpacing.verticalSpacing(AppSpacing.md), // Use AppSpacing
            Text(
              'Aucun prestataire favori',
              style: AppTypography.headlineSmall(context).copyWith( // Use AppTypography
                fontWeight: FontWeight.w500,
                color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, // Use AppColors
              ),
            ),
            AppSpacing.verticalSpacing(AppSpacing.xs), // Use AppSpacing
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding), // Use AppSpacing
              child: Text(
                'Ajoutez des prestataires à vos favoris pour les retrouver ici',
                style: AppTypography.bodyMedium(context).copyWith( // Use AppTypography
                  color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, // Use AppColors
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.screenPadding), // Use AppSpacing
      itemCount: filteredProviders.length,
      itemBuilder: (context, index) {
        final provider = filteredProviders[index];
        final providerId = provider['providerId'] as String;
        final firstName = provider['firstName'] as String;
        final lastName = provider['lastName'] as String;
        final photoURL = provider['photoURL'] as String;
        final services = provider['services'] as List<String>? ?? []; // Re-added services
        final rating = provider['rating'] as double;
        final reviewCount = provider['reviewCount'] as int;
        final description = provider['description'] as String;
        
        String distanceText = 'N/A';
        final locationData = provider['exactLocation'];
        if (_currentPosition != null && locationData != null && locationData['latitude'] != null && locationData['longitude'] != null) {
          final location = GeoPoint(locationData['latitude'], locationData['longitude']);
          final distance = _calculateDistance(location);
          distanceText = '${distance.toStringAsFixed(1)} km'; // Keep 1 decimal place for distance as in liste_prestataires
        }

        return _buildProviderCard(
          context,
          isDarkMode,
          providerId,
          '$firstName $lastName', // Combine name here
          photoURL,
          description,
          rating,
          reviewCount,
          distanceText,
          services, // Pass services
        );
      },
    );
  }

  Widget _buildProviderCard(
    BuildContext context,
    bool isDarkMode,
    String providerId,
    String name,
    String photoUrl,
    String bio,
    double rating,
    int reviewCount,
    String distanceText,
    List<String> services, // Added services
  ) {
    return Card(
      margin: EdgeInsets.only(bottom: AppSpacing.md), // Use AppSpacing
      elevation: 0, // Consistent with marketplace cards
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd), // Use AppSpacing
        side: BorderSide(
          color: isDarkMode ? AppColors.darkBorderColor.withOpacity(0.2) : AppColors.lightBorderColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      color: isDarkMode ? AppColors.darkCardBackground : AppColors.lightCardBackground, // Consistent with marketplace cards
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd), // Use AppSpacing
        onTap: () {
          context.push('/clientHome/provider-details/$providerId');
        },
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md), // Use AppSpacing
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: AppSpacing.xxl * 1.5, // Adjusted size (72.0)
                    height: AppSpacing.xxl * 1.5, // Adjusted size (72.0)
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd), // Use AppSpacing
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05), // Softer shadow
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd), // Use AppSpacing
                      child: photoUrl.isNotEmpty
                          ? Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                                child: Icon(
                                  Icons.person,
                                  size: AppSpacing.iconLg, // Use AppSpacing
                                  color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                                ),
                              ),
                            )
                          : Container(
                              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                              child: Icon(
                                Icons.person,
                                size: AppSpacing.iconLg, // Use AppSpacing
                                color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                              ),
                            ),
                    ),
                  ),
                  AppSpacing.horizontalSpacing(AppSpacing.md), // Use AppSpacing
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: AppTypography.h4(context).copyWith( // Use AppTypography
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        AppSpacing.verticalSpacing(AppSpacing.xxs), // Use AppSpacing
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              size: AppSpacing.iconXs, // Use AppSpacing
                              color: Colors.amber,
                            ),
                            AppSpacing.horizontalSpacing(AppSpacing.xxs), // Use AppSpacing
                            Text(
                              '${rating.toStringAsFixed(2)} (${reviewCount} avis)', // Formatted to 2 decimal places
                              style: AppTypography.labelSmall(context).copyWith( // Use AppTypography
                                color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                            AppSpacing.horizontalSpacing(AppSpacing.sm), // Use AppSpacing
                            Icon(
                              Icons.location_on_outlined, // Use outlined icon
                              size: AppSpacing.iconXs, // Use AppSpacing
                              color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                            ),
                            AppSpacing.horizontalSpacing(AppSpacing.xxs), // Use AppSpacing
                            Text(
                              distanceText,
                              style: AppTypography.labelSmall(context).copyWith( // Use AppTypography
                                color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                        AppSpacing.verticalSpacing(AppSpacing.xxs), // Added spacing
                        if (services.isNotEmpty) // Display services if available
                          Text(
                            'Services: ${services.join(', ')}',
                            style: AppTypography.labelSmall(context).copyWith(
                              color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              // Removed description
            ],
          ),
        ),
      ),
    );
  }
}
