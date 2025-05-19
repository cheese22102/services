import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../front/app_colors.dart';
import '../../front/custom_app_bar.dart';
import '../../front/sidebar.dart';
import '../../front/custom_bottom_nav.dart';
import '../../front/marketplace_search.dart';



class AllServicesPage extends StatefulWidget {
  const AllServicesPage({super.key});

  @override
  State<AllServicesPage> createState() => _AllServicesPageState();
}

class _AllServicesPageState extends State<AllServicesPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
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
      _searchQuery = query;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;

    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightInputBackground,
      drawer: const Sidebar(),
      appBar: CustomAppBar(
        title: 'Tous les services',
        showBackButton: false, // Change to false since we're showing sidebar
        showSidebar: true, // Add sidebar
        showNotifications: true, // Add notifications
        backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              // Search bar with updated styling
              MarketplaceSearch(
                controller: _searchController,
                onClear: _clearSearch,
                hintText: 'Rechercher un service...',
                onChanged: _onSearchChanged,
              ),
              
              const SizedBox(height: 24),
              
              // Services grid
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('services')
                      .snapshots(), // No ordering to show first added first
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Erreur de chargement des services',
                          style: GoogleFonts.poppins(color: Colors.red),
                        ),
                      );
                    }
                    
                    final allServices = snapshot.data?.docs ?? [];
                    
                    // Filter services based on search query
                    final filteredServices = _searchQuery.isEmpty
                        ? allServices
                        : allServices.where((service) {
                            final serviceData = service.data() as Map<String, dynamic>;
                            final name = (serviceData['name'] as String? ?? '').toLowerCase();
                            return name.contains(_searchQuery);
                          }).toList();
                    
                    if (filteredServices.isEmpty) {
                      return Center(
                        child: Text(
                          'Aucun service trouvé',
                          style: GoogleFonts.poppins(
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      );
                    }
                    
                    // Display services in a grid (3 per row)
                    return GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 0.8,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: filteredServices.length,
                      itemBuilder: (context, index) {
                        final serviceDoc = filteredServices[index];
                        final service = serviceDoc.data() as Map<String, dynamic>;
                        final serviceName = service['name'] as String? ?? 'Service sans nom';
                        final serviceIcon = _getServiceIcon(serviceName);
                        final imageUrl = service['imageUrl'] as String?;
                        
                        return _buildServiceGridItem(
                          context,
                          serviceName,
                          serviceIcon,
                          isDarkMode,
                          primaryColor,
                          imageUrl,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const CustomBottomNav(
        currentIndex: 1, // Set to 1 for Services tab
      ),
    );
  }
  
  Widget _buildServiceGridItem(
    BuildContext context,
    String serviceName,
    IconData icon,
    bool isDarkMode,
    Color primaryColor,
    String? imageUrl,
  ) {
    return GestureDetector(
      onTap: () {
        context.go('/clientHome/service-providers/$serviceName');
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey.shade800 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Service image with improved styling
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  color: isDarkMode 
                      ? AppColors.darkBackground 
                      : AppColors.lightInputBackground,
                ),
                width: double.infinity,
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Icon(
                                  icon,
                                  size: 40,
                                  color: primaryColor,
                                ),
                              );
                            },
                          ),
                        ),
                      )
                    : Center(
                        child: Icon(
                          icon,
                          size: 40,
                          color: primaryColor,
                        ),
                      ),
              ),
            ),
            
            // Service name with improved styling
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                serviceName,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  IconData _getServiceIcon(String serviceName) {
    switch (serviceName.toLowerCase()) {
      case 'plomberie':
        return Icons.plumbing;
      case 'électricité':
        return Icons.electrical_services;
      case 'jardinage':
        return Icons.yard;
      case 'ménage':
        return Icons.cleaning_services;
      case 'peinture':
        return Icons.format_paint;
      case 'menuiserie':
        return Icons.handyman;
      case 'informatique':
        return Icons.computer;
      case 'déménagement':
        return Icons.local_shipping;
      case 'réparation':
        return Icons.build;
      default:
        return Icons.miscellaneous_services;
    }
  }
}