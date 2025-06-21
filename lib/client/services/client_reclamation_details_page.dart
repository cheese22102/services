import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Added
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../front/app_colors.dart';
import '../../front/custom_app_bar.dart';
import '../../front/app_spacing.dart'; // Added
import '../../front/app_typography.dart'; // Added
import '../../utils/image_gallery_utils.dart'; // Added for consistent image display
import '../../models/reclamation_model.dart';
import 'package:url_launcher/url_launcher.dart'; // Added for phone call

class ClientReclamationDetailsPage extends StatefulWidget {
  final String reclamationId;
  
  const ClientReclamationDetailsPage({
    super.key,
    required this.reclamationId,
  });

  @override
  State<ClientReclamationDetailsPage> createState() => _ClientReclamationDetailsPageState();
}

class _ClientReclamationDetailsPageState extends State<ClientReclamationDetailsPage> {
  bool _isLoading = true;
  ReclamationModel? _reclamation;
  Map<String, dynamic>? _reservationData;
  Map<String, dynamic>? _reclamationProviderData;
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  
  @override
  void initState() {
    super.initState();
    _loadReclamationData();
  }
  
  Future<void> _loadReclamationData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get reclamation data
      final reclamationDoc = await FirebaseFirestore.instance
          .collection('reclamations')
          .doc(widget.reclamationId)
          .get();
      
      if (!reclamationDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Réclamation introuvable', style: AppTypography.bodyMedium(context).copyWith(color: Colors.white)),
              backgroundColor: AppColors.errorRed,
            ),
          );
          context.pop();
        }
        return;
      }
      
      final reclamationData = reclamationDoc.data()!;
      final reclamation = ReclamationModel.fromMap(reclamationData, widget.reclamationId);
      
      // Get target data (the user who is the target of the reclamation)
      final targetDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(reclamation.targetId)
          .get();
      
      targetDoc.data();
      
      // Get reservation data
      final reservationDoc = await FirebaseFirestore.instance
          .collection('reservations')
          .doc(reclamation.reservationId)
          .get();
      
      final reservationData = reservationDoc.data();

      // Fetch provider data related to the reservation
      Map<String, dynamic>? providerData;
      if (reservationData != null && reservationData.containsKey('providerId')) {
        final providerId = reservationData['providerId'] as String;
        final providerDoc = await FirebaseFirestore.instance.collection('providers').doc(providerId).get();
        if (providerDoc.exists) {
          providerData = providerDoc.data();
          final providerUserDoc = await FirebaseFirestore.instance.collection('users').doc(providerId).get();
          if (providerUserDoc.exists) {
            providerData!.addAll(providerUserDoc.data()!); // Merge user data
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _reclamation = reclamation;
          _reservationData = reservationData;
          _reclamationProviderData = providerData; // Store provider data
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e', style: AppTypography.bodyMedium(context).copyWith(color: Colors.white)),
            backgroundColor: AppColors.errorRed,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Widget _buildStatusBadge(bool isDarkMode) {
    if (_reclamation == null) return const SizedBox();
    
    Color statusColor;
    String statusText;
    
    switch (_reclamation!.status) {
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'En attente';
        break;
      case 'resolved':
        statusColor = AppColors.primaryGreen; // Consistent color
        statusText = 'Résolue';
        break;
      case 'rejected':
        statusColor = AppColors.errorRed; // Consistent color
        statusText = 'Rejetée';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Inconnu';
    }
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm), // Use AppSpacing
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg), // Use AppSpacing
        border: Border.all(color: statusColor),
      ),
      child: Text(
        statusText,
        style: AppTypography.labelMedium(context).copyWith( // Use AppTypography
          fontWeight: FontWeight.w500,
          color: statusColor,
        ),
      ),
    );
  }
  
  Widget _buildReclamationProviderSection(bool isDarkMode) {
    if (_reclamationProviderData == null) return const SizedBox();
    
    final providerName = '${_reclamationProviderData!['firstname'] ?? ''} ${_reclamationProviderData!['lastname'] ?? ''}'.trim();
    final providerPhone = _reclamationProviderData!['phone'] ?? 'Non disponible';
    final providerPhotoURL = _reclamationProviderData!['avatarURL'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Prestataire',
          style: AppTypography.h4(context).copyWith(color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
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
                    backgroundImage: providerPhotoURL.isNotEmpty
                        ? NetworkImage(providerPhotoURL)
                        : null,
                    child: providerPhotoURL.isEmpty
                        ? Icon(Icons.person, size: AppSpacing.iconXl, color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)
                        : null,
                  ),
                  AppSpacing.horizontalSpacing(AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          providerName,
                          style: AppTypography.headlineMedium(context).copyWith(color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
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
                              providerPhone,
                              style: AppTypography.bodyMedium(context).copyWith(color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
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
                        if (providerPhone.isNotEmpty && providerPhone != 'Non disponible') {
                          final cleanPhone = providerPhone.replaceAll(RegExp(r'\D'), '');
                          final Uri phoneUri = Uri(scheme: 'tel', path: cleanPhone);
                          try {
                            await launchUrl(phoneUri);
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Impossible d\'ouvrir: $e', style: AppTypography.bodySmall(context).copyWith(color: Colors.white)), backgroundColor: AppColors.errorRed));
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
                      onTap: () => _contactProvider(providerId: _reclamationProviderData!['userId']!), // Added ! for non-null
                      isDarkMode: isDarkMode,
                      primaryColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildReservationSection(bool isDarkMode) {
    if (_reclamation == null || _reservationData == null) return const SizedBox();
    
    final serviceName = _reservationData!['serviceName'] ?? 'Service non spécifié';
    final reservationDate = _reservationData!['reservationDate'] != null
        ? (_reservationData!['reservationDate'] as Timestamp).toDate()
        : null;
    
    String formattedDate = 'Date non spécifiée';
    if (reservationDate != null) {
      formattedDate = DateFormat('dd/MM/yyyy à HH:mm').format(reservationDate);
    }
    
    return Container(
      padding: EdgeInsets.all(AppSpacing.md), // Use AppSpacing
      decoration: BoxDecoration(
        color: isDarkMode ? AppColors.darkCardBackground : AppColors.lightCardBackground, // Consistent color
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd), // Use AppSpacing
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Réservation',
            style: AppTypography.bodyLarge(context).copyWith( // Use AppTypography
              fontWeight: FontWeight.bold,
              color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, // Use AppColors
            ),
          ),
          AppSpacing.verticalSpacing(AppSpacing.xs), // Use AppSpacing
          Row(
            children: [
              Icon(Icons.handyman, size: AppSpacing.iconMd, color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,), // Use AppSpacing and AppColors
              AppSpacing.horizontalSpacing(AppSpacing.sm), // Use AppSpacing
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serviceName,
                      style: AppTypography.bodyLarge(context).copyWith( // Use AppTypography
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, // Use AppColors
                      ),
                    ),
                    Text(
                      formattedDate,
                      style: AppTypography.bodyMedium(context).copyWith( // Use AppTypography
                        color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, // Use AppColors
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
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightInputBackground, // Consistent background
      appBar: CustomAppBar(
        title: 'Détails de la réclamation',
        showBackButton: true,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
              ),
            )
          : _reclamation == null
              ? Center(
                  child: Text(
                    'Réclamation introuvable',
                    style: AppTypography.bodyMedium(context).copyWith(
                      color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.all(AppSpacing.screenPadding), // Use AppSpacing
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status badge
                      _buildStatusBadge(isDarkMode),
                      
                      AppSpacing.verticalSpacing(AppSpacing.md), // Use AppSpacing
                      
                      // Reclamation title
                      Text(
                        _reclamation!.title,
                        style: AppTypography.headlineSmall(context).copyWith( // Use AppTypography
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, // Use AppColors
                        ),
                      ),
                      
                      AppSpacing.verticalSpacing(AppSpacing.xs), // Use AppSpacing
                      
                      // Date
                      Text(
                        'Soumise le ${DateFormat('dd/MM/yyyy à HH:mm').format(_reclamation!.createdAt.toDate())}',
                        style: AppTypography.bodyMedium(context).copyWith( // Use AppTypography
                          color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, // Use AppColors
                        ),
                      ),
                      
                      AppSpacing.verticalSpacing(AppSpacing.lg), // Use AppSpacing
                      
                      // Provider section (formerly Target section)
                      _buildReclamationProviderSection(isDarkMode), // Changed to provider section
                      
                      AppSpacing.verticalSpacing(AppSpacing.lg), // Use AppSpacing
                      
                      // Reservation section
                      _buildReservationSection(isDarkMode),
                      
                      AppSpacing.verticalSpacing(AppSpacing.lg), // Use AppSpacing
                      
                      // Description
                      Text(
                        'Description',
                        style: AppTypography.headlineSmall(context).copyWith( // Use AppTypography
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, // Use AppColors
                        ),
                      ),
                      
                      AppSpacing.verticalSpacing(AppSpacing.xs), // Use AppSpacing
                      
                      Text( // Removed Container
                        _reclamation!.description,
                        style: AppTypography.bodyMedium(context).copyWith( // Use AppTypography
                          color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, // Use AppColors
                        ),
                      ),
                      
                      AppSpacing.verticalSpacing(AppSpacing.lg), // Use AppSpacing
                      
                      // Images
                      if (_reclamation!.imageUrls.isNotEmpty) ...[
                        Text(
                          'Images',
                          style: AppTypography.headlineSmall(context).copyWith( // Use AppTypography
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, // Use AppColors
                          ),
                        ),
                        
                        AppSpacing.verticalSpacing(AppSpacing.xs), // Use AppSpacing
                        
                        ImageGalleryUtils.buildImageGallery( // Use ImageGalleryUtils
                          context,
                          // ignore: unnecessary_type_check
                          _reclamation!.imageUrls.map((url) => url is String ? url : '').where((url) => url.isNotEmpty).toList(), // Ensure list of strings
                          isDarkMode: isDarkMode,
                          fixedHeight: 200,
                          onRemoveImage: null, // No removal on details page
                        ),
                        
                        AppSpacing.verticalSpacing(AppSpacing.lg), // Use AppSpacing
                      ],
                      
                      // Admin response
                      if (_reclamation!.status == 'resolved' || _reclamation!.status == 'rejected') ...[
                        Text(
                          'Réponse de l\'administrateur',
                          style: AppTypography.headlineSmall(context).copyWith( // Use AppTypography
                            fontWeight: FontWeight.w600, // Made bolder
                            color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, // Use AppColors
                          ),
                        ),
                        
                        AppSpacing.verticalSpacing(AppSpacing.xs), // Use AppSpacing
                        
                        Text( // Removed Container
                          _reclamation!.adminResponse ?? 'Aucune réponse fournie',
                          style: AppTypography.bodyMedium(context).copyWith( // Use AppTypography
                            color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, // Use AppColors
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
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

  void _contactProvider({required String providerId}) {
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
    
    if (providerId.isEmpty) {
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
    
    final providerName = _reclamationProviderData != null 
        ? '${_reclamationProviderData!['firstname'] ?? ''} ${_reclamationProviderData!['lastname'] ?? ''}'
        : 'Prestataire';
    
    context.push(
      '/clientHome/marketplace/chat/conversation/$providerId',
      extra: {
        'otherUserName': providerName,
      },
    );
  }
}
