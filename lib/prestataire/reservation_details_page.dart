import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../front/app_colors.dart';
import '../front/app_typography.dart';
import '../front/custom_app_bar.dart';
import '../front/custom_button.dart';
import '../front/app_spacing.dart';
import '../utils/image_gallery_utils.dart';

class ReservationDetailsPage extends StatefulWidget {
  final String reservationId;
  
  const ReservationDetailsPage({
    super.key,
    required this.reservationId,
  });

  @override
  State<ReservationDetailsPage> createState() => _ReservationDetailsPageState();
}

class _ReservationDetailsPageState extends State<ReservationDetailsPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _reservationData;
  Map<String, dynamic>? _userData;
  bool _hasPendingReclamation = false; // New state variable
  
  // Add these new variables for completion functionality
  final TextEditingController _completionDescriptionController = TextEditingController();

  // Map related variables
  GoogleMapController? _googleMapController;
  double? _latitude;
  double? _longitude;
  Set<Circle> _circles = {};
  
  @override
  void initState() {
    super.initState();
    _loadReservationData();
  }
  
  @override
  void dispose() {
    _completionDescriptionController.dispose();
    _googleMapController?.dispose(); // Dispose map controller
    super.dispose();
  }
  
  void _showCustomSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTypography.bodySmall(context).copyWith(color: Colors.white),
        ),
        backgroundColor: isError ? AppColors.errorLightRed : AppColors.warningOrange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
  
  Future<void> _loadReservationData() async {
    setState(() {
      _isLoading = true;
      _hasPendingReclamation = false; // Reset on load
    });
    
    try {
      // Get reservation data
      final reservationDoc = await FirebaseFirestore.instance
          .collection('reservations')
          .doc(widget.reservationId)
          .get();
      
      if (!reservationDoc.exists) {
        if (mounted) {
          _showCustomSnackBar(context, 'Réservation introuvable', isError: true);
          Navigator.pop(context);
        }
        return;
      }
      
      final reservationData = reservationDoc.data() as Map<String, dynamic>;
      
      // Get user data
      final userId = reservationData['userId'] as String;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      final userData = userDoc.data();

      // Extract location data for map
      final locationData = reservationData['location'] as Map<String, dynamic>?;
      double? latitude;
      double? longitude;
      if (locationData != null && locationData['latitude'] != null && locationData['longitude'] != null) {
        latitude = (locationData['latitude'] as num?)?.toDouble();
        longitude = (locationData['longitude'] as num?)?.toDouble();
      }

      // Check for pending reclamations
      final reclamationsSnapshot = await FirebaseFirestore.instance
          .collection('reclamations')
          .where('reservationId', isEqualTo: widget.reservationId)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();
      
      bool hasPendingReclamation = reclamationsSnapshot.docs.isNotEmpty;
      
      if (mounted) {
        setState(() {
          _reservationData = reservationData;
          _userData = userData;
          _latitude = latitude;
          _longitude = longitude;
          _hasPendingReclamation = hasPendingReclamation;
          if (_latitude != null && _longitude != null) {
            _circles = {
              Circle(
                circleId: const CircleId('user_location_radius'),
                center: LatLng(_latitude!, _longitude!),
                radius: 1000, // Example radius, adjust as needed
                fillColor: AppColors.primaryGreen.withOpacity(0.1),
                strokeColor: AppColors.primaryGreen.withOpacity(0.5),
                strokeWidth: 1,
              )
            };
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        _showCustomSnackBar(context, 'Erreur: $e', isError: true);
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _updateReservationStatus(String status) async {
    if (_reservationData == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Update reservation status
      await FirebaseFirestore.instance
          .collection('reservations')
          .doc(widget.reservationId)
          .update({'status': status});
      
      // Create notification for user
      final userId = _reservationData!['userId'] as String;
      final providerId = FirebaseAuth.instance.currentUser?.uid;
      
      if (providerId == null) throw Exception('Provider not authenticated');
      
      // Get provider name
      final providerDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(providerId)
          .get();
      
      final providerData = providerDoc.data();
      final providerName = '${providerData?['firstname'] ?? ''} ${providerData?['lastname'] ?? ''}'.trim();
      
      // Create notification
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .add({
        'title': status == 'approved' 
            ? 'Demande d\'intervention acceptée' 
            : 'Demande d\'intervention refusée',
        'body': status == 'approved'
            ? 'Votre demande d\'intervention a été acceptée par $providerName'
            : 'Votre demande d\'intervention a été refusée par $providerName',
        'type': 'reservation_update',
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        'data': {
          'reservationId': widget.reservationId,
          'status': status,
          'providerId': providerId,
          'providerName': providerName,
        },
      });
      
      if (mounted) {
        _showCustomSnackBar(
          context,
          status == 'approved'
              ? 'Demande acceptée avec succès'
              : 'Demande refusée avec succès',
          isError: status == 'rejected',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showCustomSnackBar(context, 'Erreur: $e', isError: true);
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _makePhoneCall() async {
    if (_userData == null) return;
    
    final phone = _userData!['phone'] as String?;
    if (phone == null || phone.isEmpty) {
      if (mounted) {
        _showCustomSnackBar(context, 'Numéro de téléphone non disponible');
      }
      return;
    }
    
    final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
    final Uri phoneUri = Uri(scheme: 'tel', path: cleanPhone);
    
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri, mode: LaunchMode.externalApplication);
      } else {
        // This case means no app can handle the URI, or permissions are missing.
        // Provide a more user-friendly message.
        throw 'Aucune application de téléphone trouvée ou permissions manquantes.';
      }
    } catch (e) {
      if (mounted) {
        _showCustomSnackBar(context, 'Erreur lors de l\'appel: ${e.toString().contains('No Activity found') ? 'Veuillez vérifier si une application de téléphone est installée et que les permissions sont accordées.' : e.toString()}', isError: true);
      }
    }
  }

  
  // Add a new method to navigate to chat
  Future<void> _navigateToChat() async {
    if (_userData == null || _reservationData == null) return;
    
    final userId = _reservationData!['userId'] as String;
    final currentUser = FirebaseAuth.instance.currentUser;
    
    if (currentUser == null) {
      if (mounted) {
        _showCustomSnackBar(context, 'Vous devez être connecté pour contacter le client', isError: true);
      }
      return;
    }

    if (currentUser.uid == userId) {
      if (mounted) {
        _showCustomSnackBar(context, 'Vous ne pouvez pas contacter votre propre réservation');
      }
      return;
    }

    // Show loading indicator
    setState(() => _isLoading = true);

    try {
      // Get client name for the chat
      String clientName = 'Client';
      final userData = _userData;
      
      if (userData != null) {
        clientName = '${userData['firstname'] ?? ''} ${userData['lastname'] ?? ''}'.trim();
        clientName = clientName.isEmpty ? 'Client' : clientName;
      }
      
      // Navigate to chat screen with the properly formatted chat ID and user name
      if (mounted) {
        setState(() => _isLoading = false);
        context.push('/prestataireHome/chat/conversation/$userId', extra: {
          'otherUserName': clientName,
        });
      }
    } catch (e) {
      if (mounted) {
        _showCustomSnackBar(context, 'Erreur lors de l\'accès au chat: $e', isError: true);
      }
      setState(() => _isLoading = false);
    }
  }
  
  void _showConfirmationDialog(String action) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? AppColors.darkBackground : Colors.white,
        title: Text(
          action == 'approved' 
              ? 'Accepter la demande' 
              : 'Refuser la demande',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          action == 'approved'
              ? 'Êtes-vous sûr de vouloir accepter cette demande d\'intervention ?'
              : 'Êtes-vous sûr de vouloir refuser cette demande d\'intervention ?',
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Annuler',
              style: GoogleFonts.poppins(
                color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateReservationStatus(action == 'approved' ? 'approved' : 'rejected');
            },
            child: Text(
              'Confirmer',
              style: GoogleFonts.poppins(
                color: action == 'approved'
                    ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                    : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
    Color _getStatusColor(String status, bool isDarkMode) {
    switch (status) {
      case 'approved':
        return isDarkMode ? Colors.green.shade700 : Colors.green.shade600;
      case 'rejected':
        return isDarkMode ? Colors.red.shade800 : Colors.red.shade600;
      case 'completed':
        return isDarkMode ? Colors.blue.shade700 : Colors.blue.shade600;
      case 'waiting_confirmation': 
        return Colors.purple.shade600; // Purple color for waiting_confirmation
      case 'pending':
      default:
        return isDarkMode ? Colors.orange.shade700 : Colors.orange.shade600;
    }
  }
  
  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'completed':
        return Icons.task_alt;
      case 'waiting_confirmation': 
        return Icons.pending_actions_rounded; 
      case 'pending':
      default:
        return Icons.pending;
    }
  }
  
  String _getStatusText(String status) {
    switch (status) {
      case 'approved':
        return 'Demande acceptée';
      case 'rejected':
        return 'Demande refusée';
      case 'completed':
        return 'Intervention terminée';
      case 'waiting_confirmation': 
        return 'En attente confirmation client'; // Text for provider side
      case 'pending':
      default:
        return 'En attente de confirmation';
    }
  }
  
  // Replace the _showCompletionFormDialog method with a direct navigation method
void _navigateToCompletionPage() async {
  if (_reservationData == null) return;
  
  // Navigate to the completion page
  final result = await context.push<bool>(
    '/prestataireHome/reservation-completion/${widget.reservationId}',
  );
  
  // If the completion was successful, refresh the data
  if (result == true) {
    _loadReservationData();
  }
}

  Widget _buildContactButton({required IconData icon, required String label, required VoidCallback onTap, required bool isDarkMode}) {
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20, color: primaryColor),
        label: Text(label, style: GoogleFonts.poppins(fontSize: 14, color: primaryColor, fontWeight: FontWeight.w500)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: primaryColor, width: 1.5)),
          elevation: 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white,
      appBar: CustomAppBar(
        title: 'Détails de la demande',
        showBackButton: true,
      ),
        body: Center(
          child: CircularProgressIndicator(
            color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
          ),
        ),
      );
    }
    
    if (_reservationData == null) {
      return Scaffold(
        appBar: CustomAppBar(
          title: 'Détails de la demande',
          showBackButton: true,
        ),
        body: Center(
          child: Text(
            'Données non disponibles',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ),
      );
    }
    
    // Extract reservation data
    final description = _reservationData!['description'] as String? ?? '';
    final imageUrls = List<String>.from(_reservationData!['imageUrls'] ?? []);
    final isImmediate = _reservationData!['isImmediate'] as bool? ?? false;
    final serviceName = _reservationData!['serviceName'] as String? ?? 'Service non spécifié';
    final status = _reservationData!['status'] as String? ?? 'pending';
    
    // Format date and time
    final reservationTimestamp = _reservationData!['reservationDateTime'] as Timestamp?;
    final reservationDateTime = reservationTimestamp?.toDate();
    final formattedDate = reservationDateTime != null 
        ? DateFormat('dd/MM/yyyy').format(reservationDateTime)
        : 'Date non spécifiée';
    final formattedTime = reservationDateTime != null
        ? DateFormat('HH:mm').format(reservationDateTime)
        : 'Heure non spécifiée';
    
    // Extract user data
    final userName = _userData != null
        ? '${_userData!['firstname'] ?? ''} ${_userData!['lastname'] ?? ''}'.trim()
        : 'Utilisateur inconnu';
    final userPhone = _userData?['phone'] as String? ?? 'Non spécifié';
    final userPhoto = _userData?['avatarUrl'] as String? ?? '';
    
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Détails de la demande',
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status indicator
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: _getStatusColor(status, isDarkMode),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(status),
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _getStatusText(status),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // User info card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: isDarkMode ? Colors.grey.shade900 : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // User photo
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                              width: 2,
                            ),
                            image: userPhoto.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(userPhoto),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: userPhoto.isEmpty
                              ? Icon(
                                  Icons.person,
                                  size: 35,
                                  color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        
                        // User info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                userName.isEmpty ? 'Utilisateur inconnu' : userName,
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
                                    Icons.phone,
                                    size: 16,
                                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    userPhone,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
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
                    const SizedBox(height: 16), // Spacing between user info and buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildContactButton(
                          icon: Icons.chat_bubble_outline_rounded,
                          label: 'Message',
                          onTap: _navigateToChat,
                          isDarkMode: isDarkMode,
                        ),
                        const SizedBox(width: 8),
                        _buildContactButton(
                          icon: Icons.phone_outlined,
                          label: 'Appeler',
                          onTap: _makePhoneCall,
                          isDarkMode: isDarkMode,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Service info
            Text(
              'Détails du service',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: isDarkMode ? Colors.grey.shade900 : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Service name
                    Row(
                      children: [
                        Icon(
                          Icons.handyman,
                          size: 20,
                          color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Service:',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          serviceName,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Date and time
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 20,
                          color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isImmediate ? 'Intervention immédiate' : 'Date:',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                          ),
                        ),
                        if (!isImmediate) ...[
                          const SizedBox(width: 8),
                          Text(
                            formattedDate,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ],
                    ),
                    
                    if (!isImmediate) ...[
                      const SizedBox(height: 12),
                      
                      // Time
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 20,
                            color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Heure:',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formattedTime,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ],
                    
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Description
            Text(
              'Description du problème',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: isDarkMode ? Colors.grey.shade900 : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  description.isEmpty ? 'Aucune description fournie' : description,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ),

            // Map section
            if (_latitude != null && _longitude != null) ...[
              const SizedBox(height: 24),
              Text(
                'Localisation du client',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              // const SizedBox(height: 12), // Removed SizedBox before button
              // CustomButton for 'Ouvrir dans Maps' removed as per request
              const SizedBox(height: 16), // Keeping this SizedBox for spacing before the map
              Container(
                height: 200, // Fixed height for the map
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: GoogleMap(
                    mapType: MapType.normal,
                    initialCameraPosition: CameraPosition(
                      target: LatLng(_latitude!, _longitude!),
                      zoom: 14.0,
                    ),
                    onMapCreated: (GoogleMapController controller) {
                      _googleMapController = controller;
                    },
                    markers: {
                      Marker(
                        markerId: const MarkerId('userLocation'),
                        position: LatLng(_latitude!, _longitude!),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                      ),
                    },
                    circles: _circles,
                    zoomControlsEnabled: false,
                    scrollGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                    rotateGesturesEnabled: false,
                  ),
                ),
              ),
            ],
            
            // Images
            if (imageUrls.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Photos',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              // Use the reusable component
              ImageGalleryUtils.buildImageGallery(
                context, 
                imageUrls,
                isDarkMode: isDarkMode,
              ),
            ],
            const SizedBox(height: 32),
            
            // Show completion status if provider has marked it as completed
            // This specific message is now handled by the 'waiting_confirmation' status badge
            // if (status == 'approved' && providerCompletionStatus == 'completed') ...[
            // This section can be removed or adapted if a different message is needed when status is 'waiting_confirmation'
            // For now, the main status badge will show "En attente confirmation client"
            // ],
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(isDarkMode),
    );
  }

  Widget _buildBottomNavigationBar(bool isDarkMode) {
    final status = _reservationData?['status'] as String?;
    final providerCompletionStatus = _reservationData?['providerCompletionStatus'] as String?; // Assuming this field exists
    final bool canSubmitReclamation = !_hasPendingReclamation;

    List<Widget> buttons = [];

    if (status == 'pending') {
      buttons.add(
        Expanded(
          child: CustomButton(
            text: 'Refuser',
            onPressed: () => _showConfirmationDialog('rejected'),
            backgroundColor: isDarkMode ? Colors.red.shade800 : Colors.red.shade600,
            textColor: Colors.white,
          ),
        ),
      );
      buttons.add(const SizedBox(width: AppSpacing.sm)); // Consistent spacing
      buttons.add(
        Expanded(
          child: CustomButton(
            text: 'Accepter',
            onPressed: () => _showConfirmationDialog('approved'),
            backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
            textColor: Colors.white,
          ),
        ),
      );
    } else if (status == 'approved') {
      // Provider has not yet marked the intervention as done
      if (providerCompletionStatus != 'completed') {
        buttons.add(
          Expanded(
            child: CustomButton(
              text: 'Marquer comme terminée',
              onPressed: _navigateToCompletionPage, // This should lead to updating status to 'waiting_confirmation'
              backgroundColor: isDarkMode ? Colors.blue.shade700 : Colors.blue.shade600,
              textColor: Colors.white,
            ),
          ),
        );
        // Small orange square reclamation button next to "Marquer comme terminée"
        if (canSubmitReclamation) {
          buttons.add(const SizedBox(width: AppSpacing.sm));
          buttons.add(
            SizedBox(
              width: AppSpacing.buttonMedium, // Ensure this is a good size for a square button
              height: AppSpacing.buttonMedium,
              child: ElevatedButton(
                onPressed: () {
                  context.push('/prestataireHome/reclamation/create/${widget.reservationId}');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.warningOrange,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm), // Smaller radius for square feel
                  ),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24.0), // Triangle with ! icon
              ),
            ),
          );
        }
      } else {
        // This case implies providerCompletionStatus == 'completed' but status is still 'approved'.
        // This might happen if the status update to 'waiting_confirmation' hasn't propagated yet or if there's a different flow.
        // For now, let's assume if providerCompletionStatus is 'completed', the status should ideally be 'waiting_confirmation'.
        // If for some reason it's 'approved' and 'completed', we show the reclamation button.
        if (canSubmitReclamation) {
           buttons.add(
            Expanded(
              child: CustomButton(
                text: 'Soumettre une réclamation',
                icon: const Icon(Icons.report_problem, color: Colors.white),
                onPressed: () {
                  context.push('/prestataireHome/reclamation/create/${widget.reservationId}');
                },
                isPrimary: false,
                backgroundColor: AppColors.warningOrange,
                textColor: Colors.white,
                height: AppSpacing.buttonMedium,
              ),
            ),
          );
        }
      }
    } else if (status == 'waiting_confirmation') {
      // Provider has marked as done, client needs to confirm. Provider can submit reclamation.
      if (canSubmitReclamation) {
        buttons.add(
          Expanded(
            child: CustomButton(
              text: 'Soumettre une réclamation',
              icon: const Icon(Icons.report_problem, color: Colors.white), // Using report_problem as a general reclamation icon
              onPressed: () {
                context.push('/prestataireHome/reclamation/create/${widget.reservationId}');
              },
              isPrimary: false, // It's an orange button
              backgroundColor: AppColors.warningOrange,
              textColor: Colors.white,
              height: AppSpacing.buttonMedium, // Full width
            ),
          ),
        );
      }
    } else if (status == 'completed') {
      // Intervention is fully completed and confirmed by client. Provider can submit reclamation.
      if (canSubmitReclamation) {
        buttons.add(
          Expanded(
            child: CustomButton(
              text: 'Soumettre une réclamation',
              icon: const Icon(Icons.report_problem, color: Colors.white),
              onPressed: () {
                context.push('/prestataireHome/reclamation/create/${widget.reservationId}');
              },
              isPrimary: false,
              backgroundColor: AppColors.warningOrange,
              textColor: Colors.white,
              height: AppSpacing.buttonMedium,
            ),
          ),
        );
      }
    }

    if (buttons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      color: isDarkMode ? Colors.grey.shade900 : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm), // Standard padding
      child: SafeArea(
        child: Row(
          mainAxisAlignment: buttons.length == 1 ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween, // Center if one button
          children: buttons,
        ),
      ),
    );
  }
}
