import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/auth_helper.dart';
import '../front/sidebar.dart';
import 'package:go_router/go_router.dart';
import '../front/custom_bottom_nav.dart';
import '../front/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import '../front/custom_app_bar.dart';
import '../front/marketplace_search.dart';


class ClientHomePage extends StatefulWidget {
  const ClientHomePage({super.key});

  @override
  State<ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<ClientHomePage> {
  final int _selectedIndex = 0; // Home page is index 0
  String _firstName = '';
  String _gender = '';
  String? _avatarUrl; // Add this line to store user avatar URL

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _checkAccess();
    _loadUserData();
  }


  // Clear search query
  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
    });
  }

  // Handle search query changes
  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  Future<void> _checkAccess() async {
    if (!mounted) return;
    await AuthHelper.checkUserRole(context, 'client');
  }
  
  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (userData.exists && mounted) {
        setState(() {
          _firstName = userData.data()?['firstname'] ?? '';
          _gender = userData.data()?['gender'] ?? '';
          _avatarUrl = userData.data()?['avatarUrl']; // Add this line to load avatar URL
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;
    final mediaQuery = MediaQuery.of(context);
    final padding = mediaQuery.size.width > 600 
        ? const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0)
        : const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0);
    
    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightInputBackground,
      drawer: const Sidebar(),
      appBar: CustomAppBar(
        title: 'Accueil',
        showBackButton: false,
        showSidebar: true,
        showNotifications: true,
        backgroundColor: isDarkMode ? Colors.grey.shade900 : AppColors.lightBackground,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: primaryColor,
          onRefresh: () async {
            await _loadUserData();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome section with personalized greeting and quick action buttons
                  _buildWelcomeSection(isDarkMode),
                  
                  SizedBox(height: mediaQuery.size.width > 600 ? 32 : 24),
                  
                  // Services section
                  _buildServicesSection(context, isDarkMode, primaryColor),
                  
                  SizedBox(height: mediaQuery.size.width > 600 ? 32 : 24),
                  
                  // Recent marketplace items
                  _buildRecentMarketplaceSection(context, isDarkMode, primaryColor),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _selectedIndex,
        backgroundColor: isDarkMode ? Colors.grey.shade900 : AppColors.lightBackground,
      ),
    );
  }
  
  Widget _buildWelcomeSection(bool isDarkMode) {
    String greeting = 'Bienvenue';
    if (_firstName.isNotEmpty) {
      if (_gender.toLowerCase() == 'homme' || _gender.toLowerCase() == 'male') {
        greeting = 'Bienvenue Mr $_firstName';
      } else if (_gender.toLowerCase() == 'femme' || _gender.toLowerCase() == 'female') {
        greeting = 'Bienvenue Mme $_firstName';
      } else {
        greeting = 'Bienvenue $_firstName';
      }
    }
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 400;
        
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 8, bottom: 16),
          padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDarkMode
                  ? [Color(0xFF1E2923), Color(0xFF3A4D40)]
                  : [AppColors.primaryDarkGreen, AppColors.primaryGreen],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 3),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            children: [
              // User greeting section
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: isSmallScreen ? 24 : 32,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: _avatarUrl != null && _avatarUrl!.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            _avatarUrl!,
                            width: isSmallScreen ? 48 : 64,
                            height: isSmallScreen ? 48 : 64,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: isSmallScreen ? 24 : 32,
                            ),
                          ),
                        )
                      : Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: isSmallScreen ? 24 : 32,
                        ),
                  ),
                  SizedBox(width: isSmallScreen ? 12 : 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greeting,
                          style: GoogleFonts.poppins(
                            fontSize: isSmallScreen ? 20 : 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Que recherchez-vous aujourd\'hui ?',
                          style: GoogleFonts.poppins(
                            fontSize: isSmallScreen ? 12 : 14,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              // Divider between greeting and buttons
              Padding(
                padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 12 : 16),
                child: Divider(
                  color: Colors.white.withOpacity(0.2),
                  thickness: 1,
                ),
              ),
              
              // Quick action buttons inside the welcome card
              _buildQuickActionButtonsInCard(context, isDarkMode, isSmallScreen),
            ],
          ),
        );
      }
    );
  }

  // Updated method for quick action buttons inside the welcome card
  Widget _buildQuickActionButtonsInCard(BuildContext context, bool isDarkMode, bool isSmallScreen) {
    final itemSize = isSmallScreen ? 55.0 : 60.0; // Even smaller size
    final fontSize = isSmallScreen ? 9.0 : 10.0; // Smaller font
    
    return Wrap(
      alignment: WrapAlignment.spaceEvenly,
      spacing: isSmallScreen ? 8 : 12,
      runSpacing: isSmallScreen ? 10 : 12,
      children: [
        _buildQuickActionItemInCard(
          context,
          isDarkMode,
          'Réservations',
          Icons.event_note_rounded,
          () => context.go('/clientHome/my-reservations'),
          itemSize,
          fontSize,
        ),
        _buildQuickActionItemInCard(
          context,
          isDarkMode,
          'Réclamations',
          Icons.support_rounded,
          () => context.go('/clientHome/reclamations'),
          itemSize,
          fontSize,
        ),
        _buildQuickActionItemInCard(
          context,
          isDarkMode,
          'Favoris',
          Icons.favorite_rounded,
          () => context.go('/clientHome/marketplace/favorites'),
          itemSize,
          fontSize,
        ),
        _buildQuickActionItemInCard(
          context,
          isDarkMode,
          'Prestataires',
          Icons.person_pin_rounded,
          () => context.go('/clientHome/favorite-providers'),
          itemSize,
          fontSize,
        ),
      ],
    );
  }

  Widget _buildQuickActionItemInCard(
    BuildContext context,
    bool isDarkMode,
    String label,
    IconData icon,
    VoidCallback onTap,
    [double size = 50.0, double fontSize = 10.0]
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [       
          // Button with white/transparent background
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Center(
              child: Icon(
                icon,
                color: Colors.white,
                size: size * 0.38,
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Text label
          SizedBox(
            width: size + 10,
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: fontSize,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.9),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildServicesSection(BuildContext context, bool isDarkMode, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title with better spacing
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center, // Changed to center alignment
            children: [
              Text(
                'Nos services',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              TextButton(
                onPressed: () {
                  context.go('/clientHome/all-services');
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Voir tout',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: primaryColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Search bar with improved styling and spacing
        Container(
          margin: const EdgeInsets.only(bottom: 16.0),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: MarketplaceSearch(
            controller: _searchController,
            onClear: _clearSearch,
            hintText: 'Trouvez un service...',
            onChanged: _onSearchChanged,
          ),
        ),
        
        // Conditional display based on search
        _searchQuery.isEmpty 
            ? _buildServicesList(isDarkMode, primaryColor) 
            : _buildSearchResults(isDarkMode, primaryColor),
      ],
    );
  }
  
  // Display horizontal scrollable list of services (original view)
  Widget _buildServicesList(bool isDarkMode, Color primaryColor) {
    return SizedBox(
      height: 100, // Reduced height by 20% (from 120 to 100)
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('services')
            .limit(6)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: primaryColor,
              ),
            );
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Erreur de chargement des services',
                style: GoogleFonts.poppins(color: Colors.red),
              ),
            );
          }
          
          final services = snapshot.data?.docs ?? [];
          
          if (services.isEmpty) {
            return Center(
              child: Text(
                'Aucun service disponible',
                style: GoogleFonts.poppins(
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
            );
          }
          
          // Horizontal list view for swipeable services with improved cards
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: services.length,
            itemBuilder: (context, index) {
              final service = services[index].data() as Map<String, dynamic>;
              final serviceName = service['name'] as String? ?? 'Service';
              final imageUrl = service['imageUrl'] as String?;
              
              return Padding(
                padding: const EdgeInsets.only(right: 8.0), // Reduced padding
                child: GestureDetector(
                  onTap: () {
                    context.go('/clientHome/service-providers/$serviceName');
                  },
                  child: Container(
                    width: 68, // Reduced width by 20% (from 85 to 68)
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        // Service image with transparent background
                        Expanded(
                          flex: 3,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.transparent,
                            ),
                            width: double.infinity,
                            child: imageUrl != null && imageUrl.isNotEmpty
                                ? Container(
                                    decoration: BoxDecoration(
                                      color: isDarkMode 
                                          ? AppColors.darkBackground 
                                          : AppColors.lightInputBackground,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(6.0), // Reduced padding
                                      child: Image.network(
                                        imageUrl,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Center(
                                            child: Icon(
                                              Icons.image_not_supported_rounded,
                                              color: isDarkMode ? Colors.white54 : Colors.black38,
                                              size: 20, // Reduced icon size
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Icon(
                                      Icons.home_repair_service_rounded,
                                      color: primaryColor,
                                      size: 22, // Reduced icon size
                                    ),
                                  ),
                          ),
                        ),
                        
                        // Service name with improved styling
                        Expanded(
                          flex: 1,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2.0), // Reduced padding
                              child: Text(
                                serviceName,
                                style: GoogleFonts.poppins(
                                  fontSize: 10, // Smaller font
                                  fontWeight: FontWeight.w500,
                                  color: isDarkMode ? Colors.white70 : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
  
  // Apply the same styling improvements to search results
  Widget _buildSearchResults(bool isDarkMode, Color primaryColor) {
    return SizedBox(
      height: 120, // Reduced height from 140 to 120
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('services')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: primaryColor,
              ),
            );
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Erreur de recherche',
                style: GoogleFonts.poppins(color: Colors.red),
              ),
            );
          }
          
          final services = snapshot.data?.docs
              .map((doc) => {
                    'id': doc.id,
                    ...doc.data() as Map<String, dynamic>,
                  })
              .toList() ??
              [];
              
          // Filter services based on search query
          final filteredServices = services.where((service) {
            final name = service['name'] as String? ?? '';
            return name.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();
          
          if (filteredServices.isEmpty) {
            return Center(
              child: Text(
                'Aucun service trouvé pour "$_searchQuery"',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            );
          }
          
          // Display search results in a horizontal list (same as default view)
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: filteredServices.length,
            itemBuilder: (context, index) {
              final service = filteredServices[index];
              final serviceName = service['name'] as String? ?? 'Service';
              final imageUrl = service['imageUrl'] as String?;
              
              return Padding(
                padding: const EdgeInsets.only(right: 10.0),
                child: GestureDetector(
                  onTap: () {
                    context.go('/clientHome/service-providers/$serviceName');
                  },
                  child: Container(
                    width: 90, // Further reduced from 100 to 90
                    decoration: BoxDecoration(
                      color: Colors.transparent, // Make container transparent
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        // Service image with improved styling
                        Expanded(
                          flex: 3,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12), // Consistent rounded corners
                              color: isDarkMode 
                                  ? AppColors.darkBackground // Match page background in dark mode
                                  : AppColors.lightInputBackground, // Match page background in light mode
                            ),
                            width: double.infinity,
                            child: imageUrl != null && imageUrl.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Container(
                                          color: Colors.grey[300],
                                          child: const Center(
                                            child: Icon(
                                              Icons.image_not_supported,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        );
                                      },
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Center(
                                          child: CircularProgressIndicator(
                                            value: loadingProgress.expectedTotalBytes != null
                                                ? loadingProgress.cumulativeBytesLoaded /
                                                    loadingProgress.expectedTotalBytes!
                                                : null,
                                          ),
                                        );
                                      },
                                    ),
                                  )
                                : Center(
                                    child: Icon(
                                      Icons.home_repair_service_rounded,
                                      color: primaryColor,
                                      size: 24, // Smaller icon
                                    ),
                                  ),
                          ),
                        ),
                        
                        // Service name with improved styling
                        Expanded(
                          flex: 1,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4.0), // Reduced padding
                              child: Text(
                                serviceName,
                                style: GoogleFonts.poppins(
                                  fontSize: 11, // Smaller font
                                  fontWeight: FontWeight.w500,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
  
  // Build the recent marketplace section
  Widget _buildRecentMarketplaceSection(BuildContext context, bool isDarkMode, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title with improved spacing
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Marketplace',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              TextButton(
                onPressed: () {
                  context.go('/clientHome/marketplace');
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Voir tout',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: primaryColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        
        // Horizontal scrollable marketplace items
        SizedBox(
          height: 180, // Height for the marketplace items row
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('marketplace')
                .orderBy('createdAt', descending: true)
                .limit(6) // Limit to 6 items
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(
                    color: primaryColor,
                  ),
                );
              }
              
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Erreur de chargement des annonces',
                    style: GoogleFonts.poppins(color: Colors.red),
                  ),
                );
              }
              
              final posts = snapshot.data?.docs ?? [];
              
              if (posts.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shopping_bag_outlined,
                        size: 36,
                        color: isDarkMode ? Colors.white54 : Colors.black38,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Aucune annonce disponible',
                        style: GoogleFonts.poppins(
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              // Horizontal list view for swipeable marketplace items
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index].data() as Map<String, dynamic>;
                  final postId = posts[index].id;
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: GestureDetector(
                      onTap: () {
                        context.go('/clientHome/marketplace/post/$postId');
                      },
                      child: Container(
                        width: 140, // Width of each marketplace card
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.grey.shade900 : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Product image
                            SizedBox(
                              height: 100,
                              width: double.infinity,
                              child: ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                                child: post['images'] != null && (post['images'] as List).isNotEmpty
                                    ? Image.network(
                                        post['images'][0],
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                                            child: Center(
                                              child: Icon(
                                                Icons.image_not_supported_rounded,
                                                color: isDarkMode ? Colors.white54 : Colors.black38,
                                                size: 24,
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                    : Container(
                                        color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                                        child: Center(
                                          child: Icon(
                                            Icons.image_not_supported_rounded,
                                            color: isDarkMode ? Colors.white54 : Colors.black38,
                                            size: 24,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            
                            // Product info
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Title
                                  Text(
                                    post['title'] ?? 'Sans titre',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDarkMode ? Colors.white : Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  
                                  // Price
                                  Text(
                                    '${post['price'] ?? 0} DT',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  
                                  // Condition
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: post['condition'] == 'Neuf'
                                          ? Colors.green.withOpacity(0.2)
                                          : Colors.orange.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: Text(
                                      post['condition'] ?? 'Occasion',
                                      style: GoogleFonts.poppins(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w500,
                                        color: post['condition'] == 'Neuf'
                                            ? Colors.green.shade800
                                            : Colors.orange.shade800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}