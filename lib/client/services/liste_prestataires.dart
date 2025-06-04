import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../front/app_colors.dart';
import '../../front/app_spacing.dart'; // Added AppSpacing
import '../../front/app_typography.dart'; // Added AppTypography
import '../../front/custom_app_bar.dart';
import '../../front/marketplace_search.dart'; // For search bar consistency

class ServiceProvidersPage extends StatefulWidget {
  final String serviceName;

  const ServiceProvidersPage({
    super.key,
    required this.serviceName,
  });

  @override
  State<ServiceProvidersPage> createState() => _ServiceProvidersPageState();
}

class _ServiceProvidersPageState extends State<ServiceProvidersPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'rating'; 
  bool _isAscending = true;
  Position? _currentPosition;
  bool _isLoading = true;
  List<Map<String, dynamic>> _allProviders = []; // Stores all fetched providers with user data
  List<Map<String, dynamic>> _filteredAndSortedProviders = []; // The list to display

  // Infinite scrolling related variables
  final ScrollController _scrollController = ScrollController();
  DocumentSnapshot? _lastDocument;
  bool _hasMore = true;
  bool _isFetchingMore = false;
  final int _pageSize = 10; // Number of providers to fetch per page

  @override
  void initState() {
    super.initState();
    _loadInitialProviders(); // Start fetching and processing providers
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent && _hasMore && !_isFetchingMore) {
      _loadMoreProviders();
    }
  }

  Future<void> _loadInitialProviders() async {
    setState(() {
      _isLoading = true;
      _allProviders.clear();
      _filteredAndSortedProviders.clear();
      _lastDocument = null;
      _hasMore = true;
    });

    await _getCurrentLocation(); // Fetch current location first

    try {
      Query query = FirebaseFirestore.instance
          .collection('providers')
          .where('status', isEqualTo: 'approved')
          .where('services', arrayContains: widget.serviceName);

      if (_sortBy == 'rating') {
        query = query.orderBy('rating', descending: !_isAscending);
      }
      // For distance, we fetch all and sort client-side, so no Firestore orderBy for distance

      final providerSnapshot = await query.limit(_pageSize).get();

      List<Map<String, dynamic>> tempProviders = [];
      for (var doc in providerSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final providerId = doc.id;
        final userId = data['userId'] ?? 'Unknown';

        final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        String name = 'Prestataire';
        String photoUrl = '';
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          name = '${userData['firstname'] ?? ''} ${userData['lastname'] ?? ''}'.trim();
          name = name.isEmpty ? 'Prestataire' : name;
          photoUrl = userData['avatarUrl'] ?? '';
        }

        tempProviders.add({
          'providerId': providerId,
          'name': name,
          'photoUrl': photoUrl,
          'bio': data['bio'] ?? 'Aucune description disponible',
          'rating': (data['rating'] as num?)?.toDouble() ?? 0.0,
          'reviewCount': (data['reviewCount'] as num?)?.toInt() ?? 0,
          'exactLocation': data['exactLocation'],
        });
      }

      if (mounted) {
        setState(() {
          _allProviders = tempProviders;
          _lastDocument = providerSnapshot.docs.isNotEmpty ? providerSnapshot.docs.last : null;
          _hasMore = providerSnapshot.docs.length == _pageSize;
          _applyFiltersAndSort();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading initial providers: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement des prestataires: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMoreProviders() async {
    if (!_hasMore || _isFetchingMore || _sortBy == 'distance') return; // No infinite scroll for distance sort

    setState(() => _isFetchingMore = true);

    try {
      Query query = FirebaseFirestore.instance
          .collection('providers')
          .where('status', isEqualTo: 'approved')
          .where('services', arrayContains: widget.serviceName);

      if (_sortBy == 'rating') {
        query = query.orderBy('rating', descending: !_isAscending);
      }

      final providerSnapshot = await query
          .startAfterDocument(_lastDocument!)
          .limit(_pageSize)
          .get();

      List<Map<String, dynamic>> newProviders = [];
      for (var doc in providerSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final providerId = doc.id;
        final userId = data['userId'] ?? 'Unknown';

        final userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
        String name = 'Prestataire';
        String photoUrl = '';
        if (userDoc.exists) {
          final userData = userDoc.data()!;
          name = '${userData['firstname'] ?? ''} ${userData['lastname'] ?? ''}'.trim();
          name = name.isEmpty ? 'Prestataire' : name;
          photoUrl = userData['avatarUrl'] ?? '';
        }

        newProviders.add({
          'providerId': providerId,
          'name': name,
          'photoUrl': photoUrl,
          'bio': data['bio'] ?? 'Aucune description disponible',
          'rating': (data['rating'] as num?)?.toDouble() ?? 0.0,
          'reviewCount': (data['reviewCount'] as num?)?.toInt() ?? 0,
          'exactLocation': data['exactLocation'],
        });
      }

      if (mounted) {
        setState(() {
          _allProviders.addAll(newProviders);
          _lastDocument = providerSnapshot.docs.isNotEmpty ? providerSnapshot.docs.last : null;
          _hasMore = providerSnapshot.docs.length == _pageSize;
          _applyFiltersAndSort(); // Re-apply filters and sort with new data
          _isFetchingMore = false;
        });
      }
    } catch (e) {
      print('Error loading more providers: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement de plus de prestataires: $e')),
        );
        setState(() => _isFetchingMore = false);
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

  void _applyFiltersAndSort() {
    List<Map<String, dynamic>> temp = List.from(_allProviders);

    // If sorting by distance and location is not available, clear the list
    if (_sortBy == 'distance' && _currentPosition == null) {
      temp.clear();
      if (mounted) {
        setState(() {
          _filteredAndSortedProviders = temp;
        });
      }
      return; // Exit early as no providers can be shown for distance sort without location
    }

    // 1. Apply search query filter
    if (_searchQuery.isNotEmpty) {
      temp = temp.where((provider) {
        final name = (provider['name']?.toString() ?? '').toLowerCase();
        final bio = (provider['bio']?.toString() ?? '').toLowerCase();
        return name.contains(_searchQuery) || bio.contains(_searchQuery);
      }).toList();
    }

    // 2. Apply distance filter (less than 50km if location is available)
    if (_currentPosition != null) {
      temp = temp.where((provider) {
        final locationData = provider['exactLocation'];
        if (locationData == null || locationData['latitude'] == null || locationData['longitude'] == null) {
          return false; // Exclude if no exact location
        }
        final location = GeoPoint(locationData['latitude'], locationData['longitude']);
        final distance = _calculateDistance(location);
        return distance <= 50;
      }).toList();
    }

    // 3. Apply sorting
    temp.sort((a, b) {
      if (_sortBy == 'rating') {
        final ratingA = a['rating'] as double;
        final ratingB = b['rating'] as double;
        final reviewCountA = a['reviewCount'] as int;
        final reviewCountB = b['reviewCount'] as int;

        // Primary sort by rating (descending for better ratings)
        int compare = ratingB.compareTo(ratingA);
        if (compare == 0) {
          // If ratings are equal, sort by review count (descending for more reviews)
          compare = reviewCountB.compareTo(reviewCountA);
        }
        return _isAscending ? -compare : compare; // Invert if ascending is desired for rating
      } else if (_sortBy == 'distance') {
        // Calculate distance for sorting
        final locationA = a['exactLocation'];
        final locationB = b['exactLocation'];

        double distanceA = double.infinity;
        if (locationA != null && locationA['latitude'] != null && locationA['longitude'] != null) {
          distanceA = _calculateDistance(GeoPoint(locationA['latitude'], locationA['longitude']));
        }

        double distanceB = double.infinity;
        if (locationB != null && locationB['latitude'] != null && locationB['longitude'] != null) {
          distanceB = _calculateDistance(GeoPoint(locationB['latitude'], locationB['longitude']));
        }
        return _isAscending ? distanceA.compareTo(distanceB) : distanceB.compareTo(distanceA);
      }
      return 0; // No sort
    });

    if (mounted) {
      setState(() {
        _filteredAndSortedProviders = temp;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightInputBackground,
      appBar: CustomAppBar( // Removed explicit color overrides to use defaults from CustomAppBar
        title: widget.serviceName,
        showBackButton: true,
      ),
      body: Column(
        children: [
          // Search and filter section
          Padding(
            padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
            child: Column(
              children: [
                // Search bar - using MarketplaceSearch for consistency
                MarketplaceSearch(
                  controller: _searchController,
                  hintText: 'Rechercher un prestataire...',
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                      _loadInitialProviders(); // Re-load initial providers with new search query
                    });
                  },
                  onClear: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _loadInitialProviders(); // Re-load initial providers on clear
                    });
                  },
                ),
                SizedBox(height: AppSpacing.md), // Use AppSpacing
                // Sort options
                Row(
                  children: [
                    Text(
                      'Trier par:',
                      style: AppTypography.bodyMedium(context).copyWith( // Use AppTypography
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    SizedBox(width: AppSpacing.sm), // Use AppSpacing
                    _buildSortChip('Note', 'rating', isDarkMode),
                    SizedBox(width: AppSpacing.sm), // Use AppSpacing
                    _buildSortChip('Distance', 'distance', isDarkMode),
                    const Spacer(),
                    // Order toggle
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isAscending = !_isAscending;
                          _loadInitialProviders(); // Re-load initial providers with new sort order
                        });
                      },
                      child: Container(
                        padding: EdgeInsets.all(AppSpacing.sm), // Use AppSpacing
                        decoration: BoxDecoration(
                          color: isDarkMode ? AppColors.darkInputBackground : AppColors.lightCardBackground, // Consistent with MarketplaceSearch
                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd), // Use AppSpacing
                          border: Border.all(
                            color: isDarkMode ? AppColors.darkBorderColor.withOpacity(0.3) : AppColors.lightBorderColor.withOpacity(0.3),
                          ),
                        ),
                        child: Icon(
                          _isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                          size: AppSpacing.iconSm, // Use AppSpacing
                          color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Providers list
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                    ),
                  )
                : _filteredAndSortedProviders.isEmpty && !_hasMore && !_isFetchingMore
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchQuery.isNotEmpty
                                  ? Icons.search_off
                                  : (_currentPosition == null ? Icons.location_off_outlined : Icons.person_search_outlined),
                              size: AppSpacing.iconXl,
                              color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint,
                            ),
                            SizedBox(height: AppSpacing.md),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Aucun résultat trouvé'
                                  : (_sortBy == 'distance' && _currentPosition == null
                                      ? 'Localisation requise pour le tri par distance'
                                      : 'Aucun prestataire trouvé'),
                              style: AppTypography.h3(context).copyWith( // Increased font size
                                fontWeight: FontWeight.w600, // Made bolder
                                color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, // More prominent color
                              ),
                            ),
                            SizedBox(height: AppSpacing.xs),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'Essayez avec d\'autres mots-clés.'
                                  : (_sortBy == 'distance' && _currentPosition == null
                                      ? 'Veuillez activer les services de localisation pour trier par distance.'
                                      : 'Il n\'y a pas encore de prestataires pour ce service ou dans votre zone.'),
                              style: AppTypography.bodyLarge(context).copyWith( // Increased font size
                                color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_currentPosition == null) ...[
                              SizedBox(height: AppSpacing.md),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  await Geolocator.openLocationSettings();
                                  // After opening settings, try to reload providers
                                  _loadInitialProviders();
                                },
                                icon: Icon(Icons.settings_outlined, color: Colors.white),
                                label: Text(
                                  'Activer la localisation',
                                  style: AppTypography.button(context).copyWith(color: Colors.white),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                                  ),
                                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                                ),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController, // Assign scroll controller
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.lg), // Use AppSpacing
                        itemCount: _filteredAndSortedProviders.length + (_hasMore && _sortBy == 'rating' ? 1 : 0), // Add 1 for loading indicator if more data and sorting by rating
                        itemBuilder: (context, index) {
                          if (index == _filteredAndSortedProviders.length) {
                            // This is the loading indicator at the end of the list
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                                ),
                              ),
                            );
                          }

                          final provider = _filteredAndSortedProviders[index];
                          
                          String distanceText = 'N/A';
                          if (_currentPosition != null && provider['exactLocation'] != null && provider['exactLocation']['latitude'] != null && provider['exactLocation']['longitude'] != null) {
                            final location = GeoPoint(provider['exactLocation']['latitude'], provider['exactLocation']['longitude']);
                            final distance = _calculateDistance(location);
                            distanceText = '${distance.toStringAsFixed(1)} km';
                          }
                          
                          return _buildProviderCard(
                            context,
                            isDarkMode,
                            provider['providerId'],
                            provider['name'],
                            provider['photoUrl'],
                            provider['bio'],
                            provider['rating'],
                            provider['reviewCount'],
                            distanceText,
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: SizedBox(
        width: 70, 
        height: 70, 
        child: Container( 
          decoration: BoxDecoration(
            shape: BoxShape.circle, 
            color: AppColors.primaryGreen, 
            boxShadow: [ 
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: FloatingActionButton(
            onPressed: () {
              context.push('/clientHome/my-reservations');
            },
            backgroundColor: Colors.transparent, 
            elevation: 0, 
            shape: const CircleBorder(), 
            child: Icon(
              Icons.calendar_today_outlined, 
              color: Colors.white,
              size: 32, // Match chatbot FAB icon size
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSortChip(String label, String value, bool isDarkMode) {
    final isSelected = _sortBy == value;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _sortBy = value;
          // Default to ascending for distance, descending for rating when a new sort chip is selected
          _isAscending = (value == 'distance'); 
          _loadInitialProviders(); // Re-load initial providers with new sort criteria
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm), // Use AppSpacing
        decoration: BoxDecoration(
          color: isSelected
              ? (isDarkMode ? AppColors.primaryGreen.withOpacity(0.2) : AppColors.primaryDarkGreen.withOpacity(0.1))
              : (isDarkMode ? AppColors.darkInputBackground : AppColors.lightCardBackground), // Consistent with MarketplaceSearch
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg), // Use AppSpacing
          border: Border.all(
            color: isSelected
                ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                : (isDarkMode ? AppColors.darkBorderColor.withOpacity(0.3) : AppColors.lightBorderColor.withOpacity(0.3)),
          ),
        ),
        child: Text(
          label,
          style: AppTypography.labelMedium(context).copyWith( // Use AppTypography
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected
                ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                : (isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ),
        ),
      ),
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
          context.push('/clientHome/provider-details/$providerId', extra: widget.serviceName);
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
                    width: AppSpacing.xxl * 1.5, // Adjusted size
                    height: AppSpacing.xxl * 1.5, // Adjusted size
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
                  SizedBox(width: AppSpacing.md), // Use AppSpacing
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
                        SizedBox(height: AppSpacing.xxs), // Use AppSpacing
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              size: AppSpacing.iconXs, // Use AppSpacing
                              color: Colors.amber,
                            ),
                            SizedBox(width: AppSpacing.xxs), // Use AppSpacing
                            Text(
                              '${rating.toStringAsFixed(1)} (${reviewCount} avis)', // More descriptive
                              style: AppTypography.labelSmall(context).copyWith( // Use AppTypography
                                color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                            SizedBox(width: AppSpacing.sm), // Use AppSpacing
                            Icon(
                              Icons.location_on_outlined, // Use outlined icon
                              size: AppSpacing.iconXs, // Use AppSpacing
                              color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                            ),
                            SizedBox(width: AppSpacing.xxs), // Use AppSpacing
                            Text(
                              distanceText,
                              style: AppTypography.labelSmall(context).copyWith( // Use AppTypography
                                color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
