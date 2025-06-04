import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../front/app_colors.dart';
import '../../front/app_spacing.dart'; // Added AppSpacing import
import '../../front/app_typography.dart'; // Added AppTypography import
import '../../front/custom_app_bar.dart';
import '../../front/custom_bottom_nav.dart';

class MesProduitsPage extends StatefulWidget {
  const MesProduitsPage({super.key});

  @override
  State<MesProduitsPage> createState() => _MesProduitsPageState();
}

class _MesProduitsPageState extends State<MesProduitsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final user = FirebaseAuth.instance.currentUser;
  // Update the selected index to marketplace (index 2)
  final int _selectedIndex = 2; 
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Stream to get user's posts
  Stream<QuerySnapshot> _getUserPosts() {
    if (user == null) {
      // Return an empty stream
      return Stream.empty();
    }
    
    return FirebaseFirestore.instance
        .collection('marketplace')
        .where('userId', isEqualTo: user!.uid)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    if (user == null) {
      return Scaffold(
        backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightInputBackground,
        appBar: CustomAppBar(
          title: 'Mes Produits',
          showBackButton: true,
          // backgroundColor, titleColor, iconColor removed
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: AppSpacing.iconXl,
                color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint,
              ),
              SizedBox(height: AppSpacing.md),
              Text(
                'Vous devez être connecté',
                style: AppTypography.bodyMedium(context).copyWith(
                  color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightInputBackground,
      appBar: CustomAppBar(
        title: 'Mes Annonces',
        showBackButton: true,
        // backgroundColor, titleColor, iconColor removed
      ),
      body: NestedScrollView( // Use NestedScrollView for scrolling AppBar and TabBar
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return <Widget>[
            SliverPersistentHeader(
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  isScrollable: false, // Reverted to false
                  labelColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                  unselectedLabelColor: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                    color: isDarkMode ? AppColors.primaryGreen.withOpacity(0.2) : AppColors.primaryDarkGreen.withOpacity(0.2),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelStyle: AppTypography.labelMedium(context).copyWith( // Changed to labelMedium
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: AppTypography.labelMedium(context).copyWith( // Changed to labelMedium
                    fontWeight: FontWeight.w500,
                  ),
                  dividerColor: Colors.transparent,
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.all_inclusive, size: AppSpacing.iconXs), // Adjusted icon size
                          SizedBox(width: AppSpacing.xxs), // Adjusted spacing
                          Text(
                            'Tous',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.hourglass_empty, size: AppSpacing.iconXs), // Adjusted icon size
                          SizedBox(width: AppSpacing.xxs), // Adjusted spacing
                          Text(
                            'En attente',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline, size: AppSpacing.iconXs), // Adjusted icon size
                          SizedBox(width: AppSpacing.xxs), // Adjusted spacing
                          Text(
                            'Validées',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pinned: true, // Pin the TabBar
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.lg),
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Rechercher dans mes annonces...',
                    prefixIcon: Icon(Icons.search, color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: isDarkMode ? AppColors.darkCardBackground : AppColors.lightCardBackground,
                    contentPadding: EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.md),
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView( // TabBarView directly in body of NestedScrollView
          controller: _tabController,
          children: [
            // All posts
            _buildPostsList(context, false, null),
            
            // Pending posts
            _buildPostsList(context, true, false),
            
            // Validated posts
            _buildPostsList(context, true, true),
          ],
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _selectedIndex,
        // Remove the onTap handler since CustomBottomNav now handles navigation internally
      ),
    );
  }

  Widget _buildPostsList(BuildContext context, bool filterByValidation, bool? isValidated, [bool showRejected = false]) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return StreamBuilder<QuerySnapshot>(
      stream: _getUserPosts(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen));
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Erreur: ${snapshot.error}',
              style: AppTypography.bodyMedium(context).copyWith(color: AppColors.errorLightRed),
            ),
          );
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.shopping_bag_outlined,
                  size: AppSpacing.iconXl,
                  color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint,
                ),
                SizedBox(height: AppSpacing.md),
                Text(
                  'Aucune annonce trouvée',
                  style: AppTypography.bodyMedium(context).copyWith(
                    color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint,
                  ),
                ),
                SizedBox(height: AppSpacing.sm),
                ElevatedButton(
                  onPressed: () {
                    context.push('/clientHome/marketplace/add');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                  child: Text(
                    'Ajouter une annonce',
                    style: AppTypography.button(context),
                  ),
                ),
              ],
            ),
          );
        }
        
        // Filter posts based on tab and search query
        var filteredDocs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final title = data['title'] as String? ?? '';
          final description = data['description'] as String? ?? '';
          final matchesSearch = _searchQuery.isEmpty || 
              title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              description.toLowerCase().contains(_searchQuery.toLowerCase());
          
          if (showRejected) {
            // Show only rejected posts
            final isRejected = data['isRejected'] as bool? ?? false;
            return matchesSearch && isRejected;
          } else if (filterByValidation) {
            final docIsValidated = data['isValidated'] as bool? ?? false;
            final isRejected = data['isRejected'] as bool? ?? false;
            // For validated/pending tabs, exclude rejected posts
            return matchesSearch && docIsValidated == isValidated && !isRejected;
          }
          
          // For "All" tab, show everything
          return matchesSearch;
        }).toList();
        
        if (filteredDocs.isEmpty) {
          return Center(
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
                  'Aucun résultat trouvé',
                  style: AppTypography.bodyMedium(context).copyWith(
                    color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint,
                  ),
                ),
              ],
            ),
          );
        }
        
        return GridView.builder(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.9, // Adjusted aspect ratio for shorter cards
            crossAxisSpacing: AppSpacing.lg,
            mainAxisSpacing: AppSpacing.lg,
          ),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            final String title = data['title'] ?? 'Sans titre';
            final double price = (data['price'] is num) 
                ? (data['price'] as num).toDouble() 
                : 0.0;
            final List<dynamic> images = data['images'] ?? [];
            final bool isValidated = data['isValidated'] ?? false;
            final bool isRejected = data['isRejected'] ?? false;
            final String rejectionReason = data['rejectionReason'] ?? '';
            
            return GestureDetector(
              onTap: () {
                context.push('/clientHome/marketplace/details/${doc.id}');
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isDarkMode ? AppColors.darkCardBackground : AppColors.lightCardBackground,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product image and badges
                    Stack( // Added Stack to layer image and badge
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusMd)),
                          child: SizedBox(
                            height: MediaQuery.of(context).size.width > 600 ? 120 : 90, // Adjusted image height
                            width: double.infinity,
                            child: images.isNotEmpty
                                ? Image.network(
                                    images[0],
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: isDarkMode ? AppColors.darkInputBackground : AppColors.lightInputBackground,
                                        child: Icon(
                                          Icons.image_not_supported,
                                          color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint,
                                          size: AppSpacing.iconLg,
                                        ),
                                      );
                                    },
                                  )
                                : Container(
                                    color: isDarkMode ? AppColors.darkInputBackground : AppColors.lightInputBackground,
                                    child: Icon(
                                      Icons.image_not_supported,
                                      color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint,
                                      size: AppSpacing.iconLg,
                                    ),
                                  ),
                          ),
                        ),
                        // Refusé badge
                        if (isRejected)
                          Positioned(
                            top: AppSpacing.sm,
                            left: AppSpacing.sm,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                              decoration: BoxDecoration(
                                color: AppColors.errorLightRed,
                                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                              ),
                              child: Text(
                                'Refusée',
                                style: AppTypography.labelSmall(context).copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        // En attente badge
                        if (!isValidated && !isRejected) // Ensure it's pending and not rejected
                          Positioned(
                            top: AppSpacing.sm,
                            left: AppSpacing.sm,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                              decoration: BoxDecoration(
                                color: AppColors.warningOrange,
                                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                              ),
                              child: Text(
                                'En attente',
                                style: AppTypography.labelSmall(context).copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        // Validé badge (new)
                        if (isValidated && !isRejected) // Ensure it's validated and not rejected
                          Positioned(
                            top: AppSpacing.sm,
                            left: AppSpacing.sm,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen, // Green color for validated
                                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                              ),
                              child: Text(
                                'Validée',
                                style: AppTypography.labelSmall(context).copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    
                    // Product info
                    Expanded( // Wrap in Expanded to prevent overflow
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.sm), // Reduced padding
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min, // Use minimum space needed
                          children: [
                            Text(
                              title,
                              style: AppTypography.bodyMedium(context).copyWith(
                                fontSize: MediaQuery.of(context).size.width > 600 ? 14 : 12, // Smaller font on small screens
                                fontWeight: FontWeight.w600,
                                color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                              maxLines: 1, // Limit to 1 line to save space
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: AppSpacing.xxs), // Reduced spacing
                            Text(
                              '$price DT',
                              style: AppTypography.bodyLarge(context).copyWith(
                                fontSize: MediaQuery.of(context).size.width > 600 ? 16 : 14, // Smaller font on small screens
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                              ),
                            ),
                            
                            // Show rejection reason if post is rejected
                            if (isRejected && rejectionReason.isNotEmpty)
                              Flexible( // Make this flexible to avoid overflow
                                child: Padding(
                                  padding: EdgeInsets.only(top: AppSpacing.xxs), // Reduced padding
                                  child: Text(
                                    'Raison: ${rejectionReason.length > 20 ? rejectionReason.substring(0, 20) + '...' : rejectionReason}', // Show less text
                                    style: AppTypography.labelSmall(context).copyWith(
                                      fontSize: 9, // Smaller font size
                                      color: AppColors.errorLightRed.withOpacity(0.7),
                                      fontStyle: FontStyle.italic,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                          ],
                        ),
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
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDarkMode ? Colors.grey.shade900 : Colors.white, // Match AppBar/BottomNav
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}
