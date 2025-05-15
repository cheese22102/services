import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../front/app_colors.dart';
import '../../front/custom_app_bar.dart';
import 'dart:async';

class FavoriteProvidersPage extends StatefulWidget {
  const FavoriteProvidersPage({super.key});

  @override
  State<FavoriteProvidersPage> createState() => _FavoriteProvidersPageState();
}

class _FavoriteProvidersPageState extends State<FavoriteProvidersPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isLoading = true;
  List<Map<String, dynamic>> _favoriteProviders = [];
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  
  // Add a StreamSubscription to listen for changes
  StreamSubscription<QuerySnapshot>? _favoritesSubscription;

  @override
  void initState() {
    super.initState();
    _setupFavoritesListener();
  }

  @override
  void dispose() {
    _searchController.dispose();
    // Cancel the subscription when the widget is disposed
    _favoritesSubscription?.cancel();
    super.dispose();
  }
  
  // Set up a listener for changes to the favorites collection
  void _setupFavoritesListener() {
    if (currentUserId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    final favoritesRef = FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .collection('prestataires_favoris');
        
    _favoritesSubscription = favoritesRef.snapshots().listen((snapshot) {
      _loadFavoriteProviders();
    }, onError: (error) {
      print('Error listening to favorites: $error');
    });
    
    // Initial load
    _loadFavoriteProviders();
  }

  Future<void> _loadFavoriteProviders() async {
    if (currentUserId == null) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      // Get user's favorite providers from the prestataires_favoris subcollection
      final favoritesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('prestataires_favoris')
          .get();

      if (favoritesSnapshot.docs.isEmpty) {
        setState(() {
          _isLoading = false;
          _favoriteProviders = [];
        });
        return;
      }

      // Fetch provider data for each favorite
      List<Map<String, dynamic>> providers = [];
      
      // Use Future.wait to load providers in parallel
      final futures = favoritesSnapshot.docs.map((doc) async {
        final providerId = doc.id;
        final serviceName = doc.data()['serviceName'] as String? ?? '';
        
        try {
          // Get provider data
          final providerDoc = await FirebaseFirestore.instance
              .collection('providers')
              .doc(providerId)
              .get();
              
          if (providerDoc.exists) {
            final providerData = providerDoc.data() ?? {};
            final userId = providerData['userId'] as String?;
            
            if (userId != null) {
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userId)
                  .get();
                  
              if (userDoc.exists) {
                final userData = userDoc.data() ?? {};
                
                // Get provider's services
                List<String> services = [];
                if (providerData.containsKey('services') && 
                    providerData['services'] is List) {
                  services = List<String>.from(providerData['services']);
                }
                
                // Get provider's rating from the new rating field
                double rating = 0.0;
                int reviewCount = 0;
                
                if (providerData.containsKey('rating')) {
                  rating = (providerData['rating'] as num?)?.toDouble() ?? 0.0;
                }
                if (providerData.containsKey('reviewCount')) {
                  reviewCount = (providerData['reviewCount'] as num?)?.toInt() ?? 0;
                }
                
                if (providerData.containsKey('ratings') && 
                    providerData['ratings'] is Map<String, dynamic>) {
                  final ratings = providerData['ratings'] as Map<String, dynamic>;
                  if (ratings.containsKey('overall')) {
                    rating = (ratings['overall'] as num?)?.toDouble() ?? 0.0;
                  }
                  if (ratings.containsKey('reviewCount')) {
                    reviewCount = (ratings['reviewCount'] as num?)?.toInt() ?? 0;
                  }
                }
                
                return {
                  'providerId': providerId,
                  'firstName': userData['firstname'] ?? '',
                  'lastName': userData['lastname'] ?? '',
                  'photoURL': userData['photoURL'] ?? '',
                  'services': services,
                  'rating': rating,
                  'reviewCount': reviewCount,
                  'description': providerData['bio'] ?? 'Aucune description',
                  'serviceName': serviceName,
                };
              }
            }
          }
        } catch (e) {
          print('Error loading provider $providerId: $e');
        }
        return null;
      }).toList();
      
      // Wait for all futures to complete and filter out null results
      final results = await Future.wait(futures);
      providers = results.whereType<Map<String, dynamic>>().toList();
      
      if (mounted) {
        setState(() {
          _favoriteProviders = providers;
          _isLoading = false;
        });
      }
      
    } catch (e) {
      print('Error loading favorite providers: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _getFilteredProviders() {
    if (_searchQuery.isEmpty) {
      return _favoriteProviders;
    }
    
    return _favoriteProviders.where((provider) {
      final name = '${provider['firstName']} ${provider['lastName']}'.toLowerCase();
      final services = (provider['services'] as List<String>?)
          ?.map((s) => s.toLowerCase())
          .join(' ') ?? '';
      
      return name.contains(_searchQuery.toLowerCase()) || 
             services.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Prestataires favoris',
        showBackButton: true,
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher un prestataire...',
                hintStyle: GoogleFonts.poppins(
                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
                filled: true,
                fillColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          
          // Provider list with RefreshIndicator
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadFavoriteProviders,
              color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                      ),
                    )
                  : _buildProvidersList(isDarkMode),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildProvidersList(bool isDarkMode) {
    final filteredProviders = _getFilteredProviders();
    
    if (filteredProviders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 64,
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun prestataire favori',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Ajoutez des prestataires à vos favoris pour les retrouver ici',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredProviders.length,
      itemBuilder: (context, index) {
        final provider = filteredProviders[index];
        final providerId = provider['providerId'] as String;
        final firstName = provider['firstName'] as String;
        final lastName = provider['lastName'] as String;
        final photoURL = provider['photoURL'] as String;
        final services = provider['services'] as List<String>? ?? [];
        final rating = provider['rating'] as double;
        final reviewCount = provider['reviewCount'] as int;
        final description = provider['description'] as String;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: isDarkMode ? AppColors.darkInputBackground : Colors.white,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              context.push('/clientHome/provider-details/$providerId');
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Provider photo
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                            width: 2,
                          ),
                          image: photoURL.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(photoURL),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: photoURL.isEmpty
                            ? Icon(
                                Icons.person,
                                size: 30,
                                color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      
                      // Provider info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$firstName $lastName',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.star,
                                  size: 16,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$rating',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isDarkMode ? Colors.white : Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '($reviewCount avis)',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Services
                  if (services.isNotEmpty) ...[
                    Text(
                      'Services:',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: services.map((service) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDarkMode 
                              ? AppColors.primaryGreen.withOpacity(0.2) 
                              : AppColors.primaryDarkGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          service,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                  
                  const SizedBox(height: 12),
                  
                  // Description
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}