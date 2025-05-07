import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../front/app_colors.dart';
import '../front/custom_app_bar.dart';
import '../front/custom_button.dart';
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
  
  // Add these new variables for completion functionality
  final TextEditingController _completionDescriptionController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadReservationData();
  }
  
  @override
  void dispose() {
    _completionDescriptionController.dispose();
    super.dispose();
  }
  
  Future<void> _loadReservationData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get reservation data
      final reservationDoc = await FirebaseFirestore.instance
          .collection('reservations')
          .doc(widget.reservationId)
          .get();
      
      if (!reservationDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Réservation introuvable')),
          );
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
      
      if (mounted) {
        setState(() {
          _reservationData = reservationData;
          _userData = userData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'approved'
                  ? 'Demande acceptée avec succès'
                  : 'Demande refusée avec succès',
            ),
            backgroundColor: status == 'approved' ? Colors.green : Colors.red,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Numéro de téléphone non disponible')),
        );
      }
      return;
    }
    
    // Simply open the dialer with the phone number
    final phoneUri = Uri(scheme: 'tel', path: phone);
    
    try {
      await launchUrl(phoneUri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Impossible d\'ouvrir le composeur téléphonique')),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vous devez être connecté pour contacter le client')),
        );
      }
      return;
    }

    if (currentUser.uid == userId) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vous ne pouvez pas contacter votre propre réservation')),
        );
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
        clientName = clientName.trim().isNotEmpty ? clientName : 'Client';
      }
      
      // Create chat ID from user IDs
      
      // Navigate to chat screen with the properly formatted chat ID and user name
      if (mounted) {
        setState(() => _isLoading = false);
        context.push('/prestataireHome/chat/conversation/$userId', extra: {
          'otherUserName': clientName,
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'accès au chat: $e')),
        );
      }
    }
  }
  
  void _showConfirmationDialog(String action) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? AppColors.darkBackground : Colors.white,
        title: Text(
          action == 'approve' 
              ? 'Accepter la demande' 
              : 'Refuser la demande',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        content: Text(
          action == 'approve'
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
              _updateReservationStatus(action == 'approve' ? 'approved' : 'rejected');
            },
            child: Text(
              'Confirmer',
              style: GoogleFonts.poppins(
                color: action == 'approve'
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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return Scaffold(
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
    final address = _reservationData!['address'] as String? ?? '';
    final imageUrls = List<String>.from(_reservationData!['imageUrls'] ?? []);
    final isImmediate = _reservationData!['isImmediate'] as bool? ?? false;
    final serviceName = _reservationData!['serviceName'] as String? ?? 'Service non spécifié';
    final status = _reservationData!['status'] as String? ?? 'pending';
    final providerCompletionStatus = _reservationData!['providerCompletionStatus'] as String? ?? '';
    
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
    final userPhoto = _userData?['photoURL'] as String? ?? '';
    
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
              color: isDarkMode ? AppColors.darkInputBackground : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
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
                    
                    // Call button
                    IconButton(
                      onPressed: _makePhoneCall,
                      icon: Icon(
                        Icons.call,
                        color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                      ),
                      tooltip: 'Appeler',
                    ),
                    IconButton(
                  onPressed: _navigateToChat,
                  icon: Icon(
                    Icons.chat_bubble_outline,
                    color: AppColors.primaryGreen,
                  ),
                  tooltip: 'Message',
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
              color: isDarkMode ? AppColors.darkInputBackground : Colors.white,
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
                    
                    const SizedBox(height: 12),
                    
                    // Address
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 20,
                          color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Adresse:',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            address.isEmpty ? 'Non spécifiée' : address,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
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
              color: isDarkMode ? AppColors.darkInputBackground : Colors.white,
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
            
            // Action buttons
            if (status == 'pending') ...[
              Row(
                children: [
                  // Reject button
                  Expanded(
                    child: CustomButton(
                      onPressed: () => _showConfirmationDialog('reject'),
                      text: 'Refuser',
                      backgroundColor: isDarkMode ? Colors.red.shade800 : Colors.red.shade600,
                      textColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Accept button
                  Expanded(
                    child: CustomButton(
                      onPressed: () => _showConfirmationDialog('approve'),
                      text: 'Accepter',
                      backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                      textColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
            
            // Add "Mark as Completed" button for approved reservations
            if (status == 'approved' && providerCompletionStatus != 'completed') ...[
              const SizedBox(height: 24),
              CustomButton(
                onPressed: _navigateToCompletionPage,
                text: 'Marquer comme terminée',
                backgroundColor: isDarkMode ? Colors.blue.shade700 : Colors.blue.shade600,
                textColor: Colors.white,
              ),
            ],
            
            // Show completion status if provider has marked it as completed
            if (status == 'approved' && providerCompletionStatus == 'completed') ...[
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.purple, width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.hourglass_bottom,
                      color: Colors.purple,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Vous avez marqué cette intervention comme terminée. En attente de confirmation du client.',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.purple,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
