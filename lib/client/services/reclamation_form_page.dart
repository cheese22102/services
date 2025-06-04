import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';
import '../../front/app_colors.dart';
import '../../front/custom_app_bar.dart';
import '../../front/custom_button.dart';
import '../../front/custom_text_field.dart';
import '../../front/app_spacing.dart';
import '../../front/app_typography.dart';
import '../../utils/image_upload_utils.dart'; // Import ImageUploadUtils
import '../../utils/image_gallery_utils.dart'; // Import ImageGalleryUtils
import '../../front/loading_overlay.dart'; // Import LoadingOverlay

class ReclamationFormPage extends StatefulWidget {
  final String reservationId;
  
  const ReclamationFormPage({
    super.key,
    required this.reservationId,
  });

  @override
  State<ReclamationFormPage> createState() => _ReclamationFormPageState();
}

class _ReclamationFormPageState extends State<ReclamationFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  bool _isLoading = false;
  String? _targetId; 
  
  final List<File> _evidenceImages = [];
  
  @override
  void initState() {
    super.initState();
    _fetchReservationDetails();
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Réservation introuvable', style: AppTypography.bodyMedium(context).copyWith(color: Colors.white)),
            backgroundColor: AppColors.errorRed,
          ),
          );
          context.pop();
        }
        return;
      }
      
      final data = reservationDoc.data()!;
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      
      // Determine the target ID (the other party)
      if (currentUserId == data['userId']) {
        // Current user is the client, target is the provider
        _targetId = data['providerId'];
      } else if (currentUserId == data['providerId']) {
        // Current user is the provider, target is the client
        _targetId = data['userId'];
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e', style: AppTypography.bodyMedium(context).copyWith(color: Colors.white)),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    }
  }
  
  Future<void> _pickImage() async {
    try {
      final pickedFiles = await ImageUploadUtils.pickMultipleImagesWithOptions(context, isDarkMode: Theme.of(context).brightness == Brightness.dark);
      
      if (pickedFiles.isNotEmpty) {
        if (_evidenceImages.length + pickedFiles.length > 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maximum 3 images autorisées', style: AppTypography.bodyMedium(context).copyWith(color: Colors.white)),
          backgroundColor: AppColors.errorRed,
        ),
      );
          final remainingSlots = 3 - _evidenceImages.length;
          final filesToAdd = pickedFiles.take(remainingSlots).toList();
          setState(() {
            _evidenceImages.addAll(filesToAdd);
          });
        } else {
          setState(() {
            _evidenceImages.addAll(pickedFiles);
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la sélection des images: $e', style: AppTypography.bodyMedium(context).copyWith(color: Colors.white)),
          backgroundColor: AppColors.errorRed,
        ),
      );
    }
  }
  
  void _removeImage(int index) {
    setState(() {
      _evidenceImages.removeAt(index);
    });
  }
  
  Future<void> _submitReclamation() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vous devez être connecté pour soumettre une réclamation', style: AppTypography.bodyMedium(context).copyWith(color: Colors.white)),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }
    
    if (_targetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de déterminer le destinataire de la réclamation', style: AppTypography.bodyMedium(context).copyWith(color: Colors.white)),
          backgroundColor: AppColors.errorRed,
        ),
      );
      return;
    }

    // Confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
          title: Text(
            'Confirmer la soumission',
            style: AppTypography.headlineMedium(context),
          ),
          content: Text(
            'Êtes-vous sûr de vouloir soumettre cette réclamation?',
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
                style: AppTypography.button(context, color: AppColors.errorRed),
              ),
            ),
          ],
        );
      },
    );

    if (confirm != true) {
      return; // User cancelled submission
    }
    
    LoadingOverlay.show(context); // Show loading overlay
    
    try {
      // Upload images if any
      List<String> imageUrls = [];
      if (_evidenceImages.isNotEmpty) {
        imageUrls = await ImageUploadUtils.uploadMultipleImages(_evidenceImages); // Use ImageUploadUtils
      }
      
      // Create reclamation ID
      final reclamationId = const Uuid().v4();
      
      // Save reclamation to Firestore
      await FirebaseFirestore.instance
          .collection('reclamations')
          .doc(reclamationId)
          .set({
        'id': reclamationId,
        'reservationId': widget.reservationId,
        'submitterId': currentUserId,
        'targetId': _targetId,
        'title': _titleController.text,
        'description': _descriptionController.text,
        'imageUrls': imageUrls,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'isNotified': false,
      });
      
      // Update reservation to mark that it has a reclamation
      await FirebaseFirestore.instance
          .collection('reservations')
          .doc(widget.reservationId)
          .update({
        'hasReclamation': true,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Réclamation soumise avec succès', style: AppTypography.bodyMedium(context).copyWith(color: Colors.white)),
            backgroundColor: AppColors.primaryDarkGreen,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la soumission: $e', style: AppTypography.bodyMedium(context).copyWith(color: Colors.white)),
            backgroundColor: AppColors.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        LoadingOverlay.hide(); // Hide loading overlay
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightInputBackground, // Consistent background
      appBar: CustomAppBar(
        title: 'Soumettre une réclamation',
        showBackButton: true,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding), // Use AppSpacing
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title field
                    Text(
                      'Titre de la réclamation',
                      style: AppTypography.bodyLarge(context).copyWith( // Use AppTypography
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, // Use AppColors
                      ),
                    ),
                    AppSpacing.verticalSpacing(AppSpacing.xs), // Use AppSpacing
                    CustomTextField(
                      labelText: 'Titre',
                      controller: _titleController,
                      hintText: 'Ex: Service non conforme, Problème de qualité...',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un titre';
                        }
                        return null;
                      },
                    ),
                    
                    AppSpacing.verticalSpacing(AppSpacing.sectionSpacing), // Use AppSpacing
                    
                    // Description field
                    Text(
                      'Description détaillée',
                      style: AppTypography.bodyLarge(context).copyWith( // Use AppTypography
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, // Use AppColors
                      ),
                    ),
                    AppSpacing.verticalSpacing(AppSpacing.xs), // Use AppSpacing
                    CustomTextField(
                      labelText: 'Description',
                      controller: _descriptionController,
                      hintText: 'Décrivez votre problème en détail...',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez décrire votre problème';
                        }
                        if (value.length < 20) {
                          return 'La description doit contenir au moins 20 caractères';
                        }
                        return null;
                      },
                    ),
                    
                    AppSpacing.verticalSpacing(AppSpacing.sectionSpacing), // Use AppSpacing
                    
                    // Evidence images
                    Text(
                      'Photos (optionnel)',
                      style: AppTypography.bodyLarge(context).copyWith( // Use AppTypography
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, // Use AppColors
                      ),
                    ),
                    AppSpacing.verticalSpacing(AppSpacing.xs), // Use AppSpacing
                    Text(
                      'Ajoutez jusqu\'à 3 photos pour illustrer votre problème',
                      style: AppTypography.bodyMedium(context).copyWith( // Use AppTypography
                        color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    AppSpacing.verticalSpacing(AppSpacing.md), // Use AppSpacing
                    
                    // Image picker
                    ImageGalleryUtils.buildImageGallery( // Use ImageGalleryUtils
                      context,
                      _evidenceImages,
                      isDarkMode: isDarkMode,
                      fixedHeight: 100, // Fixed height for the horizontal list
                      onRemoveImage: _removeImage,
                    ),
                    AppSpacing.verticalSpacing(AppSpacing.md), // Spacing after gallery
                    
                    // Add image button
                    if (_evidenceImages.length < 3)
                      CustomButton(
                        text: 'Ajouter des photos',
                        onPressed: _pickImage,
                        icon: const Icon(Icons.add_photo_alternate, color: Colors.white),
                        isPrimary: false,
                        backgroundColor: isDarkMode ? AppColors.darkInputBackground : AppColors.lightInputBackground,
                        textColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                        height: AppSpacing.buttonMedium,
                        borderRadius: AppSpacing.radiusMd,
                      ),
                    
                    AppSpacing.verticalSpacing(AppSpacing.xxl), // Use AppSpacing
                    
                    // Submit button (moved to bottomNavigationBar)
                    // CustomButton(
                    //   text: 'Soumettre la réclamation',
                    //   onPressed: _submitReclamation,
                    //   backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                    //   height: AppSpacing.buttonLarge,
                    //   borderRadius: AppSpacing.radiusMd,
                    // ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: Container(
        color: isDarkMode ? Colors.grey.shade900 : Colors.white, // Same as CustomAppBar background
        padding: const EdgeInsets.all(AppSpacing.md),
        child: SafeArea(
          child: CustomButton(
            text: 'Soumettre la réclamation',
            onPressed: _submitReclamation,
            backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
            height: AppSpacing.buttonLarge,
            borderRadius: AppSpacing.radiusMd,
          ),
        ),
      ),
    );
  }
}
