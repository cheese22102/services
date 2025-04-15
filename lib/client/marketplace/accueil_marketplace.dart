import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../front/app_colors.dart';
import '../../front/marketplace_card.dart'; 
import '../../front/marketplace_filter.dart'; 
import '../../front/marketplace_search.dart'; 
import '../../front/custom_app_bar.dart';
import '../../front/custom_bottom_nav.dart';

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
  RangeValues _priceRange = const RangeValues(0, 10000);
  bool _isFilterVisible = false;
  
  // Scroll controller for hiding search bar
  final ScrollController _scrollController = ScrollController();
  bool _isSearchBarVisible = true;

  // Categories with added "Autre" category
  final List<Map<String, dynamic>> _categories = [
    {'name': 'Tous', 'icon': Icons.apps, 'isSelected': true},
    {'name': 'Électronique', 'icon': Icons.phone_android, 'isSelected': false},
    {'name': 'Vêtements', 'icon': Icons.checkroom, 'isSelected': false},
    {'name': 'Maison', 'icon': Icons.chair, 'isSelected': false},
    {'name': 'Sport', 'icon': Icons.sports_soccer, 'isSelected': false},
    {'name': 'Véhicules', 'icon': Icons.directions_car, 'isSelected': false},
    {'name': 'Jardinage', 'icon': Icons.grass, 'isSelected': false},
    {'name': 'Autre', 'icon': Icons.more_horiz, 'isSelected': false}, // Added "Autre" category
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
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }
  
  // Scroll listener to hide/show search bar
  // Modify the _scrollListener method to prevent interfering with normal scrolling
  void _scrollListener() {
  // Disable the behavior that might be causing the refresh issue
  // We'll keep this empty to prevent any state changes during scrolling
  }
  
  // Method to scroll to top and show search bar

  // Cache pour le stream
  Stream<QuerySnapshot>? _cachedStream;

  // Get marketplace posts with filters
  Stream<QuerySnapshot> _getMarketplacePosts() {
    // Reset the cached stream when filters change
    _cachedStream = null;
    
    Query query = FirebaseFirestore.instance.collection('marketplace');
    
    // Only show validated posts
    query = query.where('isValidated', isEqualTo: true);

    // Apply condition filter
    if (_filterCondition != 'All') {
      query = query.where('condition', isEqualTo: _filterCondition);
    }

    // Apply price range filter
    query = query.where('price', isGreaterThanOrEqualTo: _priceRange.start);
    query = query.where('price', isLessThanOrEqualTo: _priceRange.end);

    // Apply category filter
    final selectedCategory = _categories.firstWhere(
      (category) => category['isSelected'] == true,
      orElse: () => _categories.first,
    );
    
    if (selectedCategory['name'] != 'Tous') {
      if (selectedCategory['name'] == 'Autre') {
        // For "Autre" category, we need a different approach
        // We'll filter in the UI since Firebase doesn't support "not in" queries easily
      } else {
        query = query.where('category', isEqualTo: selectedCategory['name']);
      }
    }

    // Apply sorting
    query = query.orderBy('createdAt', descending: !_sortByDateAsc);

    // Cache the stream
    _cachedStream = query.snapshots();
    return _cachedStream!;
  }

  void _selectCategory(int index) {
    setState(() {
      for (int i = 0; i < _categories.length; i++) {
        _categories[i]['isSelected'] = (i == index);
      }
      // Reset the cached stream to force a new query with the updated category filter
      _cachedStream = null;
    });
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
  }) {
    setState(() {
      _filterCondition = condition;
      _sortByDateAsc = sortByDateAsc;
      _priceRange = priceRange;
      _isFilterVisible = false;
    });
  }

  void _resetFilters() {
    setState(() {
      _filterCondition = 'All';
      _sortByDateAsc = false;
      _priceRange = const RangeValues(0, 10000);
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
        return false; // Simplement retourner false sans appeler _scrollToTop
      },
      child: Scaffold(
        backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: CustomAppBar(
          title: 'Marketplace',
          showBackButton: false,
          actions: [
            IconButton(
              icon: Icon(
                Icons.add_circle_outline,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              onPressed: () {
                // Navigate to add new marketplace item using the correct route
                context.push('/clientHome/marketplace/add');
              },
            ),
            IconButton(
              icon: Icon(
                _isFilterVisible ? Icons.filter_list_off : Icons.filter_list,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              onPressed: _toggleFilterVisibility,
            ),
          ],
        ),
        body: Column(
          children: [
            // Search bar and categories (always visible)
            Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: MarketplaceSearch(
                    controller: _searchController,
                    onClear: () {
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  ),
                ),
                
                // Categories
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      final isSelected = category['isSelected'] as bool;
                      
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: GestureDetector(
                          onTap: () => _selectCategory(index),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                                      : (isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Icon(
                                  category['icon'] as IconData,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDarkMode ? Colors.white70 : Colors.black54),
                                  size: 30,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                category['name'] as String,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected
                                      ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                                      : (isDarkMode ? Colors.white70 : Colors.black54),
                                ),
                              ),
                            ],
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
                    onApply: _applyFilters,
                    onReset: _resetFilters,
                  ),
            ],
          ),
          
          // Results count and sort indicator replaced with buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              context.push('/clientHome/marketplace/favorites');
                            },
                            child: Ink(
                              height: 32,
                              decoration: BoxDecoration(
                                color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.favorite,
                                      size: 14,
                                      color: isDarkMode ? Colors.white70 : Colors.black54,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        'Favoris',
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: isDarkMode ? Colors.white70 : Colors.black54,
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
                      const SizedBox(width: 8),
                      Flexible(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              context.push('/clientHome/marketplace/my-products');
                            },
                            child: Ink(
                              height: 32,
                              decoration: BoxDecoration(
                                color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.inventory_2,
                                      size: 14,
                                      color: isDarkMode ? Colors.white70 : Colors.black54,
                                    ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        'Mes articles',
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: isDarkMode ? Colors.white70 : Colors.black54,
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
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      Text(
                        _sortByDateAsc ? 'Plus ancien' : 'Plus récent',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                        ),
                      ),
                      Icon(
                        _sortByDateAsc ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 14,
                        color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Marketplace items
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _getMarketplacePosts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Erreur de chargement: ${snapshot.error}',
                      style: GoogleFonts.poppins(),
                    ),
                  );
                }
                
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: isDarkMode ? Colors.white54 : Colors.black38,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune annonce trouvée',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Essayez de modifier vos filtres',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: isDarkMode ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
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
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: isDarkMode ? Colors.white54 : Colors.black38,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune annonce trouvée',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Essayez de modifier vos filtres',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: isDarkMode ? Colors.white54 : Colors.black45,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                // Replace the GridView.builder with this updated version
                return GridView.builder(
                  controller: _scrollController,
                  // Use NeverScrollableScrollPhysics to disable the native scrolling behavior
                  // that might be causing the refresh, then wrap with ScrollConfiguration
                  physics: const ScrollPhysics(), // Use basic ScrollPhysics
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.8, // Adjust this ratio for card dimensions
                    crossAxisSpacing: 8, // Increased for better spacing
                    mainAxisSpacing: 8, // Increased for better spacing
                  ),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
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
                );
              },
            ),
          ),
        ],
      ),
      // Pas de floatingActionButton pour éviter les interférences
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _selectedIndex,
      ),
    ),
  );
}
}