import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import '../../front/app_colors.dart';
import '../../front/custom_app_bar.dart';
import '../../front/custom_button.dart';
import '../../front/custom_dialog.dart';
import '../../front/loading_overlay.dart';

class ModifyPostPage extends StatefulWidget {
  final DocumentSnapshot post;
  const ModifyPostPage({super.key, required this.post});

  @override
  State<ModifyPostPage> createState() => _ModifyPostPageState();
}

// Update the variable name from _etatProduit to _condition to match ajouter_publication.dart
class _ModifyPostPageState extends State<ModifyPostPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  String _condition = 'Neuf';  // Changed from _etatProduit to _condition
  List<File> _images = [];
  List<String> _existingImageUrls = [];
  final _picker = ImagePicker();
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
    // Update to use 'condition' field from database instead of 'etat'
    _condition = data['condition'] ?? 'Neuf';
    
    if (data['images'] != null && data['images'] is List) {
      _existingImageUrls = List<String>.from(data['images']);
    }
  }

  Future<void> _pickImage() async {
    final pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _images.addAll(pickedFiles.map((e) => File(e.path)).toList());
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
    
    
    List<String> uploadedUrls = [];
    try {
      for (var image in _images) {
        final bytes = await image.readAsBytes();
        final base64Image = base64Encode(bytes);
        
        final response = await http.post(
          Uri.parse('https://api.imgbb.com/1/upload'),
          body: {
            'key': 'YOUR_IMGBB_API_KEY',  // Replace with your actual API key
            'image': base64Image,
          },
        );
        
        if (response.statusCode == 200) {
          final jsonResponse = json.decode(response.body);
          if (jsonResponse['success'] == true) {
            uploadedUrls.add(jsonResponse['data']['url']);
          }
        }
      }
    } catch (e) {
      print('Error uploading images: $e');
    } finally {
    }
    
    return uploadedUrls;
  }

  Future<void> _updatePost() async {
    // Validate form
    if (!_validateForm()) return;
    
    // Check if any changes were made
    final data = widget.post.data() as Map<String, dynamic>;
    bool hasChanges = false;
    
    // Compare current values with original values
    if (_titleController.text.trim() != data['title'] ||
        _descriptionController.text.trim() != data['description'] ||
        double.parse(_priceController.text) != data['price'] ||
        _condition != data['condition'] ||
        _existingImageUrls.length != (data['images'] as List).length ||
        _images.isNotEmpty) {
      hasChanges = true;
    }
    
    // If no changes were made, show message and return
    if (!hasChanges) {
      _showSnackBar('Aucune modification n\'a été effectuée');
      return;
    }
    
    setState(() => _isUploading = true);
    
    try {
      // Show loading overlay
      LoadingOverlay.show(context);
      
      // Upload new images
      final uploadedUrls = await _uploadImages();
      
      // Combine existing and new image URLs
      final allImageUrls = [..._existingImageUrls, ...uploadedUrls];
      
      // Update post in Firestore - change 'etat' to 'condition'
      await FirebaseFirestore.instance.collection('marketplace').doc(widget.post.id).update({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text),
        'images': allImageUrls,
        'condition': _condition,  // Changed from 'etat' to 'condition'
        'isValidated': false,
        'lastModified': FieldValue.serverTimestamp(),
      });

      // Hide loading overlay
      LoadingOverlay.hide();

      if (mounted) {
        CustomDialog.show(
          context: context,
           title:"Succès",
           message:"Votre publication a été modifiée avec succès ! Elle est maintenant en attente de validation.",
          onConfirm: () => context.go('/clientHome/marketplace'),
        );
      }
    } catch (e) {
      // Hide loading overlay
      LoadingOverlay.hide();
      
      if (mounted) {
        CustomDialog.show(
          context:context,
          title: "Erreur",
          message: "Une erreur est survenue lors de la modification: ${e.toString()}",
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  // Update the validateForm method to use snackbars like in ajouter_publication.dart
  bool _validateForm() {
    bool isValid = true;
    
    // Reset errors
    setState(() {
      _titleError = null;
      _descriptionError = null;
      _priceError = null;
    });
    
    // Validate title
    if (_titleController.text.trim().isEmpty) {
      setState(() => _titleError = 'Veuillez entrer un titre');
      _showSnackBar('Veuillez entrer un titre pour votre annonce');
      isValid = false;
    }
    
    // Validate description
    if (_descriptionController.text.trim().isEmpty) {
      setState(() => _descriptionError = 'Veuillez entrer une description');
      _showSnackBar('Veuillez ajouter une description pour votre annonce');
      isValid = false;
    }
    
    // Validate price
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
    
    // Validate product condition - no need to validate since it has a default value
    
    // Validate images
    if (_existingImageUrls.isEmpty && _images.isEmpty) {
      _showSnackBar('Veuillez ajouter au moins une image');
      isValid = false;
    }
    
    return isValid;
  }
  
  // Add the showSnackBar method like in ajouter_publication.dart
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: Theme.of(context).brightness == Brightness.dark 
            ? AppColors.primaryGreen 
            : AppColors.primaryDarkGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: CustomAppBar(
        title: 'Modifier l\'annonce',
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title section
              Text(
                'Titre de l\'annonce',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                style: GoogleFonts.poppins(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                decoration: InputDecoration(
                  hintText: 'Ex: iPhone 13 Pro Max',
                  hintStyle: GoogleFonts.poppins(
                    color: isDarkMode ? Colors.white38 : Colors.black38,
                  ),
                  filled: true,
                  fillColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  errorText: _titleError,
                ),
              ),
              const SizedBox(height: 20),
              
              // Description section
              Text(
                'Description',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                style: GoogleFonts.poppins(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Décrivez votre produit en détail...',
                  hintStyle: GoogleFonts.poppins(
                    color: isDarkMode ? Colors.white38 : Colors.black38,
                  ),
                  filled: true,
                  fillColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                  errorText: _descriptionError,
                ),
              ),
              const SizedBox(height: 20),
              
              // Price section
              Text(
                'Prix (DT)',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _priceController,
                style: GoogleFonts.poppins(
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Ex: 1200',
                  hintStyle: GoogleFonts.poppins(
                    color: isDarkMode ? Colors.white38 : Colors.black38,
                  ),
                  filled: true,
                  fillColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  prefixIcon: Icon(
                    Icons.price_change,
                    color: isDarkMode ? Colors.white54 : Colors.black54,
                  ),
                  errorText: _priceError,
                ),
              ),
              const SizedBox(height: 20),
              
              // Product state section
              Text(
                'État du produit',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              // Update the product state options to match ajouter_publication.dart
              Row(
                children: [
                  Expanded(
                    child: _buildStateOption('Neuf', Icons.new_releases, 'Neuf'),
                    // Changed value to match the label
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStateOption('Très bon', Icons.thumb_up, 'Très bon'),
                    // Changed label and value to match ajouter_publication.dart
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStateOption('Bon', Icons.check_circle, 'Bon'),
                    // Changed icon and value to match ajouter_publication.dart
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStateOption('Occasion', Icons.handyman, 'Occasion'),
                    // Changed label and value to match ajouter_publication.dart
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Images section
              Text(
                'Images',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Les images aident à vendre plus rapidement. Ajoutez jusqu\'à 5 photos.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 12),
              
              // Existing images
              if (_existingImageUrls.isNotEmpty) ...[
                Text(
                  'Images actuelles',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _existingImageUrls.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _existingImageUrls[index],
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removeExistingImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
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
                const SizedBox(height: 16),
              ],
              
              // New images
              if (_images.isNotEmpty) ...[
                Text(
                  'Nouvelles images',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _images.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _images[index],
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 16,
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
                const SizedBox(height: 16),
              ],
              
              // Add image button
              if (_existingImageUrls.length + _images.length < 5)
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: double.infinity,
                    height: 100,
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate,
                          size: 32,
                          color: isDarkMode ? Colors.white54 : Colors.black54,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ajouter des photos',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              
              // Remove the preview section
              const SizedBox(height: 30),
              
              // Submit button (keep this part)
              CustomButton(
                text: 'Mettre à jour l\'annonce',
                onPressed: _isUploading ? null : _updatePost,
                isLoading: _isUploading,
                backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                textColor: Colors.white,
                borderRadius: 10,
                height: 50,
              ),
              
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStateOption(String title, IconData icon, String value) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _condition == value;
    
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _condition = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDarkMode ? AppColors.primaryGreen.withOpacity(0.2) : AppColors.primaryDarkGreen.withOpacity(0.1))
                : (isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200),
            borderRadius: BorderRadius.circular(10),
            border: isSelected
                ? Border.all(
                    color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                    width: 2,
                  )
                : Border.all(
                    color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                    width: 1,
                  ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 24,
                color: isSelected
                    ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                    : (isDarkMode ? Colors.white70 : Colors.black54),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                      : (isDarkMode ? Colors.white70 : Colors.black54),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
  }