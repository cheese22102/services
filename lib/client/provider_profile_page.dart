import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../front/app_colors.dart';
import '../front/custom_app_bar.dart';
import '../front/custom_button.dart';
import '../chat/conversation_service_page.dart';

class ProviderProfilePage extends StatefulWidget {
  final String providerId;

  const ProviderProfilePage({
    super.key,
    required this.providerId,
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

  // Location data
  double? _latitude;
  double? _longitude;
  String _address = '';
  MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchProviderData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchProviderData() async {
    try {
      print('Fetching provider data for ID: ${widget.providerId}');
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
      
      setState(() {
        _providerData = providerData;
        _userData = userData;
        _serviceName = serviceName;
        _latitude = latitude;
        _longitude = longitude;
        _address = address;
      });
      
      // Now load reviews and check favorites
      await _loadData();
      
    } catch (e) {
      print('Error fetching provider data: $e');
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
            .collection('favorites')
            .doc(widget.providerId)
            .get();
        
        setState(() {
          _isFavorite = favDoc.exists;
        });
      }

      // Load reviews
      final reviewsSnapshot = await FirebaseFirestore.instance
          .collection('reviews')
          .where('providerId', isEqualTo: widget.providerId)
          .orderBy('timestamp', descending: true)
          .get();

      final reviews = reviewsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'userId': data['userId'] ?? '',
          'userName': data['userName'] ?? 'Utilisateur',
          'rating': (data['rating'] ?? 0).toDouble(),
          'comment': data['comment'] ?? '',
          'timestamp': data['timestamp'] ?? Timestamp.now(),
        };
      }).toList();

      // Calculate average rating
      double totalRating = 0;
      if (reviews.isNotEmpty) {
        for (var review in reviews) {
          totalRating += review['rating'];
        }
        _averageRating = totalRating / reviews.length;
      } else {
        // Use the rating from provider data if available
        final ratings = _providerData['ratings'];
        if (ratings != null && ratings['overall'] != null) {
          _averageRating = (ratings['overall'] as num).toDouble();
        }
      }

      setState(() {
        _reviews = reviews;
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
          .collection('favorites')
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

  void _startConversation() async {
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
        if (participants.contains(widget.providerId)) {
          existingConversationId = doc.id;
          break;
        }
      }
      
      final providerName = '${_userData['firstname'] ?? ''} ${_userData['lastname'] ?? ''}';
      
      if (existingConversationId != null) {
        // Navigate to existing conversation
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConversationServicePage(
              otherUserId: widget.providerId,
              otherUserName: providerName,
            ),
          ),
        );
      } else {
        // Create a new conversation
        final newConversationRef = FirebaseFirestore.instance.collection('conversations').doc();
        
        await newConversationRef.set({
          'participants': [currentUserId, widget.providerId],
          'lastMessage': null,
          'lastMessageTime': null,
          'createdAt': FieldValue.serverTimestamp(),
          'serviceId': _serviceName,
        });
        
        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ConversationServicePage(
              otherUserId: widget.providerId,
              otherUserName: providerName,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
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


  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;
    
    final providerName = '${_userData['firstname'] ?? ''} ${_userData['lastname'] ?? ''}';
    final photoUrl = _userData['photoURL'] ?? '';
    
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
                color: primaryColor,
              ),
            )
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Provider header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDarkMode ? AppColors.darkInputBackground : Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Avatar
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: isDarkMode ? AppColors.darkBorderColor : AppColors.lightBorderColor,
                          backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                          child: photoUrl.isEmpty
                              ? Icon(
                                  Icons.person,
                                  size: 50,
                                  color: isDarkMode ? Colors.white70 : Colors.black54,
                                )
                              : null,
                        ),
                        const SizedBox(height: 16),
                        
                        // Name
                        Text(
                          providerName,
                          style: GoogleFonts.poppins(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        
                        // Service
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _serviceName,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Rating
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.star,
                              size: 24,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _averageRating.toStringAsFixed(1),
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '(${_reviews.length} avis)',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                          ],
                        ),
                        
                        // Contact buttons - always show them
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Message button
                            CustomButton(
                              onPressed: _startConversation,
                              text: 'Message',
                              backgroundColor: primaryColor,
                              textColor: Colors.white,
                              height: 44,
                              width: 120,
                            ),
                            const SizedBox(width: 16),
                            
                            // Call button
                            CustomButton(
                              onPressed: _makePhoneCall,
                              text: 'Appeler',
                              backgroundColor: Colors.transparent,
                              textColor: primaryColor,
                              height: 44,
                              width: 120,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Tabs
                  Container(
                    color: isDarkMode ? Colors.black : Colors.grey.shade50,
                    child: TabBar(
                      controller: _tabController,
                      labelColor: primaryColor,
                      unselectedLabelColor: isDarkMode ? Colors.white70 : Colors.grey.shade700,
                      indicatorColor: primaryColor,
                      tabs: [
                        Tab(text: 'À propos'),
                        Tab(text: 'Expérience'),
                        Tab(text: 'Avis'),
                      ],
                      labelStyle: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      unselectedLabelStyle: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  
                  // Tab content
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // About tab
                        _buildAboutTab(isDarkMode),
                        
                        // Experience tab
                        _buildExperienceTab(isDarkMode),
                        
                        // Reviews tab
                        _buildReviewsTab(isDarkMode),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAboutTab(bool isDarkMode) {
    final workingDays = _providerData['workingDays'] as Map<String, dynamic>? ?? {};
    final workingHours = _providerData['workingHours'] as Map<String, dynamic>? ?? {};
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bio section
          Text(
            'Bio',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _providerData['bio'] ?? 'Aucune description disponible',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 24),
          
          // Working area with map
          Text(
            'Zone de travail',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 8),
          
          // Address text
          Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 20,
                color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _address,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Map with 15km radius
          if (_latitude != null && _longitude != null)
            Container(
              height: 250,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    center: LatLng(_latitude!, _longitude!),
                    zoom: 10.0,
                    interactiveFlags: InteractiveFlag.all,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.app',
                    ),
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: LatLng(_latitude!, _longitude!),
                          radius: 15000, // 15km in meters
                          color: AppColors.primaryGreen.withOpacity(0.3), // Increased opacity
                          borderColor: AppColors.primaryGreen,
                          borderStrokeWidth: 3, // Increased stroke width
                          useRadiusInMeter: true, // Important: ensure radius is interpreted as meters
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(_latitude!, _longitude!),
                          width: 40,
                          height: 40,
                          builder: (context) => Icon(
                            Icons.location_on,
                            color: AppColors.primaryGreen,
                            size: 40,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              height: 100,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Localisation non disponible',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ),
          
          const SizedBox(height: 24),
          
          // Working hours
          Text(
            'Horaires de travail',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          
          // Days and hours
          _buildWorkingHoursTable(isDarkMode, workingDays, workingHours),
          
          const SizedBox(height: 24),
          
          // Services
          Text(
            'Services',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          
          // Services list
          _buildServicesList(isDarkMode),
        ],
      ),
    );
  }

  Widget _buildWorkingHoursTable(
    bool isDarkMode, 
    Map<String, dynamic> workingDays, 
    Map<String, dynamic> workingHours
  ) {
    final daysTranslation = {
      'monday': 'Lundi',
      'tuesday': 'Mardi',
      'wednesday': 'Mercredi',
      'thursday': 'Jeudi',
      'friday': 'Vendredi',
      'saturday': 'Samedi',
      'sunday': 'Dimanche',
    };
    
    return Table(
      border: TableBorder.all(
        color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
        width: 1,
        borderRadius: BorderRadius.circular(8),
      ),
      columnWidths: const {
        0: FlexColumnWidth(2),
        1: FlexColumnWidth(3),
      },
      children: daysTranslation.entries.map((entry) {
        final day = entry.key;
        final dayName = entry.value;
        final isWorking = workingDays[day] == true;
        
        String hoursText = 'Fermé';
        if (isWorking && workingHours.containsKey(day)) {
          final dayHours = workingHours[day] as Map<String, dynamic>?;
          if (dayHours != null) {
            final start = dayHours['start'] ?? '00:00';
            final end = dayHours['end'] ?? '00:00';
            if (start != '00:00' || end != '00:00') {
              hoursText = '$start - $end';
            } else {
              hoursText = 'Horaires non spécifiés';
            }
          }
        }
        
        return TableRow(
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.transparent : Colors.white,
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                dayName,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                hoursText,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isWorking 
                      ? (isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)
                      : (isDarkMode ? Colors.grey.shade600 : Colors.grey.shade500),
                ),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildServicesList(bool isDarkMode) {
    final services = _providerData['services'] as List<dynamic>? ?? [];
    
    if (services.isEmpty) {
      return Text(
        'Aucun service spécifié',
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        ),
      );
    }
    
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: services.map((service) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDarkMode ? AppColors.darkInputBackground : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDarkMode 
                  ? AppColors.darkBorderColor.withOpacity(0.3) 
                  : AppColors.lightBorderColor.withOpacity(0.3),
            ),
          ),
          child: Text(
            service.toString(),
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExperienceTab(bool isDarkMode) {
    final experiences = _providerData['experiences'] as List<dynamic>? ?? [];
    final certifications = _providerData['certifications'] as List<dynamic>? ?? [];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Experience section
          Text(
            'Expérience professionnelle',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          
          if (experiences.isEmpty)
            Text(
              'Aucune expérience professionnelle spécifiée',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: experiences.length,
              itemBuilder: (context, index) {
                final experience = experiences[index] as Map<String, dynamic>? ?? {};
                final service = experience['service'] ?? 'Non spécifié';
                final years = experience['years'] ?? 0;
                final description = experience['description'] ?? 'Aucune description';
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  color: isDarkMode ? AppColors.darkInputBackground : Colors.white,
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
                            Icon(
                              Icons.work_outline,
                              size: 20,
                              color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                service,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDarkMode ? AppColors.primaryGreen.withOpacity(0.1) : AppColors.primaryDarkGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '$years ${years > 1 ? 'ans' : 'an'}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          
          const SizedBox(height: 24),
          
          // Certifications section
          Text(
            'Certifications',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          
          if (certifications.isEmpty)
            Text(
              'Aucune certification spécifiée',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: certifications.map((certification) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDarkMode ? AppColors.darkInputBackground : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDarkMode 
                          ? AppColors.darkBorderColor.withOpacity(0.3) 
                          : AppColors.lightBorderColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_outlined,
                        size: 16,
                        color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        certification.toString(),
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewsTab(bool isDarkMode) {
    return _reviews.isEmpty
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.rate_review_outlined,
                  size: 64,
                  color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'Aucun avis pour le moment',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Soyez le premier à donner votre avis',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                                  ),
              ],
            ),
          )
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _reviews.length,
            itemBuilder: (context, index) {
              final review = _reviews[index];
              final userName = review['userName'];
              final rating = review['rating'];
              final comment = review['comment'];
              final timestamp = review['timestamp'] as Timestamp;
              final date = timestamp.toDate();
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: isDarkMode ? AppColors.darkInputBackground : Colors.white,
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
                            radius: 16,
                            backgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                            child: Icon(
                              Icons.person,
                              size: 20,
                              color: isDarkMode ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            userName,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${date.day}/${date.month}/${date.year}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Rating stars
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            index < rating ? Icons.star : Icons.star_border,
                            size: 18,
                            color: Colors.amber,
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                      
                      // Comment
                      Text(
                        comment,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }
}