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
  
  // Scroll controller for hiding search bar and pagination
  final ScrollController _scrollController = ScrollController();

  // Pagination state variables
  DocumentSnapshot? _lastDocumentMarketplace;
  bool _hasMoreMarketplace = true;
  bool _isFetchingMoreMarketplace = false;
  final int _marketplacePageSize = 10; // Number of items per page
  final List<DocumentSnapshot> _allMarketplaceDocs = []; // Stores all fetched documents
  List<DocumentSnapshot> _displayedMarketplacePosts = []; // Posts to display after client-side filtering/search
  bool _isInitialLoading = true; // True while loading the very first set of data

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
      // Apply search client-side without full reload if query changes
      if (_searchQuery != _searchController.text) {
        setState(() {
          _searchQuery = _searchController.text;
        });
        _applyClientSideFiltersAndSearch(); 
      }
    });
    
    _scrollController.addListener(_scrollListener);
    
    // Load services (categories) first, then load initial marketplace data
    _loadServices().then((_) {
      if (mounted) {
        _loadInitialMarketplaceData();
      }
    });
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
  
  // Scroll listener for pagination
  void _scrollListener() {
    // Logic for hiding search bar (if any was intended) can be added here.
    // Pagination logic:
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300 && // Trigger a bit before the end
        _hasMoreMarketplace &&
        !_isFetchingMoreMarketplace &&
        !_isInitialLoading) { // Don't fetch more if initial load is happening or already fetching
      _loadMoreMarketplaceData();
    }
  }
  
  // Method to select a category
  void _selectCategory(int index) {
    bool changed = false;
    for (int i = 0; i < _categories.length; i++) {
      if (_categories[i]['isSelected'] != (i == index)) {
        changed = true;
        _categories[i]['isSelected'] = (i == index);
      }
    }
    if (changed) {
      setState(() {}); // Update UI for category selection
      _loadInitialMarketplaceData(); // Reload data as category filter changed
    }
  }

  // --- New methods for pagination and data handling ---

  Query _buildMarketplaceQuery() {
    Query query = FirebaseFirestore.instance.collection('marketplace');
    
    query = query.where('isValidated', isEqualTo: true);
    
    final selectedCategory = _categories.firstWhere(
      (cat) => cat['isSelected'], 
      orElse: () => _categories.firstWhere((c) => c['id'] == 'all', orElse: () => _categories.first)
    );

    // Apply category filter if not "Tous"
    if (selectedCategory['id'] != 'all') {
      query = query.where('category', isEqualTo: selectedCategory['id']);
    }
    
    if (_filterCondition != 'All') {
      query = query.where('condition', isEqualTo: _filterCondition);
    }
    
    query = query.where('price', isGreaterThanOrEqualTo: _priceRange.start);
    query = query.where('price', isLessThanOrEqualTo: _priceRange.end);
    
    if (_filterLocation != null && _filterLocation != 'Tous') {
      query = query.where('location', isEqualTo: _filterLocation);
    }
    
    // Firestore requires the first orderBy field to match the range filter field if one exists.
    // Price is used in range filter, so it must be the first orderBy.
    query = query.orderBy('price', descending: !_isAscending); // _isAscending is final false, so descending: true
    query = query.orderBy('createdAt', descending: !_sortByDateAsc);
    
    return query;
  }

  Future<void> _fetchMarketplacePage({DocumentSnapshot? startAfter}) async {
    if (!mounted) return;

    Query baseQuery = _buildMarketplaceQuery();
    if (startAfter != null) {
      baseQuery = baseQuery.startAfterDocument(startAfter);
    }
    
    try {
      final QuerySnapshot snapshot = await baseQuery.limit(_marketplacePageSize).get();
      if (!mounted) return;

      final newDocs = snapshot.docs;
      _allMarketplaceDocs.addAll(newDocs); // Add to the main list
      _lastDocumentMarketplace = newDocs.isNotEmpty ? newDocs.last : null;
      _hasMoreMarketplace = newDocs.length == _marketplacePageSize;
      
      _applyClientSideFiltersAndSearch(); // This will update _displayedMarketplacePosts and call setState
    } catch (e) {
      print("Error fetching marketplace page: $e");
      if (mounted) {
        // Optionally show a snackbar or error message
        // setState(() { _isFetchingMoreMarketplace = false; _isInitialLoading = false; });
      }
    }
  }

  Future<void> _loadInitialMarketplaceData() async {
    if (!mounted) return;
    setState(() {
      _isInitialLoading = true;
      _allMarketplaceDocs.clear();
      _displayedMarketplacePosts.clear();
      _lastDocumentMarketplace = null;
      _hasMoreMarketplace = true;
      _isFetchingMoreMarketplace = false; // Ensure this is reset
    });

    await _fetchMarketplacePage();

    if (mounted) {
      setState(() {
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _loadMoreMarketplaceData() async {
    if (!mounted || _isFetchingMoreMarketplace || !_hasMoreMarketplace) return;

    setState(() {
      _isFetchingMoreMarketplace = true;
    });

    await _fetchMarketplacePage(startAfter: _lastDocumentMarketplace);

    if (mounted) {
      setState(() {
        _isFetchingMoreMarketplace = false;
      });
    }
  }

  void _applyClientSideFiltersAndSearch() {
    if (!mounted) return;

    List<DocumentSnapshot> currentPosts = List.from(_allMarketplaceDocs);

    // Apply search query
    if (_searchQuery.isNotEmpty) {
      final searchQueryLower = _searchQuery.toLowerCase();
      currentPosts = currentPosts.where((doc) {
        final postData = doc.data() as Map<String, dynamic>;
        final title = (postData['title'] as String? ?? '').toLowerCase();
        final description = (postData['description'] as String? ?? '').toLowerCase();
        return title.contains(searchQueryLower) || description.contains(searchQueryLower);
      }).toList();
    }
    
    setState(() {
      _displayedMarketplacePosts = currentPosts;
    });
  }
  // --- End of new methods ---
  
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
    _loadInitialMarketplaceData(); // Reload data as filters changed
  }

  void _resetFilters() {
    setState(() {
      _filterCondition = 'All';
      _sortByDateAsc = false;
      _priceRange = const RangeValues(0, 10000);
      _filterLocation = 'Tous'; // Reset location filter
      _searchController.clear();
      // _searchQuery will be cleared by searchController listener if needed,
      // or clear it explicitly and call _applyClientSideFiltersAndSearch
      _searchQuery = ''; 
      
      // Reset categories
      for (int i = 0; i < _categories.length; i++) {
        _categories[i]['isSelected'] = (i == 0); // Select 'All' category
      }
    });
    _loadInitialMarketplaceData(); // Reload data as filters reset
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
                        _loadInitialMarketplaceData(); // Reload data as sort order changed
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
            
            // Marketplace items (as a SliverGrid or SliverList)
            if (_isInitialLoading)
              SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)),
              )
            else if (_displayedMarketplacePosts.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: AppSpacing.iconXl,
                        color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint,
                      ),
                      SizedBox(height: AppSpacing.md),
                      Text(
                        'Aucune annonce trouvée',
                        style: AppTypography.h4(context).copyWith(
                          fontWeight: FontWeight.w500,
                          color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Text(
                        'Essayez de modifier vos filtres ou votre recherche',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyMedium(context).copyWith(
                          color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == _displayedMarketplacePosts.length) {
                        // This is the loading indicator at the bottom
                        return _isFetchingMoreMarketplace && _hasMoreMarketplace
                            ? Center(child: Padding(
                                padding: EdgeInsets.all(AppSpacing.md),
                                child: CircularProgressIndicator(color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen),
                              ))
                            : const SizedBox.shrink(); // Or some placeholder if needed
                      }

                      final doc = _displayedMarketplacePosts[index];
                      final data = doc.data() as Map<String, dynamic>;
                      
                      final String title = data['title'] as String? ?? 'Sans titre';
                      final double price = (data['price'] is num) 
                            ? (data['price'] as num).toDouble() 
                            : 0.0;
                      final String location = data['location'] as String? ?? 'Emplacement inconnu';
                      final String condition = data['condition'] as String? ?? 'État inconnu';
                      
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
                          context.push('/clientHome/marketplace/details/${doc.id}');
                        },
                      );
                    },
                    // Add 1 to childCount if there's more data OR currently fetching, to show the loader
                    childCount: _displayedMarketplacePosts.length + (_hasMoreMarketplace ? 1 : 0),
                  ),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: AppSpacing.lg,
                    mainAxisSpacing: AppSpacing.lg,
                  ),
              ),
        ),
        ],
        ),
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
