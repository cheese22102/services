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

class ClientHomePage extends StatefulWidget {
  const ClientHomePage({super.key});

  @override
  State<ClientHomePage> createState() => _ClientHomePageState();
}

class _ClientHomePageState extends State<ClientHomePage> {
  final int _selectedIndex = 0; // Home page is index 0
  String _firstName = '';
  String _gender = '';
  
  @override
  void initState() {
    super.initState();
    _checkAccess();
    _loadUserData();
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
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;
    
    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
      drawer: const Sidebar(),
      appBar: CustomAppBar(
        title: 'Accueil',
        showBackButton: false,
        showSidebar: true,
        showNotifications: true,
        backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome section with personalized greeting
                _buildWelcomeSection(isDarkMode),
                
                const SizedBox(height: 24),
                
                // Services section
                _buildServicesSection(context, isDarkMode, primaryColor),
                
                const SizedBox(height: 24),
                
                // Recent marketplace items
                _buildRecentMarketplaceSection(isDarkMode, primaryColor),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _selectedIndex,
      ),
    );
  }
  
  
  Widget _buildWelcomeSection(bool isDarkMode) {
    // Determine greeting based on gender
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
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode 
              ? [AppColors.darkBackground, Color(0xFF3A4D40)]
              : [AppColors.primaryDarkGreen.withOpacity(0.8), AppColors.primaryGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            style: GoogleFonts.poppins(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Que recherchez-vous aujourd\'hui ?',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.white.withOpacity(0.9),
              letterSpacing: 0.3,
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Nos services',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            TextButton(
              onPressed: () {
                context.go('/clientHome/all-services');
              },
              child: Row(
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
        
        // Horizontal swipeable services with improved UI
        SizedBox(
          height: 140, // Reduced height for smaller cards
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('services')
                .limit(6) // Limit to 6 services
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
                    padding: const EdgeInsets.only(right: 12.0),
                    child: GestureDetector(
                      onTap: () {
                        context.go('/clientHome/service-providers/$serviceName');
                      },
                      child: Container(
                        width: 120, // Smaller width for cards
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.grey.shade800 : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.06),
                              blurRadius: 6,
                              spreadRadius: 0.5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Service image with improved styling - fixed corners
                            Expanded(
                              flex: 3,
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                  color: primaryColor.withOpacity(0.1),
                                ),
                                width: double.infinity,
                                child: imageUrl != null && imageUrl.isNotEmpty
                                    ? ClipRRect(
                                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                        child: Image.network(
                                          imageUrl,
                                          fit: BoxFit.contain,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Center(
                                              child: Icon(
                                                Icons.image_not_supported_outlined,
                                                color: primaryColor,
                                                size: 28,
                                              ),
                                            );
                                          },
                                        ),
                                      )
                                    : Center(
                                        child: Icon(
                                          Icons.image_not_supported_outlined,
                                          color: primaryColor,
                                          size: 28,
                                        ),
                                      ),
                              ),
                            ),
                            
                            // Service name with improved styling
                            Expanded(
                              flex: 1,
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  child: Text(
                                    serviceName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12, // Smaller font size
                                      fontWeight: FontWeight.w500,
                                      color: isDarkMode ? Colors.white : Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
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
        ),
      ],
    );
  }
  
  Widget _buildRecentMarketplaceSection(bool isDarkMode, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Marketplace',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            TextButton(
              onPressed: () {
                context.go('/clientHome/marketplace');
              },
              child: Row(
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
        // Improved marketplace placeholder with better styling
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey.shade800.withOpacity(0.5) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.storefront_outlined,
                  size: 40,
                  color: primaryColor.withOpacity(0.7),
                ),
                const SizedBox(height: 12),
                Text(
                  'Découvrez les dernières annonces',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}