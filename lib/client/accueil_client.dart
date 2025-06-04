import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/auth_helper.dart';
import '../front/sidebar.dart';
import 'package:go_router/go_router.dart';
import '../front/custom_bottom_nav.dart';
import '../front/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import '../front/marketplace_search.dart';
import 'dart:async';
import 'package:intl/intl.dart'; // Added for DateFormat
import '../notifications_service.dart';

class ClientHomePage extends StatefulWidget {
  const ClientHomePage({super.key});

  @override
  State<ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<ClientHomePage> {
  final int _selectedIndex = 0; // Home page is index 0
  String _firstName = '';
  String _userId = ''; // Added for fetching user-specific reservations
  bool _hasUnreadNotifications = false; // New state variable for unread notifications
  StreamSubscription<int>? _unreadNotificationsSubscription; // Subscription for notifications
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _checkAccess();
    _loadUserData();
    // Initialize notification stream
    _unreadNotificationsSubscription = NotificationsService.getTotalUnreadNotificationsCount().listen((count) {
      if (mounted && _hasUnreadNotifications != (count > 0)) { // Check if mounted
        setState(() {
          _hasUnreadNotifications = count > 0;
        });
      }
    });
  }

  @override
  void dispose() {
    _unreadNotificationsSubscription?.cancel(); // Cancel subscription
    _searchController.dispose();
    super.dispose();
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
      _searchQuery = query.trim(); // Trim whitespace
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
          _userId = user.uid; // Set userId here
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
      backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightInputBackground, // Updated light mode background
      drawer: const Sidebar(),
      body: SafeArea(
        child: RefreshIndicator(
          color: primaryColor,
          onRefresh: () async {
            await _loadUserData();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopHeaderSection(context, isDarkMode, primaryColor),
                
                Padding(
                  padding: padding,
                  child: _searchQuery.isEmpty
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: mediaQuery.size.width > 600 ? 32 : 24),
                            _buildServiceAndMarketplaceCards(context, isDarkMode, primaryColor),
                            SizedBox(height: mediaQuery.size.width > 600 ? 32 : 24),
                            _buildServicesSection(context, isDarkMode, primaryColor),
                            SizedBox(height: mediaQuery.size.width > 600 ? 32 : 24),
                            _buildRecentReservationsSection(context, isDarkMode, primaryColor), // Moved here
                            SizedBox(height: mediaQuery.size.width > 600 ? 32 : 24), // Add spacing
                            _buildRecentMarketplaceSection(context, isDarkMode, primaryColor),
                          ],
                        )
                      : _buildCombinedSearchResults(context, isDarkMode, primaryColor),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _selectedIndex,
        backgroundColor: isDarkMode ? Colors.grey.shade900 : Colors.white, // Explicitly set to match AppBar/BottomNav defaults
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
              context.go('/clientHome/chatbot'); // Navigate to chatbot page
            },
            backgroundColor: Colors.transparent, // Make FAB transparent
            elevation: 0, // Remove default elevation to avoid color overlap
            shape: CircleBorder(), // Ensure it's perfectly rounded
            child: Icon(Icons.smart_toy_rounded, color: Colors.white, size: 32), // Icon color remains white
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat, // Position at bottom right
    );
  }
  
  Widget _buildTopHeaderSection(BuildContext context, bool isDarkMode, Color primaryColor) {
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 400;
    
    String greeting = 'Bonjour !';
    if (_firstName.isNotEmpty) {
      greeting = 'Bonjour $_firstName !';
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: mediaQuery.padding.top + 16,
        left: 24,
        right: 24,
        bottom: 24,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [Color(0xFF1E2923), Color(0xFF3A4D40)]
              : [AppColors.primaryGreen, AppColors.primaryDarkGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Builder( // Added Builder to get a context that is a descendant of Scaffold
                builder: (BuildContext innerContext) {
                  return IconButton(
                    icon: Icon(Icons.menu, color: Colors.white, size: isSmallScreen ? 24 : 28),
                    onPressed: () {
                      Scaffold.of(innerContext).openDrawer(); // Use innerContext
                    },
                  );
                },
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greeting,
                        style: GoogleFonts.poppins(
                          fontSize: isSmallScreen ? 22 : 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Comment pouvons-nous vous aider aujourd\'hui ?',
                        style: GoogleFonts.poppins(
                          fontSize: isSmallScreen ? 12 : 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Stack(
                children: [
                  IconButton(
                    icon: Icon(Icons.notifications_none_rounded, color: Colors.white, size: isSmallScreen ? 24 : 28),
                    onPressed: () {
                      context.go('/clientHome/notifications');
                    },
                  ),
                  if (_hasUnreadNotifications) // Conditionally show red dot
                    Positioned(
                      top: 6, // Adjusted position
                      right: 6, // Adjusted position
                      child: Container(
                        width: 12, // Increased size
                        height: 12, // Increased size
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDarkMode ? Colors.grey.shade900 : Colors.white,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            height: 50,
            decoration: BoxDecoration(
              // Use page background colors with some opacity
              color: isDarkMode 
                  ? AppColors.darkBackground.withOpacity(0.2) 
                  : AppColors.lightInputBackground.withOpacity(0.2),
              borderRadius: BorderRadius.circular(15), // Match MarketplaceSearch's border radius
              // No separate shadow here, rely on MarketplaceSearch's internal styling if any, or let it blend
            ),
            child: MarketplaceSearch(
              controller: _searchController,
              onClear: _clearSearch,
              hintText: 'Rechercher des services ou produits...',
              onChanged: _onSearchChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceAndMarketplaceCards(BuildContext context, bool isDarkMode, Color primaryColor) {
    return Row(
      children: [
        Expanded(
          child: _buildLargeCard(
            context,
            isDarkMode,
            'Services',
            'Réserver maintenant',
            Icons.build_circle_outlined,
            () => context.go('/clientHome/all-services'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildLargeCard(
            context,
            isDarkMode,
            'Marketplace',
            'Acheter & Vendre',
            Icons.shopping_cart_outlined,
            () => context.go('/clientHome/marketplace'),
          ),
        ),
      ],
    );
  }

  Widget _buildLargeCard(
    BuildContext context,
    bool isDarkMode,
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? AppColors.primaryDarkGreen : AppColors.primaryGreen,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: Colors.white, size: 36),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildServicesSection(BuildContext context, bool isDarkMode, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Services populaires',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              Semantics(
                label: 'Voir tous les services',
                hint: 'Naviguer vers la page de tous les services',
                button: true,
                child: TextButton(
                  onPressed: () {
                    context.go('/clientHome/all-services');
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    minimumSize: const Size(44, 44),
                    tapTargetSize: MaterialTapTargetSize.padded,
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
              ),
            ],
          ),
        ),
        _buildServicesGrid(isDarkMode, primaryColor),
      ],
    );
  }
  
  Stream<QuerySnapshot> _getServicesStream(String searchQuery) {
    Query query = FirebaseFirestore.instance.collection('services');
    if (searchQuery.isNotEmpty) {
      // For search, fetch all services ordered by name, then filter client-side
      query = query.orderBy('name');
    } else {
      // For "popular services" display on home page without search
      query = query.orderBy('name').limit(4); // Limit to 4 services for one row
    }
    return query.snapshots();
  }

  Widget _buildServicesGrid(bool isDarkMode, Color primaryColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getServicesStream(_searchQuery),
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
              'Erreur de chargement des services: ${snapshot.error}',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          );
        }
        
        final services = snapshot.data?.docs ?? [];
        
        if (services.isEmpty) {
          return Center(
            child: Text(
              _searchQuery.isEmpty ? 'Aucun service disponible' : 'Aucun service trouvé pour "$_searchQuery"',
              style: GoogleFonts.poppins(
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          );
        }
        
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4, // Display 4 services in a row
            crossAxisSpacing: 8, // Adjust spacing for 4 items
            mainAxisSpacing: 8, // Adjust spacing for 4 items
            childAspectRatio: 0.85, // Adjust aspect ratio for smaller items
          ),
          itemCount: services.length,
          itemBuilder: (context, index) {
            final service = services[index].data() as Map<String, dynamic>;
            final serviceName = service['name'] as String? ?? 'Service';
            final imageUrl = service['imageUrl'] as String?;
            
            return GestureDetector(
              onTap: () {
                context.go('/clientHome/service-providers/$serviceName');
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 50, // Reduced image size for 4 items
                    height: 50, // Reduced image size for 4 items
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10), // Slightly smaller radius
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity, // Ensure image fills the ClipRRect
                              height: double.infinity,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                    strokeWidth: 2.0, 
                                    color: primaryColor,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) => Container( 
                                color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                                child: Icon(Icons.broken_image, color: primaryColor, size: 24), // Smaller icon
                              ),
                            )
                          : Container( 
                              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                              child: Icon(Icons.home_repair_service_rounded, color: primaryColor, size: 24), // Smaller icon
                            ),
                    ),
                  ),
                  const SizedBox(height: 6), // Reduced spacing
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2.0), 
                    child: Text(
                      serviceName,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 10, // Reduced font size for smaller items
                        fontWeight: FontWeight.w500, 
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                      maxLines: 2, // Allow for two lines for longer names
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  Stream<QuerySnapshot> _getMarketplaceStream(String searchQuery) {
    Query query = FirebaseFirestore.instance.collection('marketplace');
    if (searchQuery.isNotEmpty) {
      final lowerCaseQuery = searchQuery.toLowerCase();
      query = query.where('title', isGreaterThanOrEqualTo: lowerCaseQuery)
                   .where('title', isLessThanOrEqualTo: '$lowerCaseQuery\uf8ff');
    } else {
      query = query.orderBy('createdAt', descending: true).limit(6);
    }
    return query.snapshots();
  }

  Widget _buildRecentMarketplaceSection(BuildContext context, bool isDarkMode, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        SizedBox(
          height: 200, // Increased height for better card display
          child: StreamBuilder<QuerySnapshot>(
            stream: _getMarketplaceStream(_searchQuery),
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
                    'Erreur de chargement des annonces: ${snapshot.error}',
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
                        _searchQuery.isEmpty ? 'Aucune annonce disponible' : 'Aucune annonce trouvée pour "$_searchQuery"',
                        style: GoogleFonts.poppins(
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                );
              }
              
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: posts.length,
                clipBehavior: Clip.none, // Allow shadows to render outside bounds
                itemBuilder: (context, index) {
                  final post = posts[index].data() as Map<String, dynamic>;
                  final postId = posts[index].id;
                  
                  return Padding(
                    padding: const EdgeInsets.only(right: 16.0), // Increased spacing
                    child: GestureDetector(
                      onTap: () {
                        context.go('/clientHome/marketplace/post/$postId');
                      },
                      child: Container(
                        width: 150, // Increased card width
                        decoration: BoxDecoration(
                          color: isDarkMode ? AppColors.darkCardBackground : AppColors.lightCardBackground, // Updated card color
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1), // Enhanced shadow
                              blurRadius: 8, // Consistent blurRadius
                              offset: const Offset(0, 4), // Consistent offset
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                            
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
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
                                  Text(
                                    '${post['price'] ?? 0} DT',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
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

  // NEW SECTION: Recent Reservations
  Stream<List<Map<String, dynamic>>> _getReservationsStream(String userId) {
    if (userId.isEmpty) {
      return Stream.value([]); // Return empty list if no user ID
    }
    return FirebaseFirestore.instance
        .collection('reservations')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(3) // Limit to 3 newest reservations
        .snapshots()
        .asyncMap((snapshot) async {
      List<Map<String, dynamic>> reservationsWithServiceData = [];
      for (var doc in snapshot.docs) {
        final reservationData = doc.data();
        final serviceId = reservationData['serviceId'] as String?;
        final providerId = reservationData['providerId'] as String?; // Fetch providerId
        String? serviceImageUrl;
        String providerName = 'Prestataire Inconnu'; // Default

        if (serviceId != null && serviceId.isNotEmpty) { // Added isNotEmpty check
          final serviceDoc = await FirebaseFirestore.instance.collection('services').doc(serviceId).get();
          if (serviceDoc.exists) {
            serviceImageUrl = serviceDoc.data()?['imageUrl'] as String?;
          }
        }

        if (providerId != null) {
          final providerDoc = await FirebaseFirestore.instance.collection('users').doc(providerId).get();
          if (providerDoc.exists) {
            final userData = providerDoc.data() as Map<String, dynamic>;
            providerName = '${userData['firstname'] ?? ''} ${userData['lastname'] ?? ''}'.trim();
            providerName = providerName.isEmpty ? 'Prestataire Inconnu' : providerName;
          }
        }

        reservationsWithServiceData.add({
          ...reservationData,
          'id': doc.id,
          'serviceImageUrl': serviceImageUrl,
          'fetchedProviderName': providerName, // Add fetched provider name
        });
      }
      return reservationsWithServiceData;
    });
  }

  Widget _buildReservationCard(
      BuildContext context,
      Map<String, dynamic> reservation,
      bool isDarkMode,
      Color primaryColor) {
    final serviceName = reservation['serviceName'] as String? ?? 'Service Inconnu';
    final providerName = reservation['fetchedProviderName'] as String? ?? 'Prestataire Inconnu'; // Use fetched name
    final scheduledDate = reservation['scheduledDate'] as Timestamp?; // Use Timestamp
    final status = reservation['status'] as String? ?? 'pending'; // Default to 'pending'

    String formattedDate = 'Date Inconnue';
    if (scheduledDate != null) {
      try {
        formattedDate = DateFormat('dd/MM/yyyy à HH:mm').format(scheduledDate.toDate());
      } catch (e) {
        print('Error formatting date: $e');
      }
    }

    Color statusColor;
    String statusText;
    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusText = 'Acceptée';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusText = 'Annulée';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'Refusée';
        break;
      case 'completed':
        statusColor = Colors.blue;
        statusText = 'Terminée';
        break;
      case 'pending':
      default:
        statusColor = Colors.orange;
        statusText = 'En attente';
        break;
    }
    
    final serviceImageUrl = reservation['serviceImageUrl'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(12.0),
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
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: serviceImageUrl != null && serviceImageUrl.isNotEmpty
                  ? Image.network(
                      serviceImageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2.0,
                            color: primaryColor,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                        child: Icon(Icons.broken_image, color: primaryColor, size: 24),
                      ),
                    )
                  : Container(
                      color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                      child: Icon(Icons.home_repair_service_rounded, color: primaryColor, size: 24),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  serviceName,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'avec $providerName',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  formattedDate, // Use formatted date
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: isDarkMode ? Colors.white54 : Colors.black45,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2), // Use opacity for background
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor, width: 1), // Add border
            ),
            child: Text(
              statusText, // Use statusText
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: statusColor, // Use statusColor for text
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentReservationsSection(BuildContext context, bool isDarkMode, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Réservations récentes',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              TextButton(
                onPressed: () {
                  context.go('/clientHome/my-reservations'); // Assuming a route for all reservations
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
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: _getReservationsStream(_userId), // Use _userId from state
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: primaryColor));
            }
            if (snapshot.hasError) {
              return Center(child: Text('Erreur de chargement des réservations: ${snapshot.error}', style: GoogleFonts.poppins(color: Colors.red)));
            }
            final reservations = snapshot.data ?? []; // Directly use the list
            if (reservations.isEmpty) {
              return const SizedBox.shrink(); // Hide the section if no reservations
            }
            return Column(
              children: reservations.map((reservationData) {
                return _buildReservationCard(context, reservationData, isDarkMode, primaryColor);
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCombinedSearchResults(BuildContext context, bool isDarkMode, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_searchQuery.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Text(
              'Résultats de recherche pour "$_searchQuery"',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
          // Services Results
          Text(
            'Services',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: _getServicesStream(_searchQuery),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: primaryColor));
              }
              if (snapshot.hasError) {
                return Center(child: Text('Erreur de chargement des services: ${snapshot.error}', style: GoogleFonts.poppins(color: Colors.red)));
              }
              
              var services = snapshot.data?.docs ?? []; // Changed to var

              if (_searchQuery.isNotEmpty && snapshot.hasData) {
                final lowerCaseQuery = _searchQuery.toLowerCase();
                services = services.where((doc) {
                  final serviceData = doc.data() as Map<String, dynamic>;
                  final serviceName = (serviceData['name'] as String? ?? '').toLowerCase();
                  final serviceDescription = (serviceData['description'] as String? ?? '').toLowerCase();
                  return serviceName.contains(lowerCaseQuery) || serviceDescription.contains(lowerCaseQuery);
                }).toList();
              }

              if (services.isEmpty) {
                return Center(child: Text('Aucun service trouvé pour "$_searchQuery"', style: GoogleFonts.poppins(color: isDarkMode ? Colors.grey[400] : Colors.grey[600])));
              }
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4, // Display 4 services in a row, same as popular
                  crossAxisSpacing: 8, // Match popular services
                  mainAxisSpacing: 8,  // Match popular services
                  childAspectRatio: 0.85, // Match popular services
                ),
                itemCount: services.length,
                itemBuilder: (context, index) {
                  final serviceData = services[index].data() as Map<String, dynamic>;
                  final serviceName = serviceData['name'] as String? ?? 'Service';
                  final imageUrl = serviceData['imageUrl'] as String?;
                  
                  return GestureDetector(
                    onTap: () {
                      context.go('/clientHome/service-providers/$serviceName');
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 50, // Match popular services image size
                          height: 50, // Match popular services image size
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10), // Match popular services radius
                            child: imageUrl != null && imageUrl.isNotEmpty
                                ? Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: double.infinity,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded /
                                                  loadingProgress.expectedTotalBytes!
                                              : null,
                                          strokeWidth: 2.0, 
                                          color: primaryColor,
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) => Container( 
                                      color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                                      child: Icon(Icons.broken_image, color: primaryColor, size: 24), // Match popular
                                    ),
                                  )
                                : Container( 
                                    color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                                    child: Icon(Icons.home_repair_service_rounded, color: primaryColor, size: 24), // Match popular
                                  ),
                          ),
                        ),
                        const SizedBox(height: 6), // Match popular services spacing
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2.0), // Match popular services padding
                          child: Text(
                            serviceName,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 10, // Match popular services font size
                              fontWeight: FontWeight.w500, 
                              color: isDarkMode ? Colors.white70 : Colors.black87, // Match popular services color
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
          const SizedBox(height: 24),
          // Marketplace Results
          Text(
            'Marketplace',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 200, // Consistent height with "Recent Marketplace" section
            child: StreamBuilder<QuerySnapshot>(
              stream: _getMarketplaceStream(_searchQuery),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator(color: primaryColor));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Erreur de chargement des annonces: ${snapshot.error}', style: GoogleFonts.poppins(color: Colors.red)));
                }
                final posts = snapshot.data?.docs ?? [];
                if (posts.isEmpty) {
                  return Center(child: Text('Aucune annonce trouvée pour "$_searchQuery"', style: GoogleFonts.poppins(color: isDarkMode ? Colors.grey[400] : Colors.grey[600])));
                }
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: posts.length,
                  clipBehavior: Clip.none, // Allow shadows to render outside bounds
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
                          width: 140,
                          decoration: BoxDecoration(
                            color: isDarkMode ? AppColors.darkCardBackground : AppColors.lightCardBackground, // Updated card color
                            borderRadius: BorderRadius.circular(12),

                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
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
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
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
                                    Text(
                                      '${post['price'] ?? 0} DT',
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
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
      ],
    );
  }
}
