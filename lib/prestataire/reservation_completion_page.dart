import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../front/app_colors.dart';
import '../front/custom_app_bar.dart';
import '../front/custom_button.dart';
import '../utils/cloudinary_service.dart';
import '../utils/image_upload_utils.dart';
import '../front/app_spacing.dart'; // Added
import '../front/app_typography.dart'; // Added

class ReservationCompletionPage extends StatefulWidget {
  final String reservationId;
  
  const ReservationCompletionPage({
    super.key,
    required this.reservationId,
  });

  @override
  State<ReservationCompletionPage> createState() => _ReservationCompletionPageState();
}

class _ReservationCompletionPageState extends State<ReservationCompletionPage> {
  void _showCustomSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTypography.bodySmall(context).copyWith(color: Colors.white),
        ),
        backgroundColor: isError ? AppColors.errorLightRed : AppColors.warningOrange, // Or successGreen for success
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  bool _isLoading = true;
  bool _isSubmitting = false;
  Map<String, dynamic>? _reservationData;
  
  final TextEditingController _completionDescriptionController = TextEditingController();
  final List<File> _selectedImages = [];
  final List<String> _uploadedImageUrls = [];
  
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
      
      userDoc.data();
      
      if (mounted) {
        setState(() {
          _reservationData = reservationData;
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
  
  Future<void> _pickImages() async {
    try {
      final images = await ImageUploadUtils.pickMultipleImagesWithOptions(
        context,
        isDarkMode: Theme.of(context).brightness == Brightness.dark,
      );
      
      if (images.isNotEmpty) {
        setState(() {
          _selectedImages.addAll(images);
        });
        
        // Debug print to verify images were added
        debugPrint('Added ${images.length} images. Total: ${_selectedImages.length}');
      } else {
        debugPrint('No images selected');
      }
    } catch (e) {
      debugPrint('Error picking images: $e');
      if (mounted) {
        _showCustomSnackBar(context, 'Erreur lors de la sélection des images: $e', isError: true);
      }
    }
  }
  
  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }
  
  // The _submitCompletion method should be uploading images to Cloudinary
  Future<void> _submitCompletion() async {
    if (_completionDescriptionController.text.trim().isEmpty) {
      _showCustomSnackBar(context, 'Veuillez ajouter une description');
      return;
    }
    
    setState(() {
      _isSubmitting = true;
    });
    
    try {
      // Upload images to Cloudinary
      if (_selectedImages.isNotEmpty) {
        final imageUrls = await CloudinaryService.uploadImages(_selectedImages);
        _uploadedImageUrls.addAll(imageUrls);
      }
      
      // Update reservation with completion details
      await FirebaseFirestore.instance
          .collection('reservations')
          .doc(widget.reservationId)
          .update({
        'status': 'waiting_confirmation', // New status
        'providerCompletionStatus': 'completed', // Keep this for provider's view
        'providerCompletionDescription': _completionDescriptionController.text.trim(),
        'providerCompletionImages': _uploadedImageUrls,
        'providerCompletionTimestamp': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(), // Ensure updatedAt is also updated
      });
      
      // Create notification for client
      final userId = _reservationData?['userId'] as String?;
      final providerId = FirebaseAuth.instance.currentUser?.uid;
      
      if (userId != null && providerId != null) {
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
          'title': 'Service terminé',
          'body': 'Le prestataire $providerName a marqué le service comme terminé',
          'type': 'reservation_completed',
          'read': false,
          'timestamp': FieldValue.serverTimestamp(),
          'data': {
            'reservationId': widget.reservationId,
            'providerId': providerId,
            'providerName': providerName,
          },
        });
      }
      
      if (mounted) {
        _showCustomSnackBar(context, 'Service marqué comme terminé avec succès'); // isError defaults to false (orange), green would be better
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        _showCustomSnackBar(context, 'Erreur: $e', isError: true);
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
  
  // Add this method to build the selected images preview
  Widget _buildSelectedImagesPreview() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    if (_selectedImages.isEmpty) {
      return Container(
        padding: EdgeInsets.all(AppSpacing.md),
        alignment: Alignment.center,
        child: Text(
          'Aucune image sélectionnée',
          style: AppTypography.bodyMedium(context).copyWith(
            color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    
    // Define a fixed size for image previews, e.g., using AppSpacing
    final double imagePreviewSize = AppSpacing.xxl * 2.5; // Example: 40 * 2.5 = 100

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: AppSpacing.sm),
          child: Text(
            'Images sélectionnées (${_selectedImages.length}/3)', // Added max count
            style: AppTypography.labelLarge(context).copyWith(
              color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
        ),
        Container(
          height: imagePreviewSize + AppSpacing.sm * 2, // Add padding to height
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.screenPadding, vertical: AppSpacing.sm),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _selectedImages.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: EdgeInsets.only(right: AppSpacing.sm),
                child: Stack(
                  children: [
                    // Image preview
                    Container(
                      width: imagePreviewSize,
                      height: imagePreviewSize,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        border: Border.all(
                          color: isDarkMode ? AppColors.darkBorderColor : AppColors.lightBorderColor,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        child: Image.file(
                          _selectedImages[index],
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    // Delete button
                    Positioned(
                      top: AppSpacing.xxs,
                      right: AppSpacing.xxs,
                      child: GestureDetector(
                        onTap: () => _removeImage(index),
                        child: Container(
                          padding: EdgeInsets.all(AppSpacing.xxs),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            size: AppSpacing.iconSm, // Consistent icon size
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDarkMode ? Theme.of(context).scaffoldBackgroundColor : Colors.white,
        appBar: CustomAppBar(
          title: 'Marquer comme terminé',
          showBackButton: true,
        ),
        body: Center(
          child: CircularProgressIndicator(
            color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
          ),
        ),
      );
    }
    
    return Scaffold(
      backgroundColor: isDarkMode ? Theme.of(context).scaffoldBackgroundColor : Colors.white,
      appBar: CustomAppBar(
        title: 'Marquer comme terminé',
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Service info card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              color: isDarkMode ? Colors.grey.shade900 : Colors.white, // Updated card colors
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Détails de l\'intervention',
                      style: AppTypography.headlineSmall(context).copyWith(
                        color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                    SizedBox(height: AppSpacing.md),
                    Text(
                      'Veuillez ajouter une description et des photos pour marquer cette intervention comme terminée.',
                      style: AppTypography.bodyMedium(context).copyWith(
                        color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: AppSpacing.sectionSpacing),
            
            // Description field
            Text(
              'Description',
              style: AppTypography.titleLarge(context).copyWith(
                color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            TextField( // Using TextField directly for multiline, styled similarly to CustomTextField
              controller: _completionDescriptionController,
              maxLines: 4,
              style: AppTypography.bodyLarge(context).copyWith(
                color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Décrivez le travail effectué...',
                hintStyle: AppTypography.bodyLarge(context).copyWith(
                  color: isDarkMode ? AppColors.darkHintColor : AppColors.lightHintColor,
                ),
                filled: true,
                fillColor: isDarkMode ? Colors.grey.shade900 : Colors.white, // Updated fillColor
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: BorderSide(
                    color: isDarkMode ? AppColors.darkBorderColor : AppColors.lightBorderColor,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: BorderSide(
                    color: isDarkMode ? AppColors.darkBorderColor : AppColors.lightBorderColor,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  borderSide: BorderSide(
                    color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                    width: 2.0,
                  ),
                ),
                contentPadding: EdgeInsets.all(AppSpacing.md),
              ),
            ),
            
            SizedBox(height: AppSpacing.sectionSpacing),
            
            // Photos section
            Text(
              'Photos (Optionnel)',
              style: AppTypography.titleLarge(context).copyWith(
                color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            SizedBox(height: AppSpacing.sm),
            
            // Selected images preview
            _buildSelectedImagesPreview(), // Assuming this will be styled with AppSpacing/Typography
            
            SizedBox(height: AppSpacing.md),
            // Add photos button
            CustomButton(
              onPressed: _isSubmitting ? null : _pickImages,
              text: 'Ajouter des photos (${_selectedImages.length}/3)',
              icon: Icon(Icons.add_photo_alternate, color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen),
              isPrimary: false, // Secondary style
              backgroundColor: isDarkMode ? AppColors.darkSurface : AppColors.lightSurface,
              textColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
              height: AppSpacing.buttonMedium,
              borderRadius: AppSpacing.radiusMd,
            ),
            
            SizedBox(height: AppSpacing.xxl), // More space before submit
            
            // Submit button moved to bottomNavigationBar
          ],
        ),
      ),
      bottomNavigationBar: Container(
        color: isDarkMode ? Colors.grey.shade900 : Colors.white,
        padding: EdgeInsets.all(AppSpacing.md),
        child: SafeArea(
          child: CustomButton(
            onPressed: _isSubmitting ? null : _submitCompletion,
            text: _isSubmitting ? 'Envoi en cours...' : 'Marquer comme terminé',
            backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
            textColor: Colors.white,
            isLoading: _isSubmitting,
            height: AppSpacing.buttonLarge,
            borderRadius: AppSpacing.radiusMd,
            width: double.infinity,
          ),
        ),
      ),
    );
  }
}
