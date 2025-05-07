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
  
  // Data storage
  Map<String, dynamic> _providerData = {};
  Map<String, dynamic> _userData = {};
  String _serviceName = '';

  List<String> _projectImages = [];

  // Location data
  double? _latitude;
  double? _longitude;
  String _address = '';
  MapController _mapController = MapController();
  

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // Updated to 4 tabs
    _fetchProviderData();
  }

  @override
  void dispose() {
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
      
      setState(() {
        _providerData = providerData;
        _userData = userData;
        _serviceName = serviceName;
        _latitude = latitude;
        _longitude = longitude;
        _address = address;
        _projectImages = projectImages; // Store project images
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
      
      // Use the rating from provider data directly
      if (_providerData.containsKey('ratings') && 
          _providerData['ratings'] is Map<String, dynamic> &&
          _providerData['ratings']['overall'] != null) {
        _averageRating = (_providerData['ratings']['overall'] as num).toDouble();
      }
      
      // Set loading to false after all data is loaded
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
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
    final phoneNumber = _userData['phone'];
    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Numéro de téléphone non disponible')),
      );
      return;
    }

    final Uri uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'appeler ce numéro')),
      );
    }
  }

  // Method to show full screen image
    // Build provider header with photo, name, and rating
  Widget _buildProviderHeader() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;
    
    final providerName = '${_userData['firstname'] ?? ''} ${_userData['lastname'] ?? ''}';
    final photoUrl = _userData['photoURL'] ?? '';
    
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
      child: Row(
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
    );
  }

  // Build services tab
  Widget _buildServicesTab() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final services = List<String>.from(_providerData['services'] ?? []);
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Services proposés',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          if (services.isEmpty)
            Center(
              child: Text(
                'Aucun service spécifié',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                ),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: services.map((service) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDarkMode 
                        ? AppColors.primaryGreen.withOpacity(0.2) 
                        : AppColors.primaryDarkGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDarkMode 
                          ? AppColors.primaryGreen.withOpacity(0.5) 
                          : AppColors.primaryDarkGreen.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    service,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                    ),
                  ),
                );
              }).toList(),
            ),
          
          const SizedBox(height: 24),
          
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
        ],
      ),
    );
  }

  // Build reviews tab
  Widget _buildReviewsTab() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Avis des clients',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          if (_reviews.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.rate_review_outlined,
                      size: 64,
                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aucun avis pour le moment',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _reviews.length,
                itemBuilder: (context, index) {
                  final review = _reviews[index];
                  final timestamp = review['timestamp'] as Timestamp;
                  final date = timestamp.toDate();
                  final formattedDate = '${date.day}/${date.month}/${date.year}';
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                review['userName'],
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                formattedDate,
                                style: GoogleFonts.poppins(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: List.generate(5, (i) {
                              return Icon(
                                i < review['rating'] ? Icons.star : Icons.star_border,
                                color: Colors.amber,
                                size: 18,
                              );
                            }),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            review['comment'],
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // Build info tab
  Widget _buildInfoTab() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Location section
          Text(
            'Localisation',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
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
          const SizedBox(height: 16),
          
          // Map
          if (_latitude != null && _longitude != null)
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    center: LatLng(_latitude!, _longitude!),
                    zoom: 15.0,
                    interactiveFlags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.app',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          width: 40.0,
                          height: 40.0,
                          point: LatLng(_latitude!, _longitude!),
                          builder: (ctx) => const Icon(
                            Icons.location_pin,
                            color: Colors.red,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          
          const SizedBox(height: 24),
          
          // Working hours section
          Text(
            'Horaires de travail',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildWorkingHours(),
          
          const SizedBox(height: 24),
          
          // Experience section
          Text(
            'Expérience',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildExperience(),
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
  Widget _buildWorkingHours() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final workingDays = _providerData['workingDays'] as Map<String, dynamic>? ?? {};
    final workingHours = _providerData['workingHours'] as Map<String, dynamic>? ?? {};
    
    final days = [
      {'key': 'monday', 'name': 'Lundi'},
      {'key': 'tuesday', 'name': 'Mardi'},
      {'key': 'wednesday', 'name': 'Mercredi'},
      {'key': 'thursday', 'name': 'Jeudi'},
      {'key': 'friday', 'name': 'Vendredi'},
      {'key': 'saturday', 'name': 'Samedi'},
      {'key': 'sunday', 'name': 'Dimanche'},
    ];
    
    return Column(
      children: days.map((day) {
        final dayKey = day['key'] as String;
        final dayName = day['name'] as String;
        final isWorking = workingDays[dayKey] == true;
        
        String hoursText = 'Fermé';
        if (isWorking && workingHours.containsKey(dayKey)) {
          final dayHours = workingHours[dayKey] as Map<String, dynamic>?;
          if (dayHours != null) {
            final start = dayHours['start'] as String?;
            final end = dayHours['end'] as String?;
            if (start != null && end != null) {
              hoursText = '$start - $end';
            }
          }
        }
        
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                dayName,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                hoursText,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isWorking 
                      ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                      : (isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExperience() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final experiences = List<Map<String, dynamic>>.from(_providerData['experiences'] ?? []);
    
    if (experiences.isEmpty) {
      return Center(
        child: Text(
          'Aucune expérience spécifiée',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
        ),
      );
    }
    
    return Column(
      children: experiences.map((exp) {
        final service = exp['service'] as String? ?? 'Non spécifié';
        final years = exp['years']?.toString() ?? 'Non spécifié';
        final description = exp['description'] as String? ?? '';
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    service,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDarkMode 
                          ? AppColors.primaryGreen.withOpacity(0.2) 
                          : AppColors.primaryDarkGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$years ans',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                      ),
                    ),
                  ),
                ],
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  description,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomBar() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkBackground : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Reservation button
          CustomButton(
            onPressed: () => _navigateToReservationPage(),
            text: 'Réserver une intervention',
            backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
            textColor: Colors.white,
          ),
          const SizedBox(height: 12),
          
          // Call and message buttons
          Row(
            children: [
              // Call button
              Expanded(
                child: CustomButton(
                  onPressed: _makePhoneCall,
                  text: 'Appeler',
                  backgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                  textColor: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(width: 16),
              
              // Message button
              Expanded(
                child: CustomButton(
                  onPressed: _contactProvider,
                  text: 'Message',
                  backgroundColor: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                  textColor: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  // Navigate to reservation page
  void _navigateToReservationPage() async {
    if (currentUserId == null) return;
    
    try {
      // Check if an active reservation already exists with this provider
      final existingReservationsQuery = await FirebaseFirestore.instance
          .collection('reservations')
          .where('userId', isEqualTo: currentUserId)
          .where('providerId', isEqualTo: widget.providerId)
          .where('status', whereIn: ['pending', 'accepted', 'in_progress'])
          .get();
      
      if (existingReservationsQuery.docs.isNotEmpty) {
        // Active reservation exists, show message
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Vous avez déjà une réservation active avec ce prestataire'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        // No active reservation, navigate to reservation page
        GoRouter.of(context).push(
          '/clientHome/reservation/${widget.providerId}',
          extra: {
            'providerName': '${_userData['firstname'] ?? ''} ${_userData['lastname'] ?? ''}',
            'serviceName': widget.serviceName.isNotEmpty ? widget.serviceName : _serviceName,
          },
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Profil Prestataire',
        showBackButton: true,
        actions: [
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
                color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
              ),
            )
          : Column(
              children: [
                // Provider header section
                _buildProviderHeader(),
                
                // Tab bar
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
                    labelColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                    unselectedLabelColor: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                    indicatorColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                    indicatorWeight: 3,
                    labelStyle: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    tabs: const [
                      Tab(text: 'Services'),
                      Tab(text: 'Avis'),
                      Tab(text: 'Infos'),
                      Tab(text: 'Projets'), // New tab for project photos
                    ],
                  ),
                ),
                
                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildServicesTab(),
                      _buildReviewsTab(),
                      _buildInfoTab(),
                      _buildProjectPhotosTab(), // New tab content for project photos
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: !_isLoading
          ? _buildBottomBar()
          : null,
    );
  }
}