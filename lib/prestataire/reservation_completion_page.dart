import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../front/app_colors.dart';
import '../front/custom_app_bar.dart';
import '../front/custom_button.dart';
import '../utils/cloudinary_service.dart';
import '../utils/image_upload_utils.dart';

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
      
      userDoc.data();
      
      if (mounted) {
        setState(() {
          _reservationData = reservationData;
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la sélection des images: $e')),
        );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez ajouter une description')),
      );
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
        'providerCompletionStatus': 'completed',
        'providerCompletionDescription': _completionDescriptionController.text.trim(),
        'providerCompletionImages': _uploadedImageUrls,
        'providerCompletionTimestamp': FieldValue.serverTimestamp(),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Service marqué comme terminé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
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
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: Text(
          'Aucune image sélectionnée',
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Images sélectionnées (${_selectedImages.length})',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w500,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ),
        Container(
          height: 120,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _selectedImages.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Stack(
                  children: [
                    // Image preview
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          _selectedImages[index],
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    // Delete button
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _removeImage(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 16,
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
      appBar: CustomAppBar(
        title: 'Marquer comme terminé',
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Service info card
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
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
                      Text(
                        'Détails de l\'intervention',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Veuillez ajouter une description et des photos pour marquer cette intervention comme terminée.',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Description field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Description',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _completionDescriptionController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Décrivez le travail effectué...',
                  hintStyle: GoogleFonts.poppins(
                    color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
                  ),
                  filled: true,
                  fillColor: isDarkMode ? AppColors.darkInputBackground : Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                style: GoogleFonts.poppins(
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ),
            
            // Photos section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Photos',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 8),
            
            // Selected images preview
            _buildSelectedImagesPreview(),
            
            // Add photos button
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _pickImages,
                icon: const Icon(Icons.add_photo_alternate),
                label: Text(
                  'Ajouter des photos',
                  style: GoogleFonts.poppins(),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                  foregroundColor: isDarkMode ? Colors.white : Colors.black87,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            
            // Submit button
            Padding(
              padding: const EdgeInsets.all(16),
              child: CustomButton(
                onPressed: _isSubmitting ? null : _submitCompletion,
                text: _isSubmitting ? 'Envoi en cours...' : 'Marquer comme terminé',
                backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                textColor: Colors.white,
                isLoading: _isSubmitting,
              ),
            ),
          ],
        ),
      ),
    );
  }
}