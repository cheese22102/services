import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../front/app_colors.dart';
import '../../front/custom_app_bar.dart';
import '../../front/custom_button.dart';
import 'package:go_router/go_router.dart';
import '../../utils/image_gallery_utils.dart';
import 'package:intl/intl.dart';
import 'dart:async';


class ProviderProfilePage extends StatefulWidget {
  final String providerId;
  final String serviceName;

  const ProviderProfilePage({
    super.key,
    required this.providerId, this.serviceName = '',

  });


  @override
  State<ProviderProfilePage> createState() => _ProviderProfilePageState();
}

class _ProviderProfilePageState extends State<ProviderProfilePage> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  List<Map<String, dynamic>> _reviews = [];
  double _averageRating = 0.0;
  bool _isFavorite = false;
  late TabController _tabController;
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  bool _hasActiveReservation = false;
  bool _checkingReservation = true;
  StreamSubscription<QuerySnapshot>? _reservationSubscription;
  
  // Data storage
  Map<String, dynamic> _providerData = {};
  Map<String, dynamic> _userData = {};
  String _serviceName = '';

  // Detailed ratings
  double _qualityRating = 0.0;
  double _timelinessRating = 0.0;
  double _priceRating = 0.0;
  int _reviewCount = 0;

  List<String> _projectImages = [];

  // Location data
  double? _latitude;
  double? _longitude;
  String _address = '';
  final MapController _mapController = MapController();
  

    @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // Updated to 3 tabs
    _fetchProviderData();
    _setupReservationListener();
  }

  @override
  void dispose() {
    _reservationSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

    Future<void> _fetchProviderData() async {
    try {
      // Get provider data from providers collection
      final providerDoc = await FirebaseFirestore.instance
          .collection('providers')
          .doc(widget.providerId)
          .get();
      
      if (!providerDoc.exists) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      final providerData = providerDoc.data() ?? {};
      
      // Get user data using the userId field from provider data
      final userId = providerData['userId'] as String?;
      if (userId == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (!userDoc.exists) {
        setState(() {
          _isLoading = false;
        });
        return;
      }
      
      final userData = userDoc.data() ?? {};
      
      // Determine service name if possible
      String serviceName = '';
      if (providerData.containsKey('services') && 
          providerData['services'] is List && 
          (providerData['services'] as List).isNotEmpty) {
        serviceName = (providerData['services'] as List).first.toString();
      }
      
      // Extract location data
      double? latitude;
      double? longitude;
      String address = 'Adresse non spécifiée';
      
      if (providerData.containsKey('exactLocation') && 
          providerData['exactLocation'] is Map<String, dynamic>) {
        final locationData = providerData['exactLocation'] as Map<String, dynamic>;
        latitude = locationData['latitude'] as double?;
        longitude = locationData['longitude'] as double?;
        address = locationData['address'] as String? ?? 'Adresse non spécifiée';
      }
      
      // Extract project photos
      List<String> projectImages = [];
      if (providerData.containsKey('projectPhotos') && 
          providerData['projectPhotos'] is List) {
        projectImages = List<String>.from(providerData['projectPhotos']);
      }
      
      // Extract working days and hours
      
      if (providerData.containsKey('workingDays') && 
          providerData['workingDays'] is Map<String, dynamic>) {
      }
      
      if (providerData.containsKey('workingHours') && 
          providerData['workingHours'] is Map<String, dynamic>) {
      }
      
      setState(() {
        _providerData = providerData;
        _userData = userData;
        _serviceName = serviceName;
        _latitude = latitude;
        _longitude = longitude;
        _address = address;
        _projectImages = projectImages; // Store project images
        // No need to create separate state variables for workingDays and workingHours
        // as they're already part of _providerData
      });
      
      // Now load reviews and check favorites
      await _loadData();
      
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }
   Future<void> _loadData() async {
    try {
      // Check if provider is in favorites
      if (currentUserId != null) {
        final favDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('prestataires_favoris')
            .doc(widget.providerId)
            .get();
        
        setState(() {
          _isFavorite = favDoc.exists;
        });
      }
      
      // Load ratings from the subcollection
      final ratingsDoc = await FirebaseFirestore.instance
          .collection('providers')
          .doc(widget.providerId)
          .collection('ratings')
          .doc('stats')
          .get();
      
      if (ratingsDoc.exists) {
        final ratingsData = ratingsDoc.data() ?? {};
        
        setState(() {
          // Get quality ratings
          if (ratingsData['quality'] != null) {
            _qualityRating = (ratingsData['quality']['average'] as num?)?.toDouble() ?? 0.0;
          }
          
          // Get timeliness ratings
          if (ratingsData['timeliness'] != null) {
            _timelinessRating = (ratingsData['timeliness']['average'] as num?)?.toDouble() ?? 0.0;
          }
          
          // Get price ratings
          if (ratingsData['price'] != null) {
            _priceRating = (ratingsData['price']['average'] as num?)?.toDouble() ?? 0.0;
          }
          
          // Get review count
          _reviewCount = (ratingsData['reviewCount'] as num?)?.toInt() ?? 0;
        });
      }
      
      // Get overall rating from the main provider document
      if (_providerData.containsKey('rating')) {
        _averageRating = (_providerData['rating'] as num?)?.toDouble() ?? 0.0;
      }
      
      // Load reviews from the subcollection
      final reviewsSnapshot = await FirebaseFirestore.instance
          .collection('providers')
          .doc(widget.providerId)
          .collection('ratings')
          .doc('reviews')
          .collection('items')
          .orderBy('createdAt', descending: true)
          .get();
          
      setState(() {
        _reviews = reviewsSnapshot.docs.map((doc) => doc.data()).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (currentUserId == null) return;

    setState(() {
      _isFavorite = !_isFavorite;
    });

    try {
      final favRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('prestataires_favoris')
          .doc(widget.providerId);

      if (_isFavorite) {
        // Add to favorites
        await favRef.set({
          'providerId': widget.providerId,
          'addedAt': FieldValue.serverTimestamp(),
          'serviceName': _serviceName,
        });
      } else {
        // Remove from favorites
        await favRef.delete();
      }
    } catch (e) {
      // Revert state if operation fails
      setState(() {
        _isFavorite = !_isFavorite;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }
  
  Future<void> _checkActiveReservations() async {
    if (currentUserId == null) {
      setState(() {
        _checkingReservation = false;
      });
      return;
    }
    
    try {
      final reservationsQuery = await FirebaseFirestore.instance
          .collection('reservations')
          .where('userId', isEqualTo: currentUserId)
          .where('providerId', isEqualTo: widget.providerId)
          .where('status', isEqualTo: 'pending')
          .get();
      
      setState(() {
        _hasActiveReservation = reservationsQuery.docs.isNotEmpty;
        _checkingReservation = false;
      });
    } catch (e) {
      print('Error checking active reservations: $e');
      setState(() {
        _checkingReservation = false;
      });
    }
  }
  
  Future<void> _setupReservationListener() async {
    if (currentUserId == null) {
      setState(() {
        _checkingReservation = false;
      });
      return;
    }
    
    try {
      // First check for existing reservations
      await _checkActiveReservations();
      
      // Then set up a listener for new reservations
      final reservationsQuery = FirebaseFirestore.instance
          .collection('reservations')
          .where('userId', isEqualTo: currentUserId)
          .where('providerId', isEqualTo: widget.providerId)
          .where('status', isEqualTo: 'pending');
      
      _reservationSubscription = reservationsQuery.snapshots().listen((snapshot) {
        if (mounted) {
          setState(() {
            _hasActiveReservation = snapshot.docs.isNotEmpty;
            _checkingReservation = false;
          });
        }
      }, onError: (error) {
        print('Error in reservation listener: $error');
        if (mounted) {
          setState(() {
            _checkingReservation = false;
          });
        }
      });
    } catch (e) {
      print('Error setting up reservation listener: $e');
      if (mounted) {
        setState(() {
          _checkingReservation = false;
        });
      }
    }
  }

 // Replace the direct navigation with GoRouter
void _contactProvider() {
  if (_providerData.containsKey('userId')) {
    final providerId = _providerData['userId'] as String;
    final providerName = '${_userData['firstname'] ?? ''} ${_userData['lastname'] ?? ''}';
    
    // Use GoRouter instead of Navigator.push
    context.push(
      '/clientHome/marketplace/chat/conversation/$providerId',
      extra: {
        'otherUserName': providerName,
      },
    );
  }
}

  Future<void> _makePhoneCall() async {
    final phone = _userData['phone'];
    if (phone != null && phone.isNotEmpty) {
      // Fix: Ensure the phone number is properly formatted
      // Remove any non-digit characters
      final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
      final Uri phoneUri = Uri(scheme: 'tel', path: cleanPhone);
      
      try {
        await launchUrl(phoneUri);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Impossible d\'ouvrir le composeur: $e',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Numéro de téléphone non disponible',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _openInGoogleMaps() async {
    if (_latitude == null || _longitude == null) return;
    
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$_latitude,$_longitude');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir Google Maps')),
      );
    }
  }

    // Enhanced provider header with contact icons
  Widget _buildEnhancedProviderHeader() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;
    
    final providerName = '${_userData['firstname'] ?? ''} ${_userData['lastname'] ?? ''}';
    final photoUrl = _userData['avatarUrl'] ?? '';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkInputBackground : Colors.white,
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
          Row(
            children: [
              // Provider photo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: primaryColor,
                    width: 2,
                  ),
                  image: photoUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(photoUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: photoUrl.isEmpty
                    ? Icon(
                        Icons.person,
                        size: 40,
                        color: primaryColor,
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
                      providerName,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          color: Colors.amber,
                          size: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _averageRating.toStringAsFixed(1),
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '(${_reviews.length} avis)',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _serviceName,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          // Contact buttons row
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildContactButton(
                icon: Icons.message,
                label: 'Message',
                onTap: _contactProvider,
                isDarkMode: isDarkMode,
                primaryColor: primaryColor,
              ),
              _buildContactButton(
                icon: Icons.phone,
                label: 'Appeler',
                onTap: _makePhoneCall,
                isDarkMode: isDarkMode,
                primaryColor: primaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Contact button widget
  Widget _buildContactButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDarkMode,
    required Color primaryColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 24),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: primaryColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: primaryColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
  // Build reviews tab with detailed ratings
  Widget _buildReviewsTab() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;
    
    // Use SingleChildScrollView to handle overflow
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Évaluations et Avis',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            
            // Detailed ratings card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Overall rating
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              _averageRating.toStringAsFixed(1),
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Note globale',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: List.generate(5, (i) {
                                  return Icon(
                                    i < _averageRating ? Icons.star : Icons.star_border,
                                    color: Colors.amber,
                                    size: 20,
                                  );
                                }),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$_reviewCount avis',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const Divider(height: 32),
                    
                    // Detailed ratings
                    _buildRatingBar('Qualité', _qualityRating, isDarkMode),
                    const SizedBox(height: 12),
                    _buildRatingBar('Ponctualité', _timelinessRating, isDarkMode),
                    const SizedBox(height: 12),
                    _buildRatingBar('Prix', _priceRating, isDarkMode),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Reviews section title
            Text(
              'Commentaires des clients',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            
            // Reviews list
            if (_reviews.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.rate_review_outlined,
                        size: 48,
                        color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucun avis pour le moment',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              // Use ListView.builder directly with shrinkWrap
              ListView.builder(
                shrinkWrap: true, // Makes ListView take only the space it needs
                physics: NeverScrollableScrollPhysics(), // Disable scrolling of this ListView
                itemCount: _reviews.length,
                itemBuilder: (context, index) {
                  final review = _reviews[index];
                  final reviewerName = review['userName'] ?? 'Client';
                  final comment = review['comment'] ?? '';
                  final quality = (review['quality'] as num?)?.toDouble() ?? 0.0;
                  final timeliness = (review['timeliness'] as num?)?.toDouble() ?? 0.0;
                  final price = (review['price'] as num?)?.toDouble() ?? 0.0;
                  final average = (quality + timeliness + price) / 3;
                  
                  // Get date if available
                  DateTime? date;
                  if (review['createdAt'] != null && review['createdAt'] is Timestamp) {
                    date = (review['createdAt'] as Timestamp).toDate();
                  }
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                                child: Text(
                                  reviewerName.isNotEmpty ? reviewerName[0].toUpperCase() : 'C',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      reviewerName,
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: isDarkMode ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    if (date != null)
                                      Text(
                                        DateFormat('dd/MM/yyyy').format(date),
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Row(
                                children: List.generate(5, (i) {
                                  return Icon(
                                    i < average ? Icons.star : Icons.star_border,
                                    color: Colors.amber,
                                    size: 16,
                                  );
                                }),
                              ),
                            ],
                          ),
                          if (comment.isNotEmpty) ...[  
                            const SizedBox(height: 12),
                            Text(
                              comment,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [
                              _buildRatingChip('Qualité', quality, isDarkMode),
                              _buildRatingChip('Ponctualité', timeliness, isDarkMode),
                              _buildRatingChip('Prix', price, isDarkMode),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
  
  // Helper method to build rating bars
  Widget _buildRatingBar(String label, double rating, bool isDarkMode) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: List.generate(5, (i) {
                  return Icon(
                    i < rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 16,
                  );
                }),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            rating.toStringAsFixed(1),
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
  
  // Helper method to build rating chips for individual reviews
  Widget _buildRatingChip(String label, double rating, bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            rating.toStringAsFixed(1),
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            Icons.star,
            size: 12,
            color: Colors.amber,
          ),
        ],
      ),
    );
  }

   // Combined Informations tab (services + info)
  Widget _buildInformationsTab() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [    
          // Bio section
          if (_providerData['bio'] != null && _providerData['bio'].toString().isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'À propos',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _providerData['bio'],
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            
          const SizedBox(height: 24),
          
          // Working days and hours section
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Horaires de travail',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildWorkingDayRow('Lundi', 'monday', isDarkMode, primaryColor),
                    _buildWorkingDayRow('Mardi', 'tuesday', isDarkMode, primaryColor),
                    _buildWorkingDayRow('Mercredi', 'wednesday', isDarkMode, primaryColor),
                    _buildWorkingDayRow('Jeudi', 'thursday', isDarkMode, primaryColor),
                    _buildWorkingDayRow('Vendredi', 'friday', isDarkMode, primaryColor),
                    _buildWorkingDayRow('Samedi', 'saturday', isDarkMode, primaryColor),
                    _buildWorkingDayRow('Dimanche', 'sunday', isDarkMode, primaryColor),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Location section
          if (_latitude != null && _longitude != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Zone de travail',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _address,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => _openInGoogleMaps(),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            children: [
                              SizedBox(
                                height: 200,
                                width: double.infinity,
                                child: FlutterMap(
                                  mapController: _mapController,
                                  options: MapOptions(
                                    center: LatLng(_latitude!, _longitude!),
                                    zoom: 11.0, // Slightly zoomed out to show the circle
                                    interactiveFlags: InteractiveFlag.none, // Disable map interactions to ensure tap goes to parent
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName: 'com.example.app',
                                    ),
                                    // Add CircleLayer for the 10km radius
                                    CircleLayer(
                                      circles: [
                                        CircleMarker(
                                          point: LatLng(_latitude!, _longitude!),
                                          radius: 10000, // 10km in meters
                                          useRadiusInMeter: true, // Important! This ensures radius is in meters
                                          color: Colors.blue.withOpacity(0.15), // Very light fill
                                          borderColor: Colors.blue.withOpacity(0.7), // More opaque border
                                          borderStrokeWidth: 2.0, // Border width
                                        ),
                                      ],
                                    ),
                                    MarkerLayer(
                                      markers: [
                                        Marker(
                                          width: 40.0,
                                          height: 40.0,
                                          point: LatLng(_latitude!, _longitude!),
                                          builder: (ctx) => Icon(
                                            Icons.location_pin,
                                            color: primaryColor,
                                            size: 40,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Add a semi-transparent overlay with a hint
                              Positioned(
                                bottom: 10,
                                right: 10,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.open_in_new,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Ouvrir dans Maps',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
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
              ],
            ),
            
          
              ],
            ),
        
    );
  }
  
  // Helper method to build working day row
  Widget _buildWorkingDayRow(String dayName, String dayKey, bool isDarkMode, Color primaryColor) {
    // Check if working days data exists
    final bool isWorkingDay = _providerData.containsKey('workingDays') && 
                           _providerData['workingDays'] is Map && 
                           _providerData['workingDays'][dayKey] == true;
    
    // Get working hours if available
    String workingHours = 'Fermé';
    if (isWorkingDay && 
        _providerData.containsKey('workingHours') && 
        _providerData['workingHours'] is Map && 
        _providerData['workingHours'][dayKey] is Map) {
      
      final startTime = _providerData['workingHours'][dayKey]['start'] as String?;
      final endTime = _providerData['workingHours'][dayKey]['end'] as String?;
      
      if (startTime != null && endTime != null && 
          startTime.isNotEmpty && endTime.isNotEmpty && 
          startTime != "00:00" && endTime != "00:00") {
        workingHours = '$startTime - $endTime';
      }
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isWorkingDay ? Icons.check_circle : Icons.cancel,
                color: isWorkingDay ? primaryColor : (isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                dayName,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          Text(
            workingHours,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: isWorkingDay 
                  ? (isDarkMode ? Colors.white : Colors.black87)
                  : (isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
              fontWeight: isWorkingDay ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

   // Build project photos tab
  Widget _buildProjectPhotosTab() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    if (_projectImages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.photo_library_outlined,
                size: 64,
                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
              const SizedBox(height: 16),
              Text(
                'Aucune photo de projet disponible',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Photos de projets',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          // Use ImageGalleryUtils to display project images
          Expanded(
            child: SingleChildScrollView(
              child: ImageGalleryUtils.buildImageGallery(
                context,
                _projectImages,
                isDarkMode: isDarkMode,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
   @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;
    
    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightInputBackground,
      appBar: CustomAppBar(
        title: 'Profil Prestataire',
        showBackButton: true,
        backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
        titleColor: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        iconColor: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        actions: [
          // Favorite button
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? Colors.red : (isDarkMode ? Colors.white : Colors.black87),
            ),
            onPressed: _toggleFavorite,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: primaryColor,
              ),
            )
          : Column(
              children: [
                // Provider header with contact buttons
                _buildEnhancedProviderHeader(),
                
                // Tab bar with improved styling
                Container(
                  decoration: BoxDecoration(
                    color: isDarkMode ? AppColors.darkInputBackground : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: primaryColor,
                    unselectedLabelColor: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                    indicatorColor: primaryColor,
                    indicatorWeight: 3,
                    indicatorSize: TabBarIndicatorSize.label,
                    labelStyle: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    unselectedLabelStyle: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    dividerColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.info_outline, size: 18),
                            const SizedBox(width: 6),
                            Text('Infos'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_outline, size: 18),
                            const SizedBox(width: 6),
                            Text('Avis'),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.photo_library_outlined, size: 18),
                            const SizedBox(width: 6),
                            Text('Projets'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Information tab
                      _buildInformationsTab(),
                      
                      // Reviews tab
                      _buildReviewsTab(),
                      
                      // Projects tab
                      _buildProjectPhotosTab(),
                    ],
                  ),
                ),
                
                // Bottom action buttons
                if (!_checkingReservation && !_hasActiveReservation)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDarkMode ? AppColors.darkInputBackground : Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: CustomButton(
                      text: 'Réserver',
                      onPressed: () {
                        context.push(
                          '/clientHome/reservation/${widget.providerId}',
                          extra: {
                            'providerName': '${_userData['firstname'] ?? ''} ${_userData['lastname'] ?? ''}',
                            'serviceName': widget.serviceName,
                          },
                        );
                      },
                      isPrimary: true,
                      width: double.infinity,
                    ),
                  ),
                
                // Show message if there's already an active reservation
                if (!_checkingReservation && _hasActiveReservation)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDarkMode ? AppColors.darkInputBackground : Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info,
                          color: Colors.blue,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Vous avez déjà une réservation en attente avec ce prestataire',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            context.push('/clientHome/my-reservations');
                          },
                          child: Text(
                            'Voir',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                // Show loading indicator when checking reservation status
                if (_checkingReservation)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Center(child: CircularProgressIndicator(color: primaryColor)),
                  ),
              ],
            ),
    );
  }
}