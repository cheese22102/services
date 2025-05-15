import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../front/app_colors.dart';
import '../../front/custom_app_bar.dart';
import '../../front/custom_button.dart';
import '../../front/custom_dialog.dart';
import '../../front/loading_overlay.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';


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
  String _condition = 'Neuf'; // Par défaut
  List<File> _images = [];
  final _picker = ImagePicker();
  bool _isUploading = false;

// Variables for map and location
LatLng? _selectedLocation;
final MapController _mapController = MapController();
  
  // Replace static categories with dynamic services
  List<Map<String, dynamic>> _services = [];
  
  // Cloudinary config
  final String cloudName = "dfk7mskxv";
  final String uploadPreset = "plateforme_service";

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
          _services = loadedServices;
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
    super.dispose();
  }

  // Méthode pour passer à l'étape suivante
  void _nextStep() {
    if (_validateCurrentStep()) {
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
    _mapController.move(_selectedLocation!, 15.0);
  }
}
  // Validation de l'étape courante
  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: // Catégorie
        if (_selectedCategory == null) {
          _showErrorSnackBar('Veuillez sélectionner une catégorie');
          return false;
        }
        return true;
        
      case 1: // Images
        if (_images.isEmpty) {
          _showErrorSnackBar('Veuillez ajouter au moins une image');
          return false;
        }
        return true;
        
      case 2: // Titre et description
        if (_titleController.text.trim().isEmpty) {
          _showErrorSnackBar('Le titre est obligatoire');
          return false;
        }
        if (_titleController.text.length < 3) {
          _showErrorSnackBar('Le titre doit contenir au moins 3 caractères');
          return false;
        }
        if (_descriptionController.text.trim().isEmpty) {
          _showErrorSnackBar('La description est obligatoire');
          return false;
        }
        if (_descriptionController.text.length < 10) {
          _showErrorSnackBar('La description doit contenir au moins 10 caractères');
          return false;
        }
        return true;
        
      case 3: // Prix et état
        if (_priceController.text.trim().isEmpty) {
          _showErrorSnackBar('Le prix est obligatoire');
          return false;
        }
        try {
          double price = double.parse(_priceController.text);
          if (price <= 0) {
            _showErrorSnackBar('Le prix doit être supérieur à 0');
            return false;
          }
        } catch (e) {
          _showErrorSnackBar('Veuillez entrer un prix valide');
          return false;
        }
        return true;
        
      case 4: // Localisation et récapitulatif
        if (_locationController.text.trim().isEmpty) {
          _showErrorSnackBar('La localisation est obligatoire');
          return false;
        }
        return true;
        
      default:
        return true;
    }
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  // Méthode pour sélectionner des images
  Future<void> _pickImages() async {
    try {
      final pickedFiles = await _picker.pickMultiImage(
        imageQuality: 70,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      
      if (pickedFiles.isNotEmpty) {
        if (_images.length + pickedFiles.length > 5) {
          _showErrorSnackBar('Maximum 5 images autorisées');
          final remainingSlots = 5 - _images.length;
          final filesToAdd = pickedFiles.take(remainingSlots).toList();
          setState(() {
            _images.addAll(filesToAdd.map((file) => File(file.path)));
          });
        } else {
          setState(() {
            _images.addAll(pickedFiles.map((file) => File(file.path)));
          });
        }
      }
    } catch (e) {
      _showErrorSnackBar('Erreur lors de la sélection des images');
    }
  }
  
  // Méthode pour supprimer une image
  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
    });
  }

  // Upload d'une image sur Cloudinary
  Future<String?> _uploadImageToCloudinary(File imageFile) async {
    final url = "https://api.cloudinary.com/v1_1/$cloudName/image/upload";
    try {
      var request = http.MultipartRequest('POST', Uri.parse(url));
      request.fields['upload_preset'] = uploadPreset;
      request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
      
      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var jsonData = json.decode(responseData);
        return jsonData['secure_url'];
      } else {
        throw Exception("Échec du téléchargement. Code: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Erreur d'upload: $e");
      return null;
    }
  }

 // Méthode pour publier l'annonce
   Future<void> _submitPost() async {
    if (!_validateCurrentStep() || _isUploading) return;
    
    // Show confirmation dialog before proceeding
    final confirmSubmit = await _showConfirmationDialog();
    if (confirmSubmit != true) {
      return; // User cancelled the submission
    }
    
    setState(() => _isUploading = true);
    
    try {
      // Utiliser le LoadingOverlay personnalisé au lieu du dialogue standard
      LoadingOverlay.show(context);
      
      // Upload des images
      List<String> imageUrls = [];
      for (var image in _images) {
        String? url = await _uploadImageToCloudinary(image);
        if (url != null) {
          imageUrls.add(url);
        }
      }
      
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Votre publication est en attente de validation, vous serez notifié lorsqu\'une décision est prise',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        context.pop();
      }
    } catch (e) {
      // Fermer le LoadingOverlay
      LoadingOverlay.hide();
      
      // Afficher un message d'erreur
      if (mounted) {
        _showErrorSnackBar('Erreur lors de la publication: ${e.toString()}');
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
    String categoryName = 'Catégorie inconnue';
    if (_selectedCategory != null) {
      for (var service in _services) {
        if (service['id'] == _selectedCategory) {
          categoryName = service['name'];
          break;
        }
      }
    }
    
    // Format the price with 2 decimal places
    String formattedPrice = '';
    try {
      double price = double.parse(_priceController.text);
      formattedPrice = price.toStringAsFixed(2);
    } catch (e) {
      formattedPrice = _priceController.text;
    }
    
    // Build the confirmation message
    final message = '''
Titre: ${_titleController.text}

Description: ${_descriptionController.text}

Prix: $formattedPrice TND

État: $_condition

Catégorie: $categoryName

Localisation: ${_locationController.text}

Images: ${_images.length} image(s)

Veuillez vérifier les informations ci-dessus avant de publier votre annonce.
''';

    return CustomDialog.showConfirmation(
      context: context,
      title: 'Confirmer la publication',
      message: message,
      confirmText: 'Publier',
      cancelText: 'Modifier',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: CustomAppBar(
        title: 'Nouvelle annonce',
        showBackButton: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Indicateur de progression
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                children: [
                  Row(
                    children: List.generate(_totalSteps, (index) {
                      return Expanded(
                        child: Container(
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: index <= _currentStep
                                ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                                : (isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getStepTitle(),
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            
            // Contenu de l'étape actuelle
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: _buildCurrentStepContent(isDarkMode),
              ),
            ),
            
            // Boutons de navigation
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: CustomButton(
                        text: 'Précédent',
                        onPressed: _previousStep,
                        isPrimary: false,
                        height: 50,
                      ),
                    ),
                  if (_currentStep > 0)
                    const SizedBox(width: 10),
                  Expanded(
                    child: CustomButton(
                      text: _currentStep == _totalSteps - 1 ? 'Publier' : 'Suivant',
                      onPressed: _currentStep == _totalSteps - 1 ? _submitPost : _nextStep,
                      isPrimary: true,
                      height: 50,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Titre de l'étape actuelle
  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'Choisissez une catégorie';
      case 1:
        return 'Ajoutez des photos';
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
  Widget _buildCurrentStepContent(bool isDarkMode) {
    switch (_currentStep) {
      case 0:
        // Category selection
        return _buildCategorySelectionStep();
      case 1:
        // Image selection
        return _buildImageSelectionStep(isDarkMode);
      case 2:
        // Title and description
        return _buildTitleDescriptionStep(isDarkMode);
      case 3:
        // Price and condition
        return _buildPriceConditionStep(isDarkMode);
      case 4:
        // Location selection (without overview)
        return _buildLocationSelectionStep(isDarkMode);
      default:
        return const SizedBox.shrink();
    }
  }
  
 // ... existing code ...

  Widget _buildCategorySelectionStep() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
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
          return const Center(child: Text('Aucune catégorie disponible'));
        }
        
        final services = snapshot.data!.docs;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sélectionnez une catégorie',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
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
                          : (isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppColors.primaryGreen : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (imageUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              imageUrl,
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey.shade300,
                                  child: Icon(
                                    Icons.image_not_supported,
                                    color: Colors.grey.shade700,
                                  ),
                                );
                              },
                            ),
                          )
                        else
                          Icon(
                            Icons.category,
                            size: 40,
                            color: isSelected ? AppColors.primaryGreen : Colors.grey,
                          ),
                        const SizedBox(height: 8),
                        Text(
                          serviceName,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected 
                                ? AppColors.primaryGreen 
                                : (isDarkMode ? Colors.white : Colors.black87),
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

  Widget _buildImageSelectionStep(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ajoutez des photos de votre article (max 5)',
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 20),
        if (_images.isEmpty)
          Center(
            child: GestureDetector(
              onTap: _pickImages,
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 48,
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Appuyez pour ajouter des photos',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          Column(
            children: [
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _images.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: FileImage(_images[index]),
                            fit: BoxFit.cover,
                          ),
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
                  );
                },
              ),
              const SizedBox(height: 16),
              if (_images.length < 5)
                CustomButton(
                  text: 'Ajouter plus de photos',
                  onPressed: _pickImages,
                  isPrimary: false,
                  height: 50,
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildTitleDescriptionStep(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Décrivez votre article',
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: 'Titre',
            hintText: 'Ex: iPhone 13 Pro Max 256GB',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: isDarkMode ? Colors.grey.shade800 : Colors.white,
          ),
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          maxLength: 50,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _descriptionController,
          decoration: InputDecoration(
            labelText: 'Description',
            hintText: 'Décrivez votre article en détail...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: isDarkMode ? Colors.grey.shade800 : Colors.white,
            alignLabelWithHint: true,
          ),
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          maxLines: 6,
          maxLength: 1000,
        ),
      ],
    );
  }

  Widget _buildPriceConditionStep(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Définissez le prix et l\'état',
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _priceController,
          decoration: InputDecoration(
            labelText: 'Prix (TND)',
            hintText: 'Ex: 299.99',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: isDarkMode ? Colors.grey.shade800 : Colors.white,
            prefixIcon: const Icon(Icons.wallet),
          ),
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 24),
        Text(
          'État du produit',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
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
      child: Chip(
        label: Text(
          condition,
          style: GoogleFonts.poppins(
            color: isSelected
                ? Colors.white
                : (isDarkMode ? Colors.white70 : Colors.black87),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        backgroundColor: isSelected
            ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
            : (isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }

  Widget _buildLocationSelectionStep(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Précisez la localisation',
          style: GoogleFonts.poppins(
            fontSize: 16,
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _locationController,
          decoration: InputDecoration(
            labelText: 'Localisation',
            hintText: 'Ex: Paris, France',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: isDarkMode ? Colors.grey.shade800 : Colors.white,
            prefixIcon: const Icon(Icons.location_on),
            suffixIcon: IconButton(
              icon: const Icon(Icons.my_location),
              onPressed: _useCurrentLocation,
              tooltip: 'Utiliser ma position actuelle',
            ),
          ),
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          height: 300,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                center: _selectedLocation ?? const LatLng(48.8566, 2.3522), // Default to Paris
                zoom: 13.0,
                onTap: (tapPosition, latLng) {
                  setState(() {
                    _selectedLocation = latLng;
                  });
                  _getAddressFromLatLng(latLng);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                ),
                if (_selectedLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        width: 40.0,
                        height: 40.0,
                        point: _selectedLocation!,
                        builder: (ctx) => const Icon(
                          Icons.location_pin,
                          color: Colors.red,
                          size: 40,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        CustomButton(
          text: 'Utiliser ma position actuelle',
          onPressed: _useCurrentLocation,
          isPrimary: false,
          height: 50,
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