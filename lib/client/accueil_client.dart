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
import 'dart:math';
import '../front/marketplace_card.dart';
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
        backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
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
                  // Welcome section with personalized greeting
                  _buildWelcomeSection(isDarkMode),
                  
                  SizedBox(height: mediaQuery.size.width > 600 ? 32 : 24),
                  
                  // Quick actions section
                  _buildQuickActionsSection(context, isDarkMode, primaryColor),
                  
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
        backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
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
          margin: const EdgeInsets.only(top: 8, bottom: 8),
          padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Replace the icon container with a proper avatar
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
        );
      }
    );
  }

  Widget _buildQuickActionsSection(BuildContext context, bool isDarkMode, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Actions rapides',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    'Accédez rapidement à vos fonctionnalitées préférées',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: isDarkMode ? Colors.white60 : Colors.black54,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final isSmallScreen = screenWidth < 360;
            final itemSize = isSmallScreen ? 60.0 : 70.0;
            final fontSize = isSmallScreen ? 10.0 : 12.0;
            
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickActionItem(
                  context,
                  isDarkMode,
                  'Réservations',
                  Icons.event_note_rounded, // Changed to a cleaner calendar icon
                  () => context.go('/clientHome/my-reservations'),
                  itemSize,
                  fontSize,
                  primaryColor,
                ),
                _buildQuickActionItem(
                  context,
                  isDarkMode,
                  'Réclamations',
                  Icons.support_rounded, // Changed to a more friendly support icon
                  () => context.go('/clientHome/reclamations'),
                  itemSize,
                  fontSize,
                  primaryColor,
                ),
                _buildQuickActionItem(
                  context,
                  isDarkMode,
                  'Conversations',
                  Icons.chat_bubble_rounded, // Changed to a more consistent chat icon
                  () => context.go('/clientHome/marketplace/chat'),
                  itemSize,
                  fontSize,
                  primaryColor,
                ),
              ],
            );
          }
        ),
      ],
    );
  }

  Widget _buildQuickActionItem(
    BuildContext context,
    bool isDarkMode,
    String label,
    IconData icon,
    VoidCallback onTap,
    [double size = 70.0, double fontSize = 12.0, Color? primaryColor]
  ) {
    primaryColor = primaryColor ?? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen);
    
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [       
            // Add a container with subtle border for visual separation
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              // Add a subtle border for visual separation
              border: Border.all(
                color: isDarkMode 
                    ? Colors.white.withOpacity(0.08) 
                    : Colors.black.withOpacity(0.05),
                width: 1.5,
              ),
              // Add a very subtle shadow for depth
              boxShadow: [
                BoxShadow(
                  color: isDarkMode 
                      ? Colors.black.withOpacity(0.1) 
                      : Colors.black.withOpacity(0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11), // Slightly smaller to account for border
                color: isDarkMode 
                    ? AppColors.darkBackground 
                    : AppColors.lightInputBackground,
              ),
              // Center the icon properly with alignment
              child: Center(
                child: Icon(
                  icon,
                  color: primaryColor,
                  size: size * 0.4, // Smaller icon (reduced from 0.45)
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Improved text container for better visibility
          Container(
            width: size + 20, // Wider to ensure text fits
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: isDarkMode 
                  ? Colors.black.withOpacity(0.2) 
                  : Colors.transparent, // Removed background in light mode
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: fontSize - 1, // Reduced font size by 1
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
              textAlign: TextAlign.center, // Center the text
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
        // Section title
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start, // Align to top for better layout with wrapped text
          children: [
            Expanded(  // Add Expanded to allow the column to take available space and wrap text
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nos services',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    'Découvrez une variété de services à votre disposition',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: isDarkMode ? Colors.white60 : Colors.black54,
                    ),
                    maxLines: 2, // Allow wrapping to 2 lines
                    overflow: TextOverflow.ellipsis, // Add ellipsis if text is too long
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                context.go('/clientHome/all-services');
              },
              child: Row(
                mainAxisSize: MainAxisSize.min, // Make row take minimum space
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
        
        const SizedBox(height: 16),
        
        // Search bar with lighter background
        Container(
          decoration: BoxDecoration(
            color: isDarkMode 
                ? AppColors.darkBackground.withOpacity(0.7) // Lighter in dark mode
                : AppColors.lightBackground, // Lighter than page background in light mode
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: MarketplaceSearch(
            controller: _searchController,
            onClear: _clearSearch,
            hintText: 'Trouvez un service...',
            onChanged: _onSearchChanged,
          ),
        ),
        
        const SizedBox(height: 16),
        
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
      height: 120, // Reduced height from 140 to 120
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
                padding: const EdgeInsets.only(right: 10.0),
                child: GestureDetector(
                  onTap: () {
                    context.go('/clientHome/service-providers/$serviceName');
                  },
                  child: Container(
                    width: 85, // Reduced from 90 to 85 for better proportions
                    decoration: BoxDecoration(
                      color: Colors.transparent, // Keep container transparent
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
                              // Remove background color completely to let page background show through
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
                                      padding: const EdgeInsets.all(8.0),
                                      child: Image.network(
                                        imageUrl,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Center(
                                            child: Icon(
                                              Icons.image_not_supported_rounded,
                                              color: isDarkMode ? Colors.white54 : Colors.black38,
                                              size: 24,
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
                                      size: 28, // Smaller icon size
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
  
  Widget _buildRecentMarketplaceSection(BuildContext context, bool isDarkMode, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Marketplace',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    'Explorez les offres récentes de notre communauté',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: isDarkMode ? Colors.white60 : Colors.black54,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () {
                context.go('/clientHome/marketplace');
              },
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
        
        const SizedBox(height: 16),
        
        // Marketplace items
        SizedBox(
          height: 240,
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('marketplace')
                .where('isValidated', isEqualTo: true)
                .orderBy('createdAt', descending: true)
                .limit(10)
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
                    'Erreur de chargement des produits',
                    style: GoogleFonts.poppins(color: Colors.red),
                  ),
                );
              }
              
              final items = snapshot.data?.docs ?? [];
              
              if (items.isEmpty) {
                return Center(
                  child: Text(
                    'Aucun produit disponible',
                    style: GoogleFonts.poppins(
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                );
              }
              
              // Select 6 random items
              List<DocumentSnapshot> randomItems = [];
              if (items.length <= 6) {
                randomItems = items;
              } else {
                // Create a copy of the items list to avoid modifying the original
                final availableItems = List<DocumentSnapshot>.from(items);
                final random = Random();
                
                while (randomItems.length < 6 && availableItems.isNotEmpty) {
                  final randomIndex = random.nextInt(availableItems.length);
                  randomItems.add(availableItems[randomIndex]);
                  availableItems.removeAt(randomIndex);
                }
              }
              
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: randomItems.length,
                itemBuilder: (context, index) {
                  final item = randomItems[index].data() as Map<String, dynamic>;
                  final itemId = randomItems[index].id;
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: SizedBox(
                      width: 180, // Add a fixed width to prevent infinite width error
                      child: MarketplaceCard(
                        id: itemId,
                        title: item['title'] ?? 'Sans titre',
                        price: (item['price'] ?? 0).toDouble(),
                        imageUrl: item['images'] != null && (item['images'] as List).isNotEmpty 
                            ? item['images'][0] 
                            : '',
                        condition: item['condition'] ?? 'Occasion',
                        location: item['location'] ?? 'Non spécifié',
                        onTap: () {
                          context.go('/clientHome/marketplace/details/$itemId');
                        },
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
