import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../front/app_colors.dart';
import '../../front/app_spacing.dart';
import '../../front/app_typography.dart';
import '../../front/custom_app_bar.dart';
import '../../front/custom_button.dart';
import '../../front/custom_dialog.dart';
import '../../front/loading_overlay.dart';
import '../../front/custom_snack.dart';
import '../../front/custom_text_field.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../utils/image_upload_utils.dart';
import '../../utils/image_gallery_utils.dart';


class AddPostPage extends StatefulWidget {
  const AddPostPage({super.key});

  @override
  State<AddPostPage> createState() => _AddPostPageState();
}

class _AddPostPageState extends State<AddPostPage> {
  // Étapes du walkthrough
  final int _totalSteps = 5;
  int _currentStep = 0;
  
  // Contrôleurs et variables pour les données du formulaire
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  String? _selectedCategory;
  String _condition = 'Neuf';
  final List<File> _images = [];
  bool _isUploading = false;

  // Variables for map and location
  LatLng? _selectedLocation;
  GoogleMapController? _googleMapController;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _initUserLocation();
    _loadServices();
  }
  
  // Load services from Firestore
  Future<void> _loadServices() async {
    setState(() {
    });
    
    try {
      final servicesSnapshot = await FirebaseFirestore.instance
          .collection('services')
          .orderBy('name')
          .get();
      
      final List<Map<String, dynamic>> loadedServices = [];
      
      for (var doc in servicesSnapshot.docs) {
        final data = doc.data();
        loadedServices.add({
          'id': doc.id,
          'name': data['name'] ?? 'Service',
          'icon': Icons.miscellaneous_services,
          'imageUrl': data['imageUrl'] ?? '',
        });
      }
      
      if (mounted) {
        setState(() {
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
        });
      }
    }
  }
  
  Future<void> _initUserLocation() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userData = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userData.exists) {
          final city = userData.data()?['city'] as String?;
          if (city != null && city.isNotEmpty) {
            setState(() {
              _locationController.text = city;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Erreur lors de la récupération de la localisation: $e');
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _googleMapController?.dispose(); // Dispose the GoogleMapController
    super.dispose();
  }

  // Méthode pour passer à l'étape suivante
  void _nextStep() {
    if (_validateCurrentStep(context)) { // Pass context
      setState(() {
        _currentStep++;
      });
    }
  }
  
  // Méthode pour revenir à l'étape précédente
  void _previousStep() {
    setState(() {
      if (_currentStep > 0) {
        _currentStep--;
      }
    });
  }
  // Get current user location
  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permission denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permission permanently denied');
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
      });
      
      // Get city name from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude, 
        position.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _locationController.text = _formatAddress(place);
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  // Format address
  String _formatAddress(Placemark place) {
    List<String> addressParts = [
      place.street ?? '',
      place.locality ?? '',
      place.subAdministrativeArea ?? '',
      place.administrativeArea ?? '',
    ];
    return addressParts.where((part) => part.isNotEmpty).join(', ');
  }
  // Use current location and update map
  Future<void> _useCurrentLocation() async {
    await _getCurrentLocation();
    if (_selectedLocation != null && mounted) {
      _googleMapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_selectedLocation!, 15.0),
      );
    }
  }
  // Validation de l'étape courante
  bool _validateCurrentStep(BuildContext scaffoldContext) { // Accept scaffoldContext
    switch (_currentStep) {
      case 0: // Catégorie
        if (_selectedCategory == null) {
          CustomSnackBar.showError(scaffoldContext, 'Veuillez sélectionner une catégorie'); // Use scaffoldContext
          return false;
        }
        return true;
        
      case 1: // Images
        if (_images.isEmpty) {
          CustomSnackBar.showError(scaffoldContext, 'Veuillez ajouter au moins une image'); // Use scaffoldContext
          return false;
        }
        return true;
        
      case 2: // Titre et description
        if (_titleController.text.trim().isEmpty) {
          CustomSnackBar.showError(scaffoldContext, 'Le titre est obligatoire'); // Use scaffoldContext
          return false;
        }
        if (_titleController.text.length < 3) {
          CustomSnackBar.showError(scaffoldContext, 'Le titre doit contenir au moins 3 caractères'); // Use scaffoldContext
          return false;
        }
        if (_descriptionController.text.trim().isEmpty) {
          CustomSnackBar.showError(scaffoldContext, 'La description est obligatoire'); // Use scaffoldContext
          return false;
        }
        if (_descriptionController.text.length < 10) {
          CustomSnackBar.showError(scaffoldContext, 'La description doit contenir au moins 10 caractères'); // Use scaffoldContext
          return false;
        }
        return true;
        
      case 3: // Prix et état
        if (_priceController.text.trim().isEmpty) {
          CustomSnackBar.showError(scaffoldContext, 'Le prix est obligatoire'); // Use scaffoldContext
          return false;
        }
        try {
          double price = double.parse(_priceController.text);
          if (price <= 0) {
            CustomSnackBar.showError(scaffoldContext, 'Le prix doit être supérieur à 0'); // Use scaffoldContext
            return false;
          }
        } catch (e) {
          CustomSnackBar.showError(scaffoldContext, 'Veuillez entrer un prix valide'); // Use scaffoldContext
          return false;
        }
        return true;
        
      case 4: // Localisation et récapitulatif
        if (_locationController.text.trim().isEmpty) {
          CustomSnackBar.showError(scaffoldContext, 'La localisation est obligatoire'); // Use scaffoldContext
          return false;
        }
        return true;
        
      default:
        return true;
    }
  }
  
  // Méthode pour sélectionner des images
  Future<void> _pickImages(BuildContext scaffoldContext) async { // Accept scaffoldContext
    setState(() {
      _isUploading = true;
    });
    try {
      final pickedFiles = await ImageUploadUtils.pickMultipleImagesWithOptions(scaffoldContext, isDarkMode: Theme.of(scaffoldContext).brightness == Brightness.dark); // Use scaffoldContext
      if (pickedFiles.isNotEmpty) {
        if (_images.length + pickedFiles.length > 5) {
          CustomSnackBar.showError(scaffoldContext, 'Maximum 5 images autorisées'); // Use scaffoldContext
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
      CustomSnackBar.showError(scaffoldContext, 'Erreur lors de la sélection des images: $e'); // Use scaffoldContext
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }
  
  // Méthode pour supprimer une image
  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  // Méthode pour publier l'annonce
  Future<void> _submitPost(BuildContext scaffoldContext) async { // Accept scaffoldContext
    if (!_validateCurrentStep(scaffoldContext) || _isUploading) return; // Pass scaffoldContext
    
    // Show confirmation dialog before proceeding
    final confirmSubmit = await _showConfirmationDialog();
    if (confirmSubmit != true) {
      return; // User cancelled the submission
    }
    
    setState(() => _isUploading = true);
    
    try {
      // Utiliser le LoadingOverlay personnalisé au lieu du dialogue standard
      LoadingOverlay.show(scaffoldContext); // Use scaffoldContext
      
      // Upload des images using ImageUploadUtils
      List<String> imageUrls = await ImageUploadUtils.uploadMultipleImages(_images);
      
      if (imageUrls.isEmpty) {
        throw Exception("Aucune image n'a pu être téléchargée");
      }
      
      // Récupérer l'ID de l'utilisateur
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Utilisateur non connecté");
      }
      
      // Créer le document dans Firestore
      await FirebaseFirestore.instance.collection('marketplace').add({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text),
        'condition': _condition,
        'category': _selectedCategory, // This now contains the service ID
        'location': _locationController.text.trim(),
        'images': imageUrls,
        'userId': user.uid,
        'isValidated': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      // Fermer le LoadingOverlay
      LoadingOverlay.hide();
      
      // Afficher un message de succès et retourner à la page précédente
      if (mounted) {
        CustomSnackBar.showSuccess(
          scaffoldContext, // Use scaffoldContext
          'Votre publication est en attente de validation, vous serez notifié lorsqu\'une décision est prise',
        );
        context.pop();
      }
    } catch (e) {
      // Fermer le LoadingOverlay
      LoadingOverlay.hide();
      
      // Afficher un message d'erreur
      if (mounted) {
        CustomSnackBar.showError(scaffoldContext, 'Erreur lors de la publication: ${e.toString()}'); // Use scaffoldContext
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  // Add this method to show the confirmation dialog
  Future<bool?> _showConfirmationDialog() async {
    // Get the category name from the selected category ID
    if (_selectedCategory != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('services')
            .doc(_selectedCategory)
            .get();
        if (doc.exists) {
        }
      } catch (e) {
        debugPrint('Error getting category name: $e');
      }
    }
    
    // Format the price with 2 decimal places
    try {
      double.parse(_priceController.text);
    } catch (e) {
    }
    
    return CustomDialog.showConfirmation(
      context: context,
      title: 'Confirmer la publication',
      message: 'Êtes-vous sûr de vouloir publier cette annonce ?',
      confirmText: 'Publier',
      cancelText: 'Annuler',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightInputBackground,
      appBar: CustomAppBar(
        title: 'Nouvelle annonce',
        showBackButton: true,
      ),
      body: Builder( // Wrap body with Builder
        builder: (BuildContext scaffoldContext) { // Get scaffoldContext
          return SafeArea(
            child: Column(
              children: [
                // Indicateur de progression
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  child: Column(
                    children: [
                      Row(
                        children: List.generate(_totalSteps, (index) {
                          return Expanded(
                            child: Container(
                              height: 4,
                              margin: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                              decoration: BoxDecoration(
                                color: index <= _currentStep
                                    ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                                    : (isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                              ),
                            ),
                          );
                        }),
                      ),
                      SizedBox(height: AppSpacing.sm),
                      Text(
                        _getStepTitle(),
                        style: AppTypography.h4(scaffoldContext), // Use scaffoldContext
                      ),
                    ],
                  ),
                ),
                
                // Contenu de l'étape actuelle
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: _buildCurrentStepContent(scaffoldContext), // Pass scaffoldContext
                  ),
                ),
                
                // Boutons de navigation
                Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      if (_currentStep > 0)
                        Expanded(
                          child: CustomButton(
                            text: 'Précédent',
                            onPressed: _previousStep,
                            isPrimary: false,
                            height: AppSpacing.buttonLarge,
                            borderRadius: AppSpacing.radiusMd,
                          ),
                        ),
                      if (_currentStep > 0)
                        SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: CustomButton(
                          text: _currentStep == _totalSteps - 1 ? 'Publier' : 'Suivant',
                          onPressed: _currentStep == _totalSteps - 1 ? () => _submitPost(scaffoldContext) : _nextStep, // Pass scaffoldContext
                          isPrimary: true,
                          height: AppSpacing.buttonLarge,
                          borderRadius: AppSpacing.radiusMd,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
  
  // Titre de l'étape actuelle
  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'Choisissez une catégorie';
      case 1:
        return 'Ajoutez des photos (Max 5 photos)';
      case 2:
        return 'Décrivez votre article';
      case 3:
        return 'Définissez le prix et l\'état';
      case 4:
        return 'Précisez la localisation';
      default:
        return '';
    }
  }
  
  // Contenu de l'étape actuelle
  Widget _buildCurrentStepContent(BuildContext scaffoldContext) { // Accept scaffoldContext
    switch (_currentStep) {
      case 0:
        // Category selection
        return _buildCategorySelectionStep(scaffoldContext); // Pass scaffoldContext
      case 1:
        // Image selection
        return _buildImageSelectionStep(scaffoldContext); // Pass scaffoldContext
      case 2:
        // Title and description
        return _buildTitleDescriptionStep(scaffoldContext); // Pass scaffoldContext
      case 3:
        // Price and condition
        return _buildPriceConditionStep(scaffoldContext); // Pass scaffoldContext
      case 4:
        // Location selection
        return _buildLocationSelectionStep(scaffoldContext); // Pass scaffoldContext
      default:
        return const SizedBox.shrink();
    }
  }
  
  Widget _buildCategorySelectionStep(BuildContext scaffoldContext) { // Accept scaffoldContext
    final isDarkMode = Theme.of(scaffoldContext).brightness == Brightness.dark; // Use scaffoldContext
    
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('services').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(child: Text('Erreur: ${snapshot.error}'));
        }
        
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text(
              'Aucune catégorie disponible',
              style: AppTypography.bodyMedium(scaffoldContext), // Use scaffoldContext
            ),
          );
        }
        
        final services = snapshot.data!.docs;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: AppSpacing.md), // Keep spacing if needed
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.2,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
              ),
              itemCount: services.length,
              itemBuilder: (context, index) {
                final service = services[index].data() as Map<String, dynamic>;
                final serviceId = services[index].id;
                final serviceName = service['name'] ?? 'Catégorie';
                final imageUrl = service['imageUrl'] ?? '';
                final isSelected = _selectedCategory == serviceId;
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = serviceId;
                    });
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? AppColors.primaryGreen.withOpacity(0.2)
                          : (isDarkMode ? AppColors.darkCardBackground : AppColors.lightCardBackground),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(
                        color: isSelected ? AppColors.primaryGreen : Colors.transparent,
                        width: isSelected ? 2 : 0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDarkMode ? Colors.black.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (imageUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                            child: Image.network(
                              imageUrl,
                              width: AppSpacing.xxl,
                              height: AppSpacing.xxl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: AppSpacing.xxl,
                                  height: AppSpacing.xxl,
                                  color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                                    size: AppSpacing.iconLg,
                                  ),
                                );
                              },
                            ),
                          )
                        else
                          Icon(
                            Icons.category,
                            size: AppSpacing.iconLg,
                            color: isSelected ? AppColors.primaryGreen : (isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                          ),
                        SizedBox(height: AppSpacing.sm),
                        Text(
                          serviceName,
                          style: AppTypography.labelLarge(
                            scaffoldContext, // Use scaffoldContext
                            color: isSelected 
                                ? AppColors.primaryGreen 
                                : (isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildImageSelectionStep(BuildContext scaffoldContext) { // Accept scaffoldContext
    final isDarkMode = Theme.of(scaffoldContext).brightness == Brightness.dark; // Use scaffoldContext
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: AppSpacing.lg),
        if (_images.isEmpty)
          Center(
            child: GestureDetector(
              onTap: () => _pickImages(scaffoldContext), // Pass scaffoldContext
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: isDarkMode ? AppColors.darkCardBackground : AppColors.lightCardBackground,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  border: Border.all(
                    color: isDarkMode ? AppColors.darkBorderColor : AppColors.lightBorderColor,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDarkMode ? Colors.black.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: AppSpacing.iconXl,
                      color: isDarkMode ? AppColors.darkTextHint : AppColors.lightTextHint,
                    ),
                    SizedBox(height: AppSpacing.md),
                    Text(
                      'Appuyez pour ajouter des photos',
                      style: AppTypography.bodyLarge(scaffoldContext, color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextPrimary), // Use scaffoldContext
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Column(
            children: [
              // Display images using ImageGalleryUtils
              ImageGalleryUtils.buildImageGallery(
                scaffoldContext, // Pass scaffoldContext
                _images, // Pass the list of File objects
                isDarkMode: isDarkMode,
                fixedHeight: 350, // Adjusted height to prevent overflow
                onRemoveImage: (index) => _removeImage(index), // Pass the remove callback
              ),
              SizedBox(height: AppSpacing.md),
              if (_images.length < 5) // Only show button if less than 5 images
                CustomButton(
                  text: 'Ajouter plus de photos',
                  onPressed: () => _pickImages(scaffoldContext), // Pass scaffoldContext
                  isPrimary: false,
                  height: AppSpacing.buttonMedium,
                  borderRadius: AppSpacing.radiusMd,
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildTitleDescriptionStep(BuildContext scaffoldContext) { // Accept scaffoldContext
// Use scaffoldContext
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: AppSpacing.lg),
        CustomTextField(
          controller: _titleController,
          labelText: 'Titre',
          hintText: 'Ex: iPhone 13 Pro Max 256GB',
          maxLength: 50,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Le titre est obligatoire';
            }
            if (value.length < 3) {
              return 'Le titre doit contenir au moins 3 caractères';
            }
            return null;
          },
        ),
        SizedBox(height: AppSpacing.md),
        CustomTextField(
          controller: _descriptionController,
          labelText: 'Description',
          hintText: 'Décrivez votre article en détail...',
          maxLines: 6,
          maxLength: 1000,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'La description est obligatoire';
            }
            if (value.length < 10) {
              return 'La description doit contenir au moins 10 caractères';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPriceConditionStep(BuildContext scaffoldContext) { // Accept scaffoldContext
    final isDarkMode = Theme.of(scaffoldContext).brightness == Brightness.dark; // Use scaffoldContext
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: AppSpacing.lg),
        CustomTextField(
          controller: _priceController,
          labelText: 'Prix (TND)',
          hintText: 'Ex: 299.99',
          prefixIcon: const Icon(Icons.wallet),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Le prix est obligatoire';
            }
            try {
              double price = double.parse(value);
              if (price <= 0) {
                return 'Le prix doit être supérieur à 0';
              }
            } catch (e) {
              return 'Veuillez entrer un prix valide';
            }
            return null;
          },
        ),
        SizedBox(height: AppSpacing.lg),
        Text(
          'État du produit',
          style: AppTypography.bodyLarge(scaffoldContext, color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary), // Use scaffoldContext
        ),
        SizedBox(height: AppSpacing.md),
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
      ],
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
                : (isDarkMode ? AppColors.darkBorderColor : AppColors.lightBorderColor),
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

  Widget _buildLocationSelectionStep(BuildContext scaffoldContext) { // Accept scaffoldContext
    final isDarkMode = Theme.of(scaffoldContext).brightness == Brightness.dark; // Use scaffoldContext
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: AppSpacing.lg),
        
        // Current location button moved to top
        Container(
          width: double.infinity,
          margin: EdgeInsets.only(bottom: AppSpacing.lg), // Add margin below button
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryGreen.withOpacity(0.1),
                AppColors.primaryGreen.withOpacity(0.05),
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(
              color: AppColors.primaryGreen.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              onTap: _useCurrentLocation,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.gps_fixed,
                      color: AppColors.primaryGreen,
                      size: AppSpacing.iconMd,
                    ),
                    SizedBox(width: AppSpacing.md),
                    Text(
                      'Utiliser ma position actuelle',
                      style: AppTypography.labelLarge(scaffoldContext, color: AppColors.primaryGreen), // Use scaffoldContext
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        
        // Enhanced map container
        Container(
          height: 320,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _selectedLocation ?? const LatLng(36.8065, 10.1815), // Default to Tunis
                    zoom: 13.0,
                  ),
                  onMapCreated: (controller) {
                    _googleMapController = controller;
                  },
                  onTap: (latLng) {
                    setState(() {
                      _selectedLocation = latLng;
                    });
                    _getAddressFromLatLng(latLng);
                  },
                  markers: _selectedLocation != null
                      ? {
                          Marker(
                            markerId: const MarkerId('selected-location'),
                            position: _selectedLocation!,
                            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                          ),
                        }
                      : {},
                ),
                
                // Map overlay with instructions
                if (_selectedLocation == null)
                  Positioned(
                    top: AppSpacing.md,
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.black87 : Colors.white,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.touch_app,
                            color: AppColors.primaryGreen,
                            size: AppSpacing.iconSm,
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              'Appuyez sur la carte pour sélectionner la localisation',
                              style: AppTypography.bodySmall(scaffoldContext, color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary), // Use scaffoldContext
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(height: AppSpacing.lg),
        
        // Location input moved under the map
        CustomTextField(
          controller: _locationController,
          labelText: 'Adresse',
          hintText: 'Ex: Avenue Habib Bourguiba, Tunis',
          // Removed prefixIcon as it's redundant with the map
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Veuillez entrer une adresse';
            }
            return null;
          },
        ),
      ],
    );
  }
                
  Future<void> _getAddressFromLatLng(LatLng latLng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _locationController.text = _formatAddress(place);
        });
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
    }
  }
  // Obtenir l'icône correspondant à l'état
}
