import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import '../../front/app_colors.dart';
import '../../front/app_spacing.dart';
import '../../front/app_typography.dart';
import '../../front/custom_app_bar.dart';
import '../../front/custom_button.dart';
import '../../front/loading_overlay.dart';
import '../../front/custom_snack.dart'; // Import CustomSnackBar
import '../../utils/image_upload_utils.dart'; // Import ImageUploadUtils
import '../../utils/image_gallery_utils.dart'; // Import ImageGalleryUtils

class ModifyPostPage extends StatefulWidget {
  final DocumentSnapshot post;
  const ModifyPostPage({super.key, required this.post});

  @override
  State<ModifyPostPage> createState() => _ModifyPostPageState();
}

class _ModifyPostPageState extends State<ModifyPostPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  String _condition = 'Neuf';
  List<File> _images = [];
  List<String> _existingImageUrls = [];
  bool _isUploading = false;
  String? _titleError;
  String? _descriptionError;
  String? _priceError;

  @override
  void initState() {
    super.initState();
    _loadPostData();
  }

  void _loadPostData() {
    final data = widget.post.data() as Map<String, dynamic>;
    _titleController.text = data['title'] ?? '';
    _descriptionController.text = data['description'] ?? '';
    _priceController.text = (data['price'] ?? 0).toString();
    _condition = data['condition'] ?? 'Neuf';
    
    if (data['images'] != null && data['images'] is List) {
      _existingImageUrls = List<String>.from(data['images']);
    }
  }

  Future<void> _pickImage() async {
    setState(() {
      _isUploading = true; // Set uploading state to true when picking starts
    });
    try {
      final pickedFiles = await ImageUploadUtils.pickMultipleImagesWithOptions(
        context,
        isDarkMode: Theme.of(context).brightness == Brightness.dark,
      );
      if (pickedFiles.isNotEmpty) {
        if (_images.length + pickedFiles.length > 5) {
          // Show a snackbar or dialog if too many images are selected
          // For now, just take the allowed number
          final remainingSlots = 5 - _images.length;
          final filesToAdd = pickedFiles.take(remainingSlots).toList();
          setState(() {
            _images.addAll(filesToAdd);
          });
        } else {
          setState(() {
            _images.addAll(pickedFiles);
          });
        }
      }
    } catch (e) {
      print('Error picking images: $e');
    } finally {
      setState(() {
        _isUploading = false; // Set uploading state to false when picking ends
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  void _removeExistingImage(int index) {
    setState(() {
      _existingImageUrls.removeAt(index);
    });
  }

  Future<List<String>> _uploadImages() async {
    if (_images.isEmpty) return [];
    
    return await ImageUploadUtils.uploadMultipleImages(_images);
  }

  Future<void> _updatePost() async {
    if (!_validateForm()) return;
    
    final data = widget.post.data() as Map<String, dynamic>;
    bool hasChanges = false;
    
    if (_titleController.text.trim() != data['title'] ||
        _descriptionController.text.trim() != data['description'] ||
        double.parse(_priceController.text) != data['price'] ||
        _condition != data['condition'] ||
        _existingImageUrls.length != (data['images'] as List).length ||
        _images.isNotEmpty) {
      hasChanges = true;
    }
    
    if (!hasChanges) {
      _showSnackBar('Aucune modification n\'a été effectuée');
      return;
    }
    
    setState(() => _isUploading = true);
    
    try {
      LoadingOverlay.show(context);
      
      final uploadedUrls = await _uploadImages();
      
      final allImageUrls = [..._existingImageUrls, ...uploadedUrls];
      
      await FirebaseFirestore.instance.collection('marketplace').doc(widget.post.id).update({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text),
        'images': allImageUrls,
        'condition': _condition,
        'isValidated': false,
        'isRejected': false, // Clear rejection status
        'rejectionReason': null, // Clear rejection reason
        'rejectedAt': null, // Clear rejection timestamp
        'lastModified': FieldValue.serverTimestamp(),
      });

      LoadingOverlay.hide();

      if (mounted) {
        CustomSnackBar.showSuccess(
          context,
          'Votre annonce a été modifiée avec succès ! Elle est maintenant en attente de validation.',
        );
        context.go('/clientHome/marketplace'); // Navigate after showing snackbar
      }
    } catch (e) {
      LoadingOverlay.hide();
      
      if (mounted) {
        CustomSnackBar.showError(
          context,
          'Une erreur est survenue lors de la modification: ${e.toString()}',
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  bool _validateForm() {
    bool isValid = true;
    
    setState(() {
      _titleError = null;
      _descriptionError = null;
      _priceError = null;
    });
    
    if (_titleController.text.trim().isEmpty) {
      setState(() => _titleError = 'Veuillez entrer un titre');
      _showSnackBar('Veuillez entrer un titre pour votre annonce');
      isValid = false;
    }
    
    if (_descriptionController.text.trim().isEmpty) {
      setState(() => _descriptionError = 'Veuillez entrer une description');
      _showSnackBar('Veuillez ajouter une description pour votre annonce');
      isValid = false;
    }
    
    if (_priceController.text.trim().isEmpty) {
      setState(() => _priceError = 'Veuillez entrer un prix');
      _showSnackBar('Veuillez indiquer un prix pour votre annonce');
      isValid = false;
    } else {
      try {
        double.parse(_priceController.text);
      } catch (e) {
        setState(() => _priceError = 'Veuillez entrer un prix valide');
        _showSnackBar('Le prix doit être un nombre valide');
        isValid = false;
      }
    }
    
    if (_existingImageUrls.isEmpty && _images.isEmpty) {
      _showSnackBar('Veuillez ajouter au moins une image');
      isValid = false;
    }
    
    return isValid;
  }
  
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: AppTypography.bodyMedium(context).copyWith(color: AppColors.lightTextPrimary), // Use AppTypography and AppColors
        ),
        backgroundColor: Theme.of(context).brightness == Brightness.dark 
            ? AppColors.primaryGreen 
            : AppColors.primaryDarkGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd), // Use AppSpacing
        ),
        margin: EdgeInsets.all(AppSpacing.md), // Use AppSpacing
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightInputBackground, // Changed to lightInputBackground
      appBar: CustomAppBar(
        title: 'Modifier l\'annonce',
        showBackButton: true,
        // backgroundColor removed
        // Removed explicit titleColor and iconColor to use CustomAppBar defaults for consistency
      ),
      body: SingleChildScrollView( // Changed to SingleChildScrollView to avoid overflow with bottomSheet
        padding: EdgeInsets.only(bottom: AppSpacing.buttonMedium + AppSpacing.lg), // Add padding for bottom sheet
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg), // Use AppSpacing
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title section
                Text(
                  'Titre',
                  style: AppTypography.bodyLarge(context).copyWith( // Use AppTypography
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, // Use AppColors
                  ),
                ),
                SizedBox(height: AppSpacing.sm), // Use AppSpacing
                TextFormField(
                  controller: _titleController,
                  style: AppTypography.bodyMedium(context).copyWith( // Use AppTypography
                    color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, // Use AppColors
                  ),
                  decoration: InputDecoration(
                    hintText: 'Ex: iPhone 13 Pro Max',
                    hintStyle: AppTypography.bodyMedium(context).copyWith( // Use AppTypography
                      color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint, // Use AppColors
                    ),
                    filled: true,
                    fillColor: isDarkMode ? AppColors.darkInputBackground : AppColors.lightCardBackground, // Changed to lightCardBackground
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd), // Use AppSpacing
                      borderSide: BorderSide(
                        color: isDarkMode ? AppColors.darkBorder : AppColors.lightBorder, // Added border
                        width: 1,
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md), // Use AppSpacing
                    errorText: _titleError,
                  ),
                ),
                SizedBox(height: AppSpacing.lg), // Use AppSpacing
                
                // Description section
                Text(
                  'Description',
                  style: AppTypography.bodyLarge(context).copyWith( // Use AppTypography
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, // Use AppColors
                  ),
                ),
                SizedBox(height: AppSpacing.sm), // Use AppSpacing
                TextFormField(
                  controller: _descriptionController,
                  style: AppTypography.bodyMedium(context).copyWith( // Use AppTypography
                    color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, // Use AppColors
                  ),
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: 'Décrivez votre produit en détail...',
                    hintStyle: AppTypography.bodyMedium(context).copyWith( // Use AppTypography
                      color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint, // Use AppColors
                    ),
                    filled: true,
                    fillColor: isDarkMode ? AppColors.darkInputBackground : AppColors.lightCardBackground, // Changed to lightCardBackground
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd), // Use AppSpacing
                      borderSide: BorderSide(
                        color: isDarkMode ? AppColors.darkBorder : AppColors.lightBorder, // Added border
                        width: 1,
                      ),
                    ),
                    contentPadding: EdgeInsets.all(AppSpacing.md), // Use AppSpacing
                    errorText: _descriptionError,
                  ),
                ),
                SizedBox(height: AppSpacing.lg), // Use AppSpacing
                
                // Price section
                Text(
                  'Prix (DT)',
                  style: AppTypography.bodyLarge(context).copyWith( // Use AppTypography
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, // Use AppColors
                  ),
                ),
                SizedBox(height: AppSpacing.sm), // Use AppSpacing
                TextFormField(
                  controller: _priceController,
                  style: AppTypography.bodyMedium(context).copyWith( // Use AppTypography
                    color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, // Use AppColors
                  ),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Ex: 1200',
                    hintStyle: AppTypography.bodyMedium(context).copyWith( // Use AppTypography
                      color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint, // Use AppColors
                    ),
                    filled: true,
                    fillColor: isDarkMode ? AppColors.darkInputBackground : AppColors.lightCardBackground, // Changed to lightCardBackground
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd), // Use AppSpacing
                      borderSide: BorderSide(
                        color: isDarkMode ? AppColors.darkBorder : AppColors.lightBorder, // Added border
                        width: 1,
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.md), // Use AppSpacing
                    prefixIcon: Icon(
                      Icons.price_change,
                      color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint, // Use AppColors
                    ),
                    errorText: _priceError,
                  ),
                ),
                SizedBox(height: AppSpacing.lg), // Use AppSpacing
                      
                      // Product state section
                      Text(
                        'État du produit',
                        style: AppTypography.bodyLarge(context).copyWith( // Use AppTypography
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, // Use AppColors
                        ),
                      ),
                      SizedBox(height: AppSpacing.md), // Use AppSpacing
                      Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: [
                          _buildConditionChip('Neuf', isDarkMode),
                          _buildConditionChip('Très bon', isDarkMode),
                          _buildConditionChip('Bon', isDarkMode),
                          _buildConditionChip('Satisfaisant', isDarkMode),
                        ],
                      ),
                      SizedBox(height: AppSpacing.lg), // Use AppSpacing
                      
                      // Images section
                      Text(
                        'Images',
                        style: AppTypography.bodyLarge(context).copyWith( // Use AppTypography
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, // Use AppColors
                        ),
                      ),
                      SizedBox(height: AppSpacing.sm), // Use AppSpacing
                      SizedBox(height: AppSpacing.md), // Use AppSpacing
                      
                      // Existing images
                      if (_existingImageUrls.isNotEmpty) ...[
                        ImageGalleryUtils.buildImageGallery(
                          context,
                          _existingImageUrls,
                          isDarkMode: isDarkMode,
                          onRemoveImage: (index) => _removeExistingImage(index),
                        ),
                        SizedBox(height: AppSpacing.md),
                      ],
                      
                      // New images
                      if (_images.isNotEmpty) ...[
                        ImageGalleryUtils.buildImageGallery(
                          context,
                          _images,
                          isDarkMode: isDarkMode,
                          onRemoveImage: (index) => _removeImage(index),
                        ),
                        SizedBox(height: AppSpacing.md),
                      ],
                      
                      // Add image button
                      if (_existingImageUrls.length + _images.length < 5)
                        Center( // Center the button
                          child: CustomButton(
                            text: 'Ajouter des photos',
                            onPressed: _isUploading ? null : _pickImage,
                            isLoading: _isUploading,
                            backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                            textColor: Colors.white,
                            borderRadius: AppSpacing.radiusMd,
                            height: 50,
                          ),
                        ),
                      
                      SizedBox(height: AppSpacing.xl), // Use AppSpacing
                    ],
                  ),
                ),
              ),
            ),
      bottomSheet: Container(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md), // Use AppSpacing
        decoration: BoxDecoration(
          color: isDarkMode ? AppColors.darkSurface : AppColors.lightSurface, // Use AppColors
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: CustomButton(
            text: 'Mettre à jour l\'annonce',
            onPressed: _isUploading ? null : _updatePost,
            isLoading: _isUploading,
            backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen, // Use primaryDarkGreen for consistency with other buttons
            textColor: Colors.white, // Keep text white for better contrast on primaryDarkGreen
            borderRadius: AppSpacing.radiusMd,
            height: AppSpacing.buttonMedium, // Use AppSpacing.buttonMedium (45)
            width: double.infinity, // Make the button take full width
          ),
        ),
      ),
    );
  }

  Widget _buildConditionChip(String condition, bool isDarkMode) {
    final isSelected = _condition == condition;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _condition = condition;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
              : (isDarkMode ? AppColors.darkInputBackground : AppColors.lightInputBackground),
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
          border: Border.all(
            color: isSelected
                ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                : (isDarkMode ? AppColors.darkBorder : AppColors.lightBorder), // Changed to darkBorder/lightBorder
            width: 1.5,
          ),
        ),
        child: Text(
          condition,
          style: AppTypography.labelLarge(
            context,
            color: isSelected
                ? Colors.white
                : (isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
          ),
        ),
      ),
    );
  }
}
