import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../front/app_colors.dart';
import '../../front/custom_app_bar.dart';
import '../../front/custom_button.dart';

class ServiceProvidersPage extends StatefulWidget {
  final String serviceName;

  const ServiceProvidersPage({
    super.key,
    required this.serviceName,
  });

  @override
  State<ServiceProvidersPage> createState() => _ServiceProvidersPageState();
}

class _ServiceProvidersPageState extends State<ServiceProvidersPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'rating'; // Default sort by rating
  bool _isAscending = false;
  Position? _currentPosition;
  bool _isLoading = true;
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  double _calculateDistance(GeoPoint providerLocation) {
    if (_currentPosition == null) return double.infinity;
    
    final double lat1 = _currentPosition!.latitude;
    final double lon1 = _currentPosition!.longitude;
    final double lat2 = providerLocation.latitude;
    final double lon2 = providerLocation.longitude;
    
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000; // Convert to km
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Prestataires de ${widget.serviceName}',
        showBackButton: true,
        backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
        titleColor: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        iconColor: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      ),
      body: Column(
        children: [
          // Search and filter section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: isDarkMode ? AppColors.darkInputBackground : AppColors.lightInputBackground,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un prestataire...',
                    hintStyle: GoogleFonts.poppins(
                      color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint,
                      fontSize: 14,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    filled: true,
                    fillColor: isDarkMode ? AppColors.darkInputBackground.withOpacity(0.7) : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDarkMode ? AppColors.darkBorderColor : AppColors.lightBorderColor,
                        width: 1,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDarkMode ? AppColors.darkBorderColor.withOpacity(0.3) : AppColors.lightBorderColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                  style: GoogleFonts.poppins(
                    color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    fontSize: 14,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
                
                const SizedBox(height: 12),
                
                // Sort options
                Row(
                  children: [
                    Text(
                      'Trier par:',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildSortChip('Note', 'rating', isDarkMode),
                    const SizedBox(width: 8),
                    _buildSortChip('Distance', 'distance', isDarkMode),
                    const Spacer(),
                    // Order toggle
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isAscending = !_isAscending;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDarkMode ? AppColors.darkInputBackground : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDarkMode ? AppColors.darkBorderColor.withOpacity(0.3) : AppColors.lightBorderColor.withOpacity(0.3),
                          ),
                        ),
                        child: Icon(
                          _isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 20,
                          color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Providers list
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                    ),
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('providers')
                        .where('status', isEqualTo: 'approved')
                        .where('services', arrayContains: widget.serviceName)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Une erreur est survenue: ${snapshot.error}',
                            style: GoogleFonts.poppins(
                              color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: CircularProgressIndicator(
                            color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                          ),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                size: 64,
                                color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Aucun prestataire disponible pour ce service',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Essayez un autre service ou revenez plus tard',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      // Filter providers by distance (less than 50km)
                      var providersWithinRange = snapshot.data!.docs.where((doc) {
                        if (_currentPosition == null) return true; // If no location, show all
                        
                        final data = doc.data() as Map<String, dynamic>;
                        if (data['exactLocation'] == null) return false;
                        
                        final lat = data['exactLocation']['latitude'];
                        final lng = data['exactLocation']['longitude'];
                        
                        if (lat == null || lng == null) return false;
                        
                        final location = GeoPoint(lat, lng);
                        final distance = _calculateDistance(location);
                        
                        return distance <= 50; // Only providers within 50km
                      }).toList();

                      if (providersWithinRange.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.location_off,
                                size: 64,
                                color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Aucun prestataire disponible dans un rayon de 50km',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Essayez un autre service ou élargissez votre zone de recherche',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        );
                      }

                      // Filter by search query
                      var filteredDocs = providersWithinRange.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        
                        // Use provider data directly since there's no userData field
                        final name = data['userId']?.toString().toLowerCase() ?? '';
                        final bio = data['bio']?.toString().toLowerCase() ?? '';
                        
                        return name.contains(_searchQuery) || bio.contains(_searchQuery);
                      }).toList();

                      // Sort the providers
                      filteredDocs.sort((a, b) {
                        final dataA = a.data() as Map<String, dynamic>;
                        final dataB = b.data() as Map<String, dynamic>;
                        
                        if (_sortBy == 'rating') {
                          // Get rating from ratings.overall or default to 0
                          final ratingA = dataA['ratings']?['overall'] ?? 0.0;
                          final ratingB = dataB['ratings']?['overall'] ?? 0.0;
                          return _isAscending ? ratingA.compareTo(ratingB) : ratingB.compareTo(ratingA);
                        } else if (_sortBy == 'distance' && _currentPosition != null) {
                          // Get location from exactLocation
                          GeoPoint? locationA;
                          GeoPoint? locationB;
                          
                          if (dataA['exactLocation'] != null) {
                            final lat = dataA['exactLocation']['latitude'];
                            final lng = dataA['exactLocation']['longitude'];
                            if (lat != null && lng != null) {
                              locationA = GeoPoint(lat, lng);
                            }
                          }
                          
                          if (dataB['exactLocation'] != null) {
                            final lat = dataB['exactLocation']['latitude'];
                            final lng = dataB['exactLocation']['longitude'];
                            if (lat != null && lng != null) {
                              locationB = GeoPoint(lat, lng);
                            }
                          }
                          
                          if (locationA == null || locationB == null) return 0;
                          
                          final distanceA = _calculateDistance(locationA);
                          final distanceB = _calculateDistance(locationB);
                          
                          return _isAscending ? distanceA.compareTo(distanceB) : distanceB.compareTo(distanceA);
                        }
                        
                        return 0;
                      });

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          final doc = filteredDocs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          
                          final providerId = doc.id;
                          
                          // Get provider name from userId - in a real app, you'd fetch the user's name
                          // from the users collection using the userId
                          final userId = data['userId'] ?? 'Unknown';
                          
                          // Fetch user data for this provider
                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                            builder: (context, userSnapshot) {
                              // Default values
                              String name = 'Prestataire';
                              String photoUrl = '';
                              
                              // If user data is available, use it
                              if (userSnapshot.hasData && userSnapshot.data != null) {
                                final userData = userSnapshot.data!.data() as Map<String, dynamic>?;
                                if (userData != null) {
                                  name = '${userData['firstname'] ?? ''} ${userData['lastname'] ?? ''}';
                                  photoUrl = userData['photoURL'] ?? '';
                                }
                              }
                              
                              final bio = data['bio'] ?? 'Aucune description disponible';
                              final rating = data['ratings']?['overall'] ?? 0.0;
                              final reviewCount = data['reviewCount'] ?? 0;
                              
                              // Calculate distance if location is available
                              String distanceText = 'Distance inconnue';
                              if (_currentPosition != null && data['exactLocation'] != null) {
                                final lat = data['exactLocation']['latitude'];
                                final lng = data['exactLocation']['longitude'];
                                if (lat != null && lng != null) {
                                  final location = GeoPoint(lat, lng);
                                  final distance = _calculateDistance(location);
                                  distanceText = '${distance.toStringAsFixed(1)} km';
                                }
                              }
                              
                              return _buildProviderCard(
                                context,
                                isDarkMode,
                                providerId,
                                name,
                                photoUrl,
                                bio,
                                rating,
                                reviewCount,
                                distanceText,
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
          ),
    ],
    
    ));
  }

  Widget _buildSortChip(String label, String value, bool isDarkMode) {
    final isSelected = _sortBy == value;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _sortBy = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
              : (isDarkMode ? AppColors.darkInputBackground : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                : (isDarkMode ? AppColors.darkBorderColor.withOpacity(0.3) : AppColors.lightBorderColor.withOpacity(0.3)),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected
                ? (isDarkMode ? Colors.white : Colors.white)
                : (isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildProviderCard(
    BuildContext context,
    bool isDarkMode,
    String providerId,
    String name,
    String photoUrl,
    String bio,
    double rating,
    int reviewCount,
    String distance,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: isDarkMode ? AppColors.darkInputBackground : Colors.white,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        // In your provider card's onTap method:
        onTap: () {
        // Navigate to provider profile
        context.push('/clientHome/provider-details/$providerId', extra: widget.serviceName);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Provider avatar
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: isDarkMode ? AppColors.darkBorderColor : AppColors.lightBorderColor,
                    backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                    child: photoUrl.isEmpty
                        ? Icon(
                            Icons.person,
                            size: 32,
                            color: isDarkMode ? Colors.white70 : Colors.black54,
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
                          name,
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        
                        // Rating
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              size: 18,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              rating.toStringAsFixed(1),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '($reviewCount avis)',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 4),
                        
                        // Distance
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 16,
                              color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              distance,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
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
              
              // Bio
              Text(
                bio,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 16),
              
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Message button
                  CustomButton(
                    onPressed: () {
                      // Start a conversation with this provider
                      _startConversation(context, providerId, name);
                    },
                    text: 'Contacter',
                    backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                    textColor: Colors.white,
                    height: 36,
                    width: 120,
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // View profile button
                  CustomButton(
                    onPressed: () {
                      context.go('/clientHome/provider-details/$providerId', 
                        extra: {'serviceName': widget.serviceName});
                    },
                    text: 'Voir profil',
                    backgroundColor: Colors.transparent,
                    textColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                    height: 36,
                    width: 120,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startConversation(BuildContext context, String providerId, String providerName) async {
    if (currentUserId == null) return;
    
    try {
      // Check if a conversation already exists
      final conversationsQuery = await FirebaseFirestore.instance
          .collection('conversations')
          .where('participants', arrayContains: currentUserId)
          .get();
      
      String? existingConversationId;
      
      for (var doc in conversationsQuery.docs) {
        final participants = List<String>.from(doc['participants']);
        if (participants.contains(providerId)) {
          existingConversationId = doc.id;
          break;
        }
      }
      
      if (existingConversationId != null) {
        // Navigate to existing conversation
        if (!mounted) return;
    
      } else {
        // Create a new conversation
        final newConversationRef = FirebaseFirestore.instance.collection('conversations').doc();
        
        await newConversationRef.set({
          'participants': [currentUserId, providerId],
          'lastMessage': null,
          'lastMessageTime': null,
          'createdAt': FieldValue.serverTimestamp(),
          'serviceId': widget.serviceName,
        });
        
        if (!mounted) return;
      
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }
}