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
        // backgroundColor removed to use default from CustomAppBar
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
      child: Column( // Removed Container, direct Column for centering
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 70, // Define a fixed size for the image container
            height: 70,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12), // Rounded corners for the image
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
                        color: isDarkMode ? Colors.grey.shade800.withOpacity(0.5) : Colors.grey.shade200,
                        child: Icon(icon, color: primaryColor, size: 35),
                      ),
                    )
                  : Container(
                      color: isDarkMode ? Colors.grey.shade800.withOpacity(0.5) : Colors.grey.shade200,
                      child: Icon(icon, color: primaryColor, size: 35),
                    ),
            ),
          ),
          const SizedBox(height: 8), // Spacing between image and text
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: Text(
              serviceName,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 12, 
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
