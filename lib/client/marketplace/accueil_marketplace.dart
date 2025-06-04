import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../front/app_colors.dart';
import '../../front/app_spacing.dart';
import '../../front/app_typography.dart';
import '../../front/marketplace_card.dart';
import '../../front/marketplace_filter.dart'; 
import '../../front/marketplace_search.dart'; 
import '../../front/custom_app_bar.dart';
import '../../front/custom_bottom_nav.dart';
import '../../front/sidebar.dart';

class MarketplacePage extends StatefulWidget {
  const MarketplacePage({super.key});

  @override
  _MarketplacePageState createState() => _MarketplacePageState();
}

class _MarketplacePageState extends State<MarketplacePage> {
  // Navigation index
  int _selectedIndex = 2; // Assuming marketplace is the 3rd tab

  // Search and filter variables
  String _searchQuery = '';
  String _filterCondition = 'All';
  bool _sortByDateAsc = false; // Default to newest first
  final bool _isAscending = false; // Add this line for price sorting
  RangeValues _priceRange = const RangeValues(0, 10000);
  String? _filterLocation = 'Tous'; // New state variable for location filter
  bool _isFilterVisible = false;
  
  // Scroll controller for hiding search bar
  final ScrollController _scrollController = ScrollController();

  // Categories list - initialized once
  List<Map<String, dynamic>> _categories = [
    {'id': 'all', 'name': 'Tous', 'icon': Icons.apps, 'isSelected': true, 'imageUrl': ''},
  ];

  // Controller for search field
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
    
    // Add scroll listener to hide/show search bar
    _scrollController.addListener(_scrollListener);
    
    // Load services from Firestore
    _loadServices();
  }
  
  // Load services from Firestore
  Future<void> _loadServices() async {
    try {
      final servicesSnapshot = await FirebaseFirestore.instance
          .collection('services')
          .orderBy('name')
          .get();
      
      final List<Map<String, dynamic>> loadedServices = [
        {'id': 'all', 'name': 'Tous', 'icon': Icons.apps, 'isSelected': true, 'imageUrl': ''},
      ];
      
      for (var doc in servicesSnapshot.docs) {
        final data = doc.data();
        loadedServices.add({
          'id': doc.id,
          'name': data['name'] ?? 'Service',
          'icon': Icons.miscellaneous_services,
          'isSelected': false,
          'imageUrl': data['imageUrl'] ?? '',
        });
      }
      
      if (mounted) {
        setState(() {
          _categories = loadedServices;
        });
      }
    } catch (e) {
      // Handle error, e.g., show a snackbar
      if (mounted) {
        // CustomSnackBar.showError(context, 'Erreur de chargement des services: $e'); // Assuming CustomSnackBar is available
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }
  
  // Scroll listener to hide/show search bar
  void _scrollListener() {
    // Disable the behavior that might be causing the refresh issue
    // We'll keep this empty to prevent any state changes during scrolling
  }
  
  // Method to select a category
  void _selectCategory(int index) {
    setState(() {
      for (int i = 0; i < _categories.length; i++) {
        _categories[i]['isSelected'] = (i == index);
      }
    });
  }

  // Cache pour le stream
  Stream<QuerySnapshot>? _cachedStream;

  // Get marketplace posts with filters
  Stream<QuerySnapshot> _getMarketplacePosts() {
    // Reset the cached stream when filters change
    _cachedStream = null;
    
    Query query = FirebaseFirestore.instance.collection('marketplace');
    
    // Only show validated posts
    query = query.where('isValidated', isEqualTo: true);
    
    // Apply category filter if not "Tous"
    final selectedCategory = _categories.firstWhere((cat) => cat['isSelected'], orElse: () => _categories[0]);
    if (selectedCategory['id'] != 'all') {
      query = query.where('category', isEqualTo: selectedCategory['id']);
    }
    
    // Apply condition filter if not "All"
    if (_filterCondition != 'All') {
      query = query.where('condition', isEqualTo: _filterCondition);
    }
    
    // Apply price range filter
    query = query.where('price', isGreaterThanOrEqualTo: _priceRange.start);
    query = query.where('price', isLessThanOrEqualTo: _priceRange.end);
    
    // Apply location filter if not "Tous"
    if (_filterLocation != null && _filterLocation != 'Tous') {
      query = query.where('location', isEqualTo: _filterLocation);
    }
    
    // Apply sort order (keep existing sort by price and date)
    query = query.orderBy('price', descending: !_isAscending);
    query = query.orderBy('createdAt', descending: !_sortByDateAsc);
    
    _cachedStream = query.snapshots();
    return _cachedStream!;
  }
  
  void _toggleFilterVisibility() {
    setState(() {
      _isFilterVisible = !_isFilterVisible;
    });
  }

  void _applyFilters({
    required String condition,
    required bool sortByDateAsc,
    required RangeValues priceRange,
    String? location, // New parameter for location
  }) {
    setState(() {
      _filterCondition = condition;
      _sortByDateAsc = sortByDateAsc;
      _priceRange = priceRange;
      _filterLocation = location; // Update location filter
      _isFilterVisible = false;
    });
  }

  void _resetFilters() {
    setState(() {
      _filterCondition = 'All';
      _sortByDateAsc = false;
      _priceRange = const RangeValues(0, 10000);
      _filterLocation = 'Tous'; // Reset location filter
      _searchController.clear();
      _searchQuery = '';
      
      // Reset categories
      for (int i = 0; i < _categories.length; i++) {
        _categories[i]['isSelected'] = (i == 0); // Select 'All' category
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return WillPopScope(
      onWillPop: () async {
        // Navigate to home page when back button is pressed
        context.go('/clientHome');
        return false;
      },
      child: Scaffold(
        backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightInputBackground,
        drawer: const Sidebar(), // Add the Sidebar widget as the drawer
        appBar: CustomAppBar(
          title: 'Marketplace',
          showBackButton: false,
          showSidebar: true,
          showNotifications: true,
          currentIndex: 2, // Marketplace index
          // backgroundColor removed to use default from CustomAppBar
        ),
        body: CustomScrollView( // Changed to CustomScrollView
          controller: _scrollController, // Assign scroll controller
          slivers: [
            // Search bar with filter button (as a SliverToBoxAdapter)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md), // Adjusted padding
                child: Row(
                  children: [
                    // Search bar (takes most of the width)
                    Expanded(
                      flex: 5,
                      child: MarketplaceSearch(
                        controller: _searchController,
                        hintText: 'Rechercher...',
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
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
                    // Small gap
                    SizedBox(width: AppSpacing.md), // Increased spacing
                    // Filter button
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: isDarkMode ? AppColors.darkInputBackground : AppColors.lightInputBackground,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd), // Use AppSpacing
                      ),
                      child: IconButton(
                        icon: Icon(
                          _isFilterVisible ? Icons.filter_list_off : Icons.filter_list,
                          color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, // Use AppColors
                        ),
                        onPressed: _toggleFilterVisibility,
                        tooltip: 'Filtrer',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Categories (as a SliverToBoxAdapter)
            SliverToBoxAdapter(
              child: Column(
                children: [
                  // Categories
                  SizedBox(
                    height: 90, // Reduced height for more space
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs), // Use AppSpacing
                      itemCount: _categories.length,
                      itemBuilder: (context, index) {
                        final category = _categories[index];
                        final isSelected = category['isSelected'] as bool;
                        
                        return Padding(
                          padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm), // Increased horizontal padding
                          child: GestureDetector(
                            onTap: () => _selectCategory(index),
                            child: SizedBox(
                              width: 60, // Reduced width for the entire column
                              child: Column(
                                mainAxisSize: MainAxisSize.min, // Use min size
                                children: [
                                  Container(
                                    width: 40, // Reduced size
                                    height: 40, // Reduced size
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                                          : Colors.transparent, // Changed to transparent for unselected
                                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd), // Use AppSpacing
                                    ),
                                    child: index == 0 
                                      ? Icon(
                                          category['icon'] as IconData,
                                          color: isSelected
                                              ? Colors.white
                                              : (isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary), // Use AppColors
                                          size: AppSpacing.iconSm, // Reduced icon size
                                        )
                                      : ClipRRect(
                                          borderRadius: BorderRadius.circular(AppSpacing.radiusMd), // Use AppSpacing
                                          child: category['imageUrl'] != null && category['imageUrl'].toString().isNotEmpty
                                            ? Image.network(
                                                category['imageUrl'].toString(),
                                                width: 40,
                                                height: 40,
                                                fit: BoxFit.cover,
                                                loadingBuilder: (context, child, loadingProgress) { // Added loadingBuilder
                                                  if (loadingProgress == null) return child;
                                                  return Center(
                                                    child: CircularProgressIndicator(
                                                      value: loadingProgress.expectedTotalBytes != null
                                                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                                          : null,
                                                      color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                                                    ),
                                                  );
                                                },
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Icon(
                                                    Icons.miscellaneous_services,
                                                    color: isSelected
                                                        ? Colors.white
                                                        : (isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary), // Use AppColors
                                                    size: AppSpacing.iconSm, // Reduced icon size
                                                  );
                                                },
                                              )
                                            : Icon(
                                                Icons.miscellaneous_services,
                                                color: isSelected
                                                    ? Colors.white
                                                    : (isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary), // Use AppColors
                                                size: AppSpacing.iconSm, // Use AppSpacing
                                              ),
                                          ),
                                    ),
                                    SizedBox(height: AppSpacing.sm), // Reduced spacing
                                    Flexible( // Added Flexible to handle text overflow
                                      child: Text(
                                        category['name'] as String,
                                        style: AppTypography.labelSmall(context).copyWith( // Changed to labelSmall
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          color: isSelected
                                              ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                                              : (isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary), // Use AppColors
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    
                    // Filter panel (conditionally visible)
                    if (_isFilterVisible)
                      MarketplaceFilter(
                        condition: _filterCondition,
                        sortByDateAsc: _sortByDateAsc,
                        priceRange: _priceRange,
                        selectedLocation: _filterLocation, // Pass selected location
                        onApply: _applyFilters,
                        onReset: _resetFilters,
                      ),
                  ],
                ), 
            ),
          
            // Results count and sort indicator replaced with buttons (as a SliverToBoxAdapter)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xs, horizontal: AppSpacing.lg), // Reduced vertical padding
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Buttons for favorites and my products
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(AppSpacing.radiusLg), // Use AppSpacing
                                onTap: () {
                                  context.push('/clientHome/marketplace/favorites');
                                },
                                child: Ink(
                                  height: 30, // Reduced height
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? AppColors.darkCardBackground : AppColors.lightCardBackground, // Use AppColors
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg), // Use AppSpacing
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm), // Reduced padding
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.favorite,
                                          size: AppSpacing.iconXs, // Reduced icon size
                                          color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, // Use AppColors
                                        ),
                                        SizedBox(width: AppSpacing.xs), // Reduced spacing
                                        Flexible(
                                          child: Text(
                                            'Favoris',
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.labelSmall(context).copyWith( // Changed to labelSmall
                                              color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, // Use AppColors
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: AppSpacing.sm), // Reduced spacing
                          Flexible(
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(AppSpacing.radiusLg), // Use AppSpacing
                                onTap: () {
                                  context.push('/clientHome/marketplace/my-products');
                                },
                                child: Ink(
                                  height: 30, // Reduced height
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? AppColors.darkCardBackground : AppColors.lightCardBackground, // Use AppColors
                                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg), // Use AppSpacing
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm), // Reduced padding
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.inventory_2,
                                          size: AppSpacing.iconXs, // Reduced icon size
                                          color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, // Use AppColors
                                        ),
                                        SizedBox(width: AppSpacing.xs), // Reduced spacing
                                        Flexible(
                                          child: Text(
                                            'Mes annonces',
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.labelSmall(context).copyWith( // Changed to labelSmall
                                              color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, // Use AppColors
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Sort indicator
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _sortByDateAsc = !_sortByDateAsc;
                        });
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Trier: ',
                            style: AppTypography.labelSmall(context).copyWith( // Changed to labelSmall
                              color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, // Use AppColors
                            ),
                          ),
                          Text(
                            _sortByDateAsc ? 'Plus ancien' : 'Plus récent',
                            style: AppTypography.labelSmall(context).copyWith( // Changed to labelSmall
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen, // Use AppColors
                            ),
                          ),
                          Icon(
                            _sortByDateAsc ? Icons.arrow_upward : Icons.arrow_downward,
                            size: AppSpacing.iconXs, // Reduced icon size
                            color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen, // Use AppColors
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Marketplace items (as a SliverGrid)
            StreamBuilder<QuerySnapshot>(
              stream: _getMarketplacePosts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return SliverFillRemaining( // Use SliverFillRemaining for loading/error/empty states
                    child: Center(child: CircularProgressIndicator(color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)), // Use AppColors
                  );
                }
                
                if (snapshot.hasError) {
                  return SliverFillRemaining( // Use SliverFillRemaining for loading/error/empty states
                    child: Center(
                      child: Text(
                        'Erreur de chargement: ${snapshot.error}',
                        style: AppTypography.bodyMedium(context).copyWith(color: AppColors.errorLightRed), // Use AppColors
                      ),
                    ),
                  );
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return SliverFillRemaining( // Use SliverFillRemaining for loading/error/empty states
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: AppSpacing.iconXl, // Use AppSpacing
                            color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint, // Use AppColors
                          ),
                          SizedBox(height: AppSpacing.md), // Use AppSpacing
                          Text(
                            'Aucune annonce trouvée',
                            style: AppTypography.h4(context).copyWith( // Use AppTypography
                              fontWeight: FontWeight.w500,
                              color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, // Use AppColors
                            ),
                          ),
                          SizedBox(height: AppSpacing.xs), // Use AppSpacing
                          Text(
                            'Essayez de modifier vos filtres',
                            style: AppTypography.bodyMedium(context).copyWith( // Use AppTypography
                              color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint, // Use AppColors
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                // Get the selected category
                final selectedCategory = _categories.firstWhere(
                  (category) => category['isSelected'] == true,
                  orElse: () => _categories.first,
                );
                
                // Filter posts for the "Autre" category client-side
                var posts = snapshot.data!.docs;
                if (selectedCategory['name'] == 'Autre') {
                  // Get the list of standard categories (excluding "Tous" and "Autre")
                  final standardCategories = _categories
                      .where((cat) => cat['name'] != 'Tous' && cat['name'] != 'Autre')
                      .map((cat) => cat['name'] as String)
                      .toList();
                  
                  // Filter posts that don't belong to any standard category
                  posts = posts.where((doc) {
                    final category = doc['category'] as String?;
                    return category != null && !standardCategories.contains(category);
                  }).toList();
                }
                
                // Filter by search query if provided
                if (_searchQuery.isNotEmpty) {
                  final query = _searchQuery.toLowerCase();
                  posts = posts.where((doc) {
                    final title = (doc['title'] as String).toLowerCase();
                    final description = (doc['description'] as String).toLowerCase();
                    return title.contains(query) || description.contains(query);
                  }).toList();
                }
                
                if (posts.isEmpty) {
                  return SliverFillRemaining( // Use SliverFillRemaining for empty state
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: AppSpacing.iconXl, // Use AppSpacing
                            color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint, // Use AppColors
                          ),
                          SizedBox(height: AppSpacing.md), // Use AppSpacing
                          Text(
                            'Aucune annonce trouvée',
                            style: AppTypography.h4(context).copyWith( // Use AppTypography
                              fontWeight: FontWeight.w500,
                              color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, // Use AppColors
                            ),
                          ),
                          SizedBox(height: AppSpacing.xs), // Use AppTypography
                          Text(
                            'Essayez de modifier vos filtres',
                            style: AppTypography.bodyMedium(context).copyWith( // Use AppTypography
                              color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint, // Use AppColors
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                // Replace the GridView.builder with SliverGrid
                return SliverPadding( // Wrap with SliverPadding
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md), // Apply padding here
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final doc = posts[index];
                        final data = doc.data() as Map<String, dynamic>;
                        
                        // Ensure all required data is available and has valid types
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
                        
                        return MarketplaceCard(
                          id: doc.id,
                          title: title,
                          price: price,
                          location: location,
                          imageUrl: imageUrl,
                          condition: condition,
                          onTap: () {
                            // Navigate to detail page
                            context.push('/clientHome/marketplace/details/${doc.id}');
                          },
                        );
                      },
                      childCount: posts.length,
                    ),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.7, // Adjusted aspect ratio for thinner cards
                      crossAxisSpacing: AppSpacing.lg, // Increased spacing for smaller cards horizontally
                      mainAxisSpacing: AppSpacing.lg, // Increased spacing
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        // Update the bottom navigation bar without centerButton parameter
        bottomNavigationBar: CustomBottomNav(
          currentIndex: _selectedIndex,
        ),
        floatingActionButton: SizedBox( // Wrap with SizedBox to control size
          width: 70, // 25% bigger than default 56
          height: 70, // 25% bigger than default 56
          child: Container( // Wrap FAB in a Container with solid color
            decoration: BoxDecoration(
              shape: BoxShape.circle, // Ensure container is also circular
              color: AppColors.primaryGreen, // Solid green color
              boxShadow: [ // Keep existing shadow
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: () {
                context.go('/clientHome/marketplace/add'); // Navigate to add publication page
              },
              backgroundColor: Colors.transparent, // Make FAB transparent
              elevation: 0, // Remove default elevation to avoid color overlap
              shape: CircleBorder(), // Ensure it's perfectly rounded
              child: Icon(Icons.add, color: Colors.white, size: 32), // Add icon
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat, // Position at bottom right
      ),
    );
  }
}
