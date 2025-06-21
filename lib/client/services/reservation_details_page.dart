import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:go_router/go_router.dart';
import '../../front/app_colors.dart';
import '../../front/app_typography.dart';
import '../../front/custom_app_bar.dart';
import '../../front/custom_button.dart';
import '../../front/loading_overlay.dart';
import '../../utils/image_gallery_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../front/provider_rating_dialog.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../front/app_spacing.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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

  // Map related variables
  GoogleMapController? _googleMapController;
  Set<Marker> _markers = {};
  LatLng? _reservationLatLng;

  // Cancellation reasons
  final List<String> _predefinedCancellationReasons = [
    'Le prestataire ne répond pas',
    'Je n\'ai plus besoin du service',
    'J\'ai trouvé un autre prestataire',
    'Autre',
  ];
  String? _selectedCancellationReason;

  @override
  void initState() {
    super.initState();
    // Initialize French locale data
    initializeDateFormatting('fr_FR', null).then((_) {
      _fetchReservationDetails();
    });
  }

  @override
  void dispose() {
    _googleMapController?.dispose();
    super.dispose();
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
            final userDocData = userDoc.data();
            // Prioritize avatarUrl/avatarURL, then photoURL for the provider's image
            final String providerImageURL = userDocData?['avatarUrl'] ?? userDocData?['avatarURL'] ?? userDocData?['photoURL'] ?? '';
            
            // Merge user data into provider data for easy access
            setState(() {
              _providerData!.addAll({
                'firstname': userDocData?['firstname'] ?? '',
                'lastname': userDocData?['lastname'] ?? '',
                'phone': userDocData?['phone'] ?? '',
                'photoURL': providerImageURL, // Use the determined image URL
              });
            });
          }
        }
      }

      // Extract location data for map
      final locationData = reservationData['location'] as Map<String, dynamic>?;
      if (locationData != null && locationData['latitude'] != null && locationData['longitude'] != null) {
        _reservationLatLng = LatLng(
          (locationData['latitude'] as num).toDouble(),
          (locationData['longitude'] as num).toDouble(),
        );
        _markers = {
          Marker(
            markerId: const MarkerId('reservation_location'),
            position: _reservationLatLng!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          ),
        };
      } else {
        _reservationLatLng = null;
        _markers = {};
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
        builder: (context) {
          final isDarkMode = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
            title: Text(
              'Confirmer l\'intervention',
              style: AppTypography.headlineMedium(context),
            ),
            content: Text(
              'Êtes-vous sûr de vouloir confirmer que l\'intervention a été réalisée?',
              style: AppTypography.bodyMedium(context),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'Annuler',
                  style: AppTypography.button(context, color: AppColors.primaryDarkGreen),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  'Confirmer',
                  style: AppTypography.button(context, color: AppColors.primaryDarkGreen),
                ),
              ),
            ],
          );
        },
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
              style: AppTypography.bodyMedium(context),
            ),
            backgroundColor: AppColors.successGreen,
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
              style: AppTypography.bodyMedium(context),
            ),
            backgroundColor: AppColors.errorRed,
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
    
    // Show ProviderRatingDialog using showDialog for correct scrim behavior
    showDialog(
      context: context,
      barrierDismissible: false, // User must submit or cancel
      barrierColor: Colors.black.withOpacity(0.5), // Explicitly set semi-transparent scrim
      builder: (BuildContext dialogContext) {
        return ProviderRatingDialog(
          providerId: providerId,
          providerName: providerName,
          reservationId: widget.reservationId,
          onRatingSubmitted: () {
            // This callback is executed after the dialog is popped by _submitRating in ProviderRatingDialog
            FirebaseFirestore.instance
                .collection('reservations')
                .doc(widget.reservationId)
                .update({'rated': true})
                .then((_) {
                  if (mounted) {
                    _fetchReservationDetails(); // Refresh the details on the underlying page
                  }
                });
            
            // The SnackBar is already shown within ProviderRatingDialog upon successful submission.
            // If an additional SnackBar is needed here, ensure context is valid.
            // For now, relying on the SnackBar from ProviderRatingDialog.
          },
        );
      },
    );
  }

  Future<void> _cancelReservation() async {
    try {
      final reasonController = TextEditingController();
      String? finalReason;

      final result = await showDialog<String?>(
        context: context,
        builder: (dialogContext) { // Use dialogContext to manage dialog's state
          final isDarkMode = Theme.of(dialogContext).brightness == Brightness.dark;
          return StatefulBuilder(
            builder: (context, setState) { // Use setState for StatefulBuilder
              return AlertDialog(
                backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
                title: Text(
                  'Annuler la réservation',
                  style: AppTypography.headlineMedium(context),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Êtes-vous sûr de vouloir annuler cette réservation? Veuillez sélectionner un motif:',
                        style: AppTypography.bodyMedium(context),
                      ),
                      AppSpacing.verticalSpacing(AppSpacing.md),
                      ..._predefinedCancellationReasons.map((reason) {
                        return RadioListTile<String>(
                          title: Text(
                            reason,
                            style: AppTypography.bodyMedium(context, color: isDarkMode ? AppColors.darkTextColor : AppColors.lightTextColor),
                          ),
                          value: reason,
                          groupValue: _selectedCancellationReason,
                          onChanged: (String? value) {
                            setState(() {
                              _selectedCancellationReason = value;
                            });
                          },
                          activeColor: AppColors.primaryGreen,
                          contentPadding: EdgeInsets.zero,
                        );
                      }).toList(),
                      
                      if (_selectedCancellationReason == 'Autre') ...[
                        AppSpacing.verticalSpacing(AppSpacing.md),
                        Text(
                          'Motif personnalisé:',
                          style: AppTypography.bodyMedium(context),
                        ),
                        AppSpacing.verticalSpacing(AppSpacing.xs),
                        TextField(
                          controller: reasonController,
                          decoration: InputDecoration(
                            hintText: 'Expliquez pourquoi vous annulez...',
                            hintStyle: AppTypography.bodyMedium(context, color: isDarkMode ? AppColors.darkHintColor : AppColors.lightHintColor),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                              borderSide: BorderSide(color: isDarkMode ? AppColors.darkBorderColor : AppColors.lightBorderColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                              borderSide: BorderSide(color: isDarkMode ? AppColors.darkBorderColor : AppColors.lightBorderColor),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                              borderSide: BorderSide(color: AppColors.primaryGreen),
                            ),
                            filled: true,
                            fillColor: isDarkMode ? AppColors.darkInputBackground : AppColors.lightInputBackground,
                          ),
                          style: AppTypography.bodyMedium(context, color: isDarkMode ? AppColors.darkTextColor : AppColors.lightTextColor),
                          maxLines: 3,
                        ),
                      ],
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: Text(
                      'Retour',
                      style: AppTypography.button(context, color: AppColors.primaryDarkGreen),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      if (_selectedCancellationReason == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Veuillez sélectionner un motif d\'annulation', style: AppTypography.bodyMedium(context)),
                            backgroundColor: AppColors.errorRed,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      if (_selectedCancellationReason == 'Autre' && reasonController.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Veuillez spécifier le motif personnalisé', style: AppTypography.bodyMedium(context)),
                            backgroundColor: AppColors.errorRed,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      Navigator.of(context).pop(_selectedCancellationReason == 'Autre' ? reasonController.text.trim() : _selectedCancellationReason);
                    },
                    child: Text(
                      'Confirmer',
                      style: AppTypography.button(context, color: AppColors.errorRed),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
      
      if (result == null) return; // User cancelled the dialog
      
      finalReason = result;
      if (finalReason.isEmpty) finalReason = 'Aucun motif fourni';
      
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
      });
      
      // Send notification to provider
      final providerId = _reservationData?['providerId'];
      if (providerId != null) {
        await FirebaseFirestore.instance
            .collection('users')         // Target the 'users' collection
            .doc(providerId)             // The document ID is the provider's user ID
            .collection('notifications') // The subcollection for notifications
            .add({
          'userId': providerId, // Field indicating who this notification is for (the provider)
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
              style: AppTypography.bodyMedium(context),
            ),
            backgroundColor: AppColors.successGreen,
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
              style: AppTypography.bodyMedium(context),
            ),
            backgroundColor: AppColors.errorRed,
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

  Future<void> _openInGoogleMaps() async {
    if (_reservationLatLng == null) return;
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${_reservationLatLng!.latitude},${_reservationLatLng!.longitude}');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Impossible d\'ouvrir Maps', style: AppTypography.bodySmall(context))),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'ouverture de Maps: $e', style: AppTypography.bodySmall(context))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return WillPopScope(
      onWillPop: () async {
        context.go('/clientHome/my-reservations'); 
        return false;
      },
      child: Scaffold(
        backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightInputBackground,
        appBar: CustomAppBar(
          title: 'Détails de la réservation',
          showBackButton: true,
          onBackPressed: () {
            context.go('/clientHome/my-reservations'); 
          },
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen))
            : _errorMessage.isNotEmpty
                ? Center(
                    child: Text(
                      _errorMessage,
                      style: AppTypography.bodyMedium(context, color: AppColors.errorRed),
                      textAlign: TextAlign.center,
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.screenPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status section (enhanced display)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: _getStatusColor(_reservationData?['status'], isDarkMode).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            border: Border.all(
                              color: _getStatusColor(_reservationData?['status'], isDarkMode),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getStatusIcon(_reservationData?['status']), // New helper for icon
                                    color: _getStatusColor(_reservationData?['status'], isDarkMode),
                                    size: AppSpacing.iconMd,
                                  ),
                                  AppSpacing.horizontalSpacing(AppSpacing.sm),
                                  Text(
                                    _getStatusText(_reservationData?['status']),
                                    style: AppTypography.headlineMedium(context, color: _getStatusColor(_reservationData?['status'], isDarkMode)),
                                  ),
                                ],
                              ),
                              if (_reservationData?['status'] == 'rejected' && 
                                  _reservationData?['rejectionReason'] != null) ...[
                                AppSpacing.verticalSpacing(AppSpacing.xs),
                                Text(
                                  'Motif: ${_reservationData!['rejectionReason']}',
                                  style: AppTypography.bodySmall(context, color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                              if (_reservationData?['status'] == 'cancelled' && 
                                  _reservationData?['cancellationReason'] != null) ...[
                                AppSpacing.verticalSpacing(AppSpacing.xs),
                                Text(
                                  'Motif: ${_reservationData!['cancellationReason']}',
                                  style: AppTypography.bodySmall(context, color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                        ),
                        
                        AppSpacing.verticalSpacing(AppSpacing.sectionSpacing),
                        
                        // Provider info section (now in a card-like container)
                        Text(
                          'Prestataire',
                          style: AppTypography.h4(context, color: isDarkMode ? AppColors.darkTextColor : AppColors.lightTextColor),
                        ),
                        AppSpacing.verticalSpacing(AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: isDarkMode ? AppColors.darkCardBackground : AppColors.lightCardBackground,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            border: Border.all(
                              color: isDarkMode ? AppColors.darkBorderColor : AppColors.lightBorderColor,
                            ),
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
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: AppSpacing.iconXl,
                                    backgroundColor: isDarkMode ? AppColors.darkBorder : AppColors.lightBorder,
                                    backgroundImage: _providerData?['photoURL'] != null
                                        ? NetworkImage(_providerData!['photoURL'])
                                        : null,
                                    child: _providerData?['photoURL'] == null
                                        ? Icon(Icons.person, size: AppSpacing.iconXl, color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)
                                        : null,
                                  ),
                                  AppSpacing.horizontalSpacing(AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${_providerData?['firstname'] ?? ''} ${_providerData?['lastname'] ?? ''}',
                                          style: AppTypography.headlineMedium(context, color: isDarkMode ? AppColors.darkTextColor : AppColors.lightTextColor),
                                        ),
                                        AppSpacing.verticalSpacing(AppSpacing.xs),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.phone,
                                              size: AppSpacing.iconXs,
                                              color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                                            ),
                                            AppSpacing.horizontalSpacing(AppSpacing.xs),
                                            Text(
                                              _providerData?['phone'] ?? 'Non disponible',
                                              style: AppTypography.bodyMedium(context, color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              AppSpacing.verticalSpacing(AppSpacing.md),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildContactButton(
                                      icon: Icons.phone_outlined,
                                      label: 'Appeler',
                                      onTap: () async {
                                        final phone = _providerData?['phone'];
                                        if (phone != null && phone.isNotEmpty) {
                                          final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
                                          final Uri phoneUri = Uri(scheme: 'tel', path: cleanPhone);
                                          try {
                                            await launchUrl(phoneUri);
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Impossible d\'ouvrir: $e', style: AppTypography.bodySmall(context).copyWith(color: Colors.white)), backgroundColor: AppColors.errorLightRed));
                                            }
                                          }
                                        } else {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Numéro non disponible', style: AppTypography.bodySmall(context).copyWith(color: Colors.white)), backgroundColor: AppColors.warningOrange));
                                          }
                                        }
                                      },
                                      isDarkMode: isDarkMode,
                                      primaryColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                                    ),
                                  ),
                                  AppSpacing.horizontalSpacing(AppSpacing.sm),
                                  Expanded(
                                    child: _buildContactButton(
                                      icon: Icons.chat_bubble_outline_rounded,
                                      label: 'Message',
                                      onTap: _contactProvider,
                                      isDarkMode: isDarkMode,
                                      primaryColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        AppSpacing.verticalSpacing(AppSpacing.sectionSpacing),
                        
                        // Service details section (now in a card-like container)
                        Text(
                          'Détails du service',
                          style: AppTypography.h4(context, color: isDarkMode ? AppColors.darkTextColor : AppColors.lightTextColor),
                        ),
                        AppSpacing.verticalSpacing(AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: isDarkMode ? AppColors.darkCardBackground : AppColors.lightCardBackground,
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                            border: Border.all(
                              color: isDarkMode ? AppColors.darkBorderColor : AppColors.lightBorderColor,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildInfoRow(
                                'Service',
                                _reservationData?['serviceName'] ?? 'Non défini',
                                Icons.home_repair_service,
                                isDarkMode,
                              ),
                              AppSpacing.verticalSpacing(AppSpacing.sm), // Add spacing between rows
                              if (_reservationData?['isImmediate'] == true) ...[
                                _buildInfoRow(
                                  'Type d\'intervention',
                                  'Intervention immédiate',
                                  Icons.flash_on,
                                  isDarkMode,
                                ),
                                AppSpacing.verticalSpacing(AppSpacing.sm), // Add spacing between rows
                              ],
                              _buildInfoRow(
                                'Adresse',
                                _reservationData?['address'] ?? 'Non défini',
                                Icons.location_on,
                                isDarkMode,
                              ),
                              AppSpacing.verticalSpacing(AppSpacing.sm), // Add spacing between rows
                              _buildInfoRow(
                                'Description',
                                _reservationData?['description'] ?? 'Aucune description',
                                Icons.description,
                                isDarkMode,
                              ),
                              AppSpacing.verticalSpacing(AppSpacing.sm), // Add spacing between rows
                              _buildInfoRow(
                                'Créée le',
                                _formatTimestamp(_reservationData?['createdAt']),
                                Icons.calendar_today,
                                isDarkMode,
                              ),
                              if (_reservationData?['completedAt'] != null) ...[
                                AppSpacing.verticalSpacing(AppSpacing.sm), // Add spacing between rows
                                _buildInfoRow(
                                  'Réalisée le',
                                  _formatTimestamp(_reservationData?['completedAt']),
                                  Icons.check_circle_outline,
                                  isDarkMode,
                                ),
                              ],
                              // Moved from "Informations complémentaires"
                              if (_reservationData?['updatedAt'] != null) ...[
                                AppSpacing.verticalSpacing(AppSpacing.sm), // Add spacing between rows
                                _buildInfoRow(
                                  'Mise à jour le',
                                  _formatTimestamp(_reservationData?['updatedAt']),
                                  Icons.update,
                                  isDarkMode,
                                ),
                              ],
                              if (_reservationData?['responseMessage'] != null && _reservationData!['responseMessage'].toString().isNotEmpty) ...[
                                AppSpacing.verticalSpacing(AppSpacing.sm), // Add spacing between rows
                                _buildInfoRow(
                                  'Message du prestataire',
                                  _reservationData?['responseMessage'],
                                  Icons.message,
                                  isDarkMode,
                                ),
                              ],
                            ],
                          ),
                        ),
                        
                        // Display images using ImageGalleryUtils
                        if (_reservationData?['imageUrls'] != null && 
                            (_reservationData!['imageUrls'] as List).isNotEmpty) ...[
                          AppSpacing.verticalSpacing(AppSpacing.sectionSpacing),
                          Text(
                            'Photos',
                            style: AppTypography.h4(context, color: isDarkMode ? AppColors.darkTextColor : AppColors.lightTextColor),
                          ),
                          AppSpacing.verticalSpacing(AppSpacing.sm),
                          ImageGalleryUtils.buildImageGallery(
                            context, 
                            List<String>.from(_reservationData!['imageUrls']),
                            isDarkMode: isDarkMode,
                          ),
                        ],
                        
                        // Map section (moved to after photos)
                        if (_reservationLatLng != null) ...[
                          AppSpacing.verticalSpacing(AppSpacing.sectionSpacing),
                          Text(
                            'Localisation',
                            style: AppTypography.h4(context, color: isDarkMode ? AppColors.darkTextColor : AppColors.lightTextColor),
                          ),
                          AppSpacing.verticalSpacing(AppSpacing.sm),
                          Container(
                            height: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                              border: Border.all(
                                color: isDarkMode ? AppColors.darkBorderColor : AppColors.lightBorderColor,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                              child: GestureDetector(
                                onTap: _openInGoogleMaps,
                                child: GoogleMap(
                                  mapType: MapType.normal,
                                  initialCameraPosition: CameraPosition(
                                    target: _reservationLatLng!,
                                    zoom: 15.0,
                                  ),
                                  onMapCreated: (GoogleMapController controller) {
                                    _googleMapController = controller;
                                  },
                                  markers: _markers,
                                  zoomControlsEnabled: false,
                                  scrollGesturesEnabled: false,
                                  tiltGesturesEnabled: false,
                                  rotateGesturesEnabled: false,
                                  myLocationButtonEnabled: false,
                                  myLocationEnabled: false,
                                ),
                              ),
                            ),
                          ),
                        ],
                        
                        AppSpacing.verticalSpacing(AppSpacing.xxl),
                        
                        // View reclamation button if one exists (remains in body) - REMOVED AS PER REQUEST
                        // if (_reservationData?['hasReclamation'] == true) ...[  
                        //   AppSpacing.verticalSpacing(AppSpacing.lg),
                        //   SizedBox(
                        //     width: double.infinity,
                        //     child: CustomButton(
                        //       onPressed: () async {
                        //         // Fetch the reclamation ID
                        //         final reclamationsSnapshot = await FirebaseFirestore.instance
                        //             .collection('reclamations')
                        //             .where('reservationId', isEqualTo: widget.reservationId)
                        //             .limit(1)
                        //             .get();
                        //       
                        //         if (reclamationsSnapshot.docs.isNotEmpty) {
                        //           final reclamationId = reclamationsSnapshot.docs.first.id;
                        //           if (mounted) {
                        //             context.push('/clientHome/reclamations/details/$reclamationId');
                        //           }
                        //         }
                        //       },
                        //       text: 'Voir ma réclamation',
                        //       icon: const Icon(Icons.visibility, color: Colors.white),
                        //       isPrimary: true,
                        //       backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                        //       textColor: AppColors.darkTextColor, // This will be overridden by foregroundColor in CustomButton
                        //       height: AppSpacing.buttonMedium,
                        //     ),
                        //   ),
                        // ],
                      ],
                    ),
                  ),
        bottomNavigationBar: _buildBottomNavigationBar(isDarkMode),
      ),
    );
  }

  // Removed _buildInfoCard method as per user request to remove cards.
  // The content of _buildInfoCard is now inlined directly in the build method.

  Widget _buildInfoRow(String label, String value, IconData icon, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: AppSpacing.iconSm,
              color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
            ),
            AppSpacing.horizontalSpacing(AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.bodySmall(context, color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  ),
                  AppSpacing.verticalSpacing(AppSpacing.xxs),
                  Text(
                    value,
                    style: AppTypography.bodyMedium(context, color: isDarkMode ? AppColors.darkTextColor : AppColors.lightTextColor),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getStatusColor(String? status, bool isDarkMode) {
    switch (status) {
      case 'pending':
        return AppColors.warningOrange;
      case 'approved':
        return AppColors.primaryGreen;
      case 'completed':
        return AppColors.successGreen;
      case 'rejected':
        return AppColors.errorRed;
      case 'cancelled':
        return isDarkMode ? Colors.white : AppColors.lightBorder; // White in dark mode, light grey in light mode
      case 'waiting_confirmation': 
        return Colors.purple.shade600; // Purple for waiting for client's confirmation
      default:
        return isDarkMode ? AppColors.darkBorder : AppColors.lightBorder;
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
      case 'waiting_confirmation': 
        return 'En attente de confirmation'; // Text for client side
      default:
        return 'Statut inconnu';
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty_rounded;
      case 'approved':
        return Icons.check_circle_outline_rounded;
      case 'completed':
        return Icons.task_alt_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      case 'cancelled':
        return Icons.highlight_off_rounded;
      case 'waiting_confirmation': 
        return Icons.pending_actions_rounded; // Icon for client side
      default:
        return Icons.info_outline_rounded;
    }
  }

  Widget _buildContactButton({required IconData icon, required String label, required VoidCallback onTap, required bool isDarkMode, required Color primaryColor}) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: AppSpacing.iconSm, color: primaryColor),
      label: Text(label, style: AppTypography.button(context).copyWith(color: primaryColor)),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        padding: EdgeInsets.symmetric(vertical: AppSpacing.md, horizontal: AppSpacing.lg),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg), side: BorderSide(color: primaryColor, width: 1.5)),
        elevation: 0,
      ),
    );
  }

  Widget _buildBottomNavigationBar(bool isDarkMode) {
    final status = _reservationData?['status'] as String?;
    // 'providerCompletionStatus' is relevant for client to know if provider marked as done.
    // Let's assume 'providerCompletionStatus' == 'completed' means the status should be 'waiting_confirmation'.
    // final bool isProviderMarkedDone = _reservationData?['providerCompletionStatus'] == 'completed';
    final bool canSubmitReclamation = _reservationData?['hasReclamation'] != true; // Assuming 'hasReclamation' means an active one exists.

    List<Widget> buttons = [];

    if (status == 'pending') {
      buttons.add(
        Expanded(
          child: CustomButton(
            text: 'Annuler la réservation',
            icon: const Icon(Icons.cancel, color: Colors.white),
            onPressed: _cancelReservation,
            isPrimary: false,
            backgroundColor: AppColors.errorRed,
            textColor: Colors.white, // Ensure text is white on red button
            height: AppSpacing.buttonMedium,
          ),
        ),
      );
    } else if (status == 'approved') {
      // If reservation is approved by provider, but provider has NOT YET marked it as done.
      // Client sees an orange button to submit a reclamation.
      if (canSubmitReclamation) {
        buttons.add(
          Expanded(
            child: CustomButton(
              text: 'Soumettre une réclamation',
              icon: const Icon(Icons.report_problem, color: Colors.white),
              onPressed: () {
                context.push('/clientHome/reclamations/create/${widget.reservationId}');
              },
              isPrimary: false, // It's an orange button
              backgroundColor: AppColors.warningOrange,
              textColor: Colors.white, // Ensure text is white
              height: AppSpacing.buttonMedium,
            ),
          ),
        );
      }
    } else if (status == 'waiting_confirmation') {
      // Provider has marked as done, client needs to confirm.
      // Client sees "Confirmer l'achèvement" and a small square reclamation icon button.
      buttons.add(
        Expanded(
          child: CustomButton(
            text: "Confirmer", // Shortened text
            icon: const Icon(Icons.check_circle_outline, color: Colors.white),
            onPressed: _confirmCompletion, // This will change status to 'completed' and trigger rating
            isPrimary: true, // Main action button
            backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
            textColor: Colors.white,
            height: AppSpacing.buttonMedium,
          ),
        ),
      );

      if (canSubmitReclamation) {
        buttons.add(AppSpacing.horizontalSpacing(AppSpacing.sm)); // Spacing
        buttons.add(
          SizedBox(
            width: AppSpacing.buttonMedium, // Square button
            height: AppSpacing.buttonMedium,
            child: ElevatedButton(
              onPressed: () {
                context.push('/clientHome/reclamations/create/${widget.reservationId}');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.warningOrange,
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24.0), // Triangle with !
            ),
          ),
        );
      }
    } else if (status == 'completed') {
      // Intervention is fully completed and confirmed by client. Client can submit reclamation.
      // (Rating should have already occurred when transitioning to 'completed')
      if (canSubmitReclamation) {
        buttons.add(
          Expanded(
            child: CustomButton(
              text: 'Soumettre une réclamation',
              icon: const Icon(Icons.report_problem, color: Colors.white),
              onPressed: () {
                context.push('/clientHome/reclamations/create/${widget.reservationId}');
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
    // No buttons for 'rejected' or 'cancelled' status in the bottom bar as per current logic.

    if (buttons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      color: isDarkMode ? Colors.grey.shade900 : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: buttons.length == 1 ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
          children: buttons,
        ),
      ),
    );
  }
  
  void _contactProvider() {
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Vous devez être connecté pour envoyer un message',
            style: AppTypography.bodyMedium(context),
          ),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
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
            style: AppTypography.bodyMedium(context),
          ),
          backgroundColor: AppColors.errorRed,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    
    final providerName = _providerData != null 
        ? '${_providerData!['firstname'] ?? ''} ${_providerData!['lastname'] ?? ''}'
        : 'Prestataire';
    
    context.push(
      '/clientHome/marketplace/chat/conversation/$providerId',
      extra: {
        'otherUserName': providerName,
      },
    );
  }
}
