import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:go_router/go_router.dart';
import '../../front/app_colors.dart';
import '../../front/custom_app_bar.dart';
import '../../front/custom_button.dart';
import '../../front/loading_overlay.dart';
import '../../utils/image_gallery_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../front/provider_rating_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  Map<String, dynamic>? _providerData;
  String _errorMessage = '';
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    // Initialize French locale data
    initializeDateFormatting('fr_FR', null).then((_) {
      _fetchReservationDetails();
    });
  }

  Future<void> _fetchReservationDetails() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final reservationDoc = await FirebaseFirestore.instance
          .collection('reservations')
          .doc(widget.reservationId)
          .get();

      if (!reservationDoc.exists) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Réservation introuvable';
        });
        return;
      }

      final reservationData = reservationDoc.data()!;
      
      // Fetch provider data
      final providerId = reservationData['providerId'] as String?;
      if (providerId != null) {
        final providerDoc = await FirebaseFirestore.instance
            .collection('providers')
            .doc(providerId)
            .get();
            
        if (providerDoc.exists) {
          setState(() {
            _providerData = providerDoc.data();
          });
          
          // Also fetch user data for the provider to get name and phone
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(providerId)
              .get();
              
          if (userDoc.exists) {
            // Merge user data into provider data for easy access
            setState(() {
              _providerData!.addAll({
                'firstname': userDoc.data()?['firstname'] ?? '',
                'lastname': userDoc.data()?['lastname'] ?? '',
                'phone': userDoc.data()?['phone'] ?? '',
                'photoURL': userDoc.data()?['photoURL'] ?? '',
              });
            });
          }
        }
      }

      setState(() {
        _reservationData = reservationData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors du chargement des détails: $e';
      });
    }
  }

  Future<void> _confirmCompletion() async {
    try {
      // Show confirmation dialog
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Confirmer l\'intervention',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Êtes-vous sûr de vouloir confirmer que l\'intervention a été réalisée?',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Annuler',
                style: GoogleFonts.poppins(),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Confirmer',
                style: GoogleFonts.poppins(
                  color: AppColors.primaryDarkGreen,
                ),
              ),
            ),
          ],
        ),
      );
      
      if (confirm != true) return;
      
      LoadingOverlay.show(context);
      
      // Update reservation status
      await FirebaseFirestore.instance
          .collection('reservations')
          .doc(widget.reservationId)
          .update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      LoadingOverlay.hide();
      
      if (mounted) {
        // Refresh data
        await _fetchReservationDetails();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Intervention confirmée avec succès',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        // Show rating dialog
        _showRatingDialog();
      }
    } catch (e) {
      LoadingOverlay.hide();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur lors de la confirmation: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
  
    void _showRatingDialog() {
    if (_providerData == null || _reservationData == null) return;
    
    final providerId = _reservationData!['providerId'] as String?;
    if (providerId == null) return;
    
    final providerName = _providerData!['firstname'] != null && _providerData!['lastname'] != null
        ? '${_providerData!['firstname']} ${_providerData!['lastname']}'
        : 'Prestataire';
    
    // Navigate to the ProviderRatingDialog page instead of showing a dialog
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ProviderRatingDialog(
          providerId: providerId,
          providerName: providerName,
          reservationId: widget.reservationId,
          onRatingSubmitted: () {
            // Update the reservation to mark it as rated
            FirebaseFirestore.instance
                .collection('reservations')
                .doc(widget.reservationId)
                .update({'rated': true})
                .then((_) {
                  // Refresh the reservation data
                  _fetchReservationDetails();
                });
                
            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Merci pour votre évaluation!'),
                backgroundColor: Colors.green,
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _cancelReservation() async {
    try {
      // Show confirmation dialog with reason input
      final reasonController = TextEditingController();
      final result = await showDialog<Map<String, dynamic>?>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Annuler la réservation',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Êtes-vous sûr de vouloir annuler cette réservation?',
                style: GoogleFonts.poppins(),
              ),
              const SizedBox(height: 16),
              Text(
                'Motif d\'annulation (optionnel):',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  hintText: 'Expliquez pourquoi vous annulez...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(
                'Retour',
                style: GoogleFonts.poppins(),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop({
                'confirm': true,
                'reason': reasonController.text.trim(),
              }),
              child: Text(
                'Confirmer',
                style: GoogleFonts.poppins(
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
      );
      
      if (result == null || result['confirm'] != true) return;
      
      final reason = result['reason'] as String;
      final finalReason = reason.isEmpty ? 'Aucun motif fourni' : reason;
      
      LoadingOverlay.show(context);
      
      // Update reservation status
      await FirebaseFirestore.instance
          .collection('reservations')
          .doc(widget.reservationId)
          .update({
        'status': 'cancelled',
        'cancellationReason': finalReason,
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'cancelledBy': 'client',
      });
      
      // Send notification to provider
      final providerId = _reservationData?['providerId'];
      if (providerId != null) {
        await FirebaseFirestore.instance
            .collection('notifications')
            .add({
          'userId': providerId,
          'title': 'Réservation annulée',
          'body': 'Le client a annulé la réservation',
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
          'type': 'reservation_cancelled',
          'data': {
            'reservationId': widget.reservationId,
            'reason': finalReason,
          },
        });
      }
      
      LoadingOverlay.hide();
      
      if (mounted) {
        // Refresh data
        await _fetchReservationDetails();
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Réservation annulée avec succès',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      LoadingOverlay.hide();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur lors de l\'annulation: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Non disponible';
    
    final date = timestamp.toDate();
    return DateFormat('dd/MM/yyyy à HH:mm', 'fr_FR').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Détails de la réservation',
        showBackButton: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Text(
                    _errorMessage,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.red,
                    ),
                    textAlign: TextAlign.center,
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _getStatusColor(_reservationData?['status'], isDarkMode),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _getStatusText(_reservationData?['status']),
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            if (_reservationData?['status'] == 'rejected' && 
                                _reservationData?['rejectionReason'] != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Motif: ${_reservationData!['rejectionReason']}',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                            if (_reservationData?['status'] == 'cancelled' && 
                                _reservationData?['cancellationReason'] != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Motif: ${_reservationData!['cancellationReason']}',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Provider info
                      Text(
                        'Prestataire',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.grey.shade800.withOpacity(0.5) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
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
                            // Provider header with photo and basic info
                            Row(
                              children: [
                                // Provider photo
                                CircleAvatar(
                                  radius: 30,
                                  backgroundColor: Colors.grey.shade200,
                                  backgroundImage: _providerData?['photoURL'] != null
                                      ? NetworkImage(_providerData!['photoURL'])
                                      : null,
                                  child: _providerData?['photoURL'] == null
                                      ? const Icon(Icons.person, size: 40, color: Colors.grey)
                                      : null,
                                ),
                                const SizedBox(width: 16),
                                // Provider info - simplified to just name and phone
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${_providerData?['firstname'] ?? ''} ${_providerData?['lastname'] ?? ''}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: isDarkMode ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.phone,
                                            size: 16,
                                            color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _providerData?['phone'] ?? 'Non disponible',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              color: isDarkMode ? Colors.white70 : Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Contact buttons
                            Row(
                              children: [
                                // Call button
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      final phone = _providerData?['phone'];
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
                                    },
                                    icon: const Icon(Icons.call),
                                    label: Text(
                                      'Appeler',
                                      style: GoogleFonts.poppins(),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Message button
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _contactProvider,
                                    icon: const Icon(Icons.message),
                                    label: Text(
                                      'Message',
                                      style: GoogleFonts.poppins(),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey.shade700,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Service details
                      Text(
                        'Détails du service',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoCard(
                        isDarkMode,
                        [
                          _buildInfoRow(
                            'Service',
                            _reservationData?['serviceName'] ?? 'Non défini',
                            Icons.home_repair_service,
                            isDarkMode,
                          ),
                          if (_reservationData?['isImmediate'] == true)
                            _buildInfoRow(
                              'Type d\'intervention',
                              'Intervention immédiate',
                              Icons.flash_on,
                              isDarkMode,
                            ),
                          _buildInfoRow(
                            'Adresse',
                            _reservationData?['address'] ?? 'Non défini',
                            Icons.location_on,
                            isDarkMode,
                          ),
                          _buildInfoRow(
                            'Description',
                            _reservationData?['description'] ?? 'Aucune description',
                            Icons.description,
                            isDarkMode,
                          ),
                        ],
                      ),
                      
                      // Display images using ImageGalleryUtils
                      if (_reservationData?['imageUrls'] != null && 
                          (_reservationData!['imageUrls'] as List).isNotEmpty) ...[
                        const SizedBox(height: 24),
                        Text(
                          'Photos',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ImageGalleryUtils.buildImageGallery(
                          context, 
                          List<String>.from(_reservationData!['imageUrls']),
                          isDarkMode: isDarkMode,
                        ),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      // Dates information
                      Text(
                        'Informations complémentaires',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildInfoCard(
                        isDarkMode,
                        [
                          _buildInfoRow(
                            'Créée le',
                            _formatTimestamp(_reservationData?['createdAt']),
                            Icons.calendar_today,
                            isDarkMode,
                          ),
                          if (_reservationData?['updatedAt'] != null)
                            _buildInfoRow(
                              'Mise à jour le',
                              _formatTimestamp(_reservationData?['updatedAt']),
                              Icons.update,
                              isDarkMode,
                            ),
                          if (_reservationData?['responseMessage'] != null && _reservationData!['responseMessage'].toString().isNotEmpty)
                            _buildInfoRow(
                              'Message du prestataire',
                              _reservationData?['responseMessage'],
                              Icons.message,
                              isDarkMode,
                            ),
                        ],
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Actions - Only show cancel button when status is pending
                      if (_reservationData?['status'] == 'pending')
                        CustomButton(
                          text: 'Annuler la réservation',
                          icon: const Icon(Icons.cancel, color: Colors.white),
                          onPressed: _cancelReservation,
                          isPrimary: false,
                          backgroundColor: Colors.red,
                          textColor: Colors.white,
                        ),
                        
                      // Contact provider button for approved reservations
                      if (_reservationData?['status'] == 'approved')
                        CustomButton(
                          text: 'Contacter le prestataire',
                          icon: const Icon(Icons.chat, color: Colors.white),
                          onPressed: _contactProvider,
                          isPrimary: true,
                          backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                        ),
                        
                      // If completed, show review option
                      if (_reservationData?['status'] == 'completed' && (_reservationData?['rated'] == null || _reservationData?['rated'] == false))
                        Column(
                          children: [
                            const SizedBox(height: 16),
                            CustomButton(
                              text: 'Évaluer le service',
                              icon: const Icon(Icons.star, color: Colors.white),
                              onPressed: _showRatingDialog,
                              isPrimary: true,
                              backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                            ),
                          ],
                        ),
                      
                      // Provider completion section - show only if provider has marked as completed
                      if (_reservationData?['providerCompletionStatus'] == 'completed') ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Intervention réalisée',
                                    style: GoogleFonts.poppins(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: isDarkMode ? Colors.white : Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Le prestataire a marqué cette intervention comme terminée le:',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: isDarkMode ? Colors.white70 : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _reservationData?['providerCompletionTimestamp'] != null
                                    ? DateFormat('dd/MM/yyyy à HH:mm').format(
                                        (_reservationData?['providerCompletionTimestamp'] as Timestamp).toDate())
                                    : 'Date non disponible',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isDarkMode ? Colors.white : Colors.black,
                                ),
                              ),
                              
                              // Provider completion description
                              if (_reservationData?['providerCompletionDescription'] != null &&
                                  _reservationData!['providerCompletionDescription'].toString().isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Text(
                                  'Description des travaux réalisés:',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isDarkMode ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? Colors.grey.shade700 : Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Text(
                                    _reservationData!['providerCompletionDescription'],
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: isDarkMode ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                              
                              // Provider completion images
                              if (_reservationData?['providerCompletionImages'] != null &&
                                  (_reservationData!['providerCompletionImages'] as List).isNotEmpty) ...[
                                const SizedBox(height: 16),
                                Text(
                                  'Photos des travaux réalisés:',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isDarkMode ? Colors.white70 : Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  height: 120,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: (_reservationData!['providerCompletionImages'] as List).length,
                                    itemBuilder: (context, index) {
                                      final imageUrl = (_reservationData!['providerCompletionImages'] as List)[index];
                                      return GestureDetector(
                                        onTap: () {
                                          ImageGalleryUtils.openImageGallery(
                                            context,
                                            (_reservationData!['providerCompletionImages'] as List)
                                                .cast<String>(),
                                            initialIndex: index,
                                          );
                                        },
                                        child: Container(
                                          width: 120,
                                          height: 120,
                                          margin: const EdgeInsets.only(right: 8),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                            image: DecorationImage(
                                              image: NetworkImage(imageUrl),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                              
                              // Confirmation button
                              if (_reservationData?['status'] == 'approved') ...[
                                const SizedBox(height: 20),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () => _confirmCompletion(),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primaryGreen,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Text(
                                      'Confirmer l\'intervention',
                                      style: GoogleFonts.poppins(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      
                      // Confirmation button
                      if (_reservationData?['status'] == 'approved' && _reservationData?['providerCompletionStatus'] != 'completed') ...[
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _confirmCompletion(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Text(
                              'Confirmer l\'intervention',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _buildInfoCard(bool isDarkMode, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade800.withOpacity(0.5) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status, bool isDarkMode) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return AppColors.primaryGreen;
      case 'completed':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return isDarkMode ? Colors.grey.shade700 : Colors.grey.shade400;
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'approved':
        return 'Approuvée';
      case 'completed':
        return 'Terminée';
      case 'rejected':
        return 'Refusée';
      case 'cancelled':
        return 'Annulée';
      default:
        return 'Statut inconnu';
    }
  }
  
  void _contactProvider() {
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Vous devez être connecté pour envoyer un message',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final providerId = _reservationData?['providerId'] as String?;
    if (providerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible de contacter ce prestataire',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final providerName = _providerData != null 
        ? '${_providerData!['firstname'] ?? ''} ${_providerData!['lastname'] ?? ''}'
        : 'Prestataire';
    
    // Use GoRouter to navigate to chat screen
    context.push(
      '/clientHome/marketplace/chat/conversation/$providerId',
      extra: {
        'otherUserName': providerName,
      },
    );
  }
}