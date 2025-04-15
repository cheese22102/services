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
  
  // Catégories (identiques à celles de accueil_marketplace.dart)
  final List<Map<String, dynamic>> _categories = [
    {'name': 'Électronique', 'icon': Icons.phone_android},
    {'name': 'Vêtements', 'icon': Icons.checkroom},
    {'name': 'Maison', 'icon': Icons.chair},
    {'name': 'Sport', 'icon': Icons.sports_soccer},
    {'name': 'Véhicules', 'icon': Icons.directions_car},
    {'name': 'Jardinage', 'icon': Icons.grass},
    {'name': 'Autre', 'icon': Icons.more_horiz},
  ];
  
  // Cloudinary config
  final String cloudName = "dfk7mskxv";
  final String uploadPreset = "plateforme_service";

  @override
  void initState() {
    super.initState();
  _getCurrentLocation(); // Add this line
    _initUserLocation();
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
        'category': _selectedCategory,
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
        return _buildCategoryStep(isDarkMode);
      case 1:
        return _buildImagesStep(isDarkMode);
      case 2:
        return _buildDescriptionStep(isDarkMode);
      case 3:
        return _buildPriceAndConditionStep(isDarkMode);
      case 4:
        return _buildLocationAndSummaryStep(isDarkMode);
      default:
        return const SizedBox.shrink();
    }
  }
  
  // Étape 1: Choix de la catégorie
  Widget _buildCategoryStep(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sélectionnez la catégorie qui correspond le mieux à votre article:',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.9,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final category = _categories[index];
            final isSelected = _selectedCategory == category['name'];
            
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategory = category['name'] as String;
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDarkMode ? AppColors.primaryGreen.withOpacity(0.2) : AppColors.primaryDarkGreen.withOpacity(0.1))
                      : (isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(15),
                  border: isSelected
                      ? Border.all(
                          color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                          width: 2,
                        )
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      category['icon'] as IconData,
                      size: 40,
                      color: isSelected
                          ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                          : (isDarkMode ? Colors.white70 : Colors.black54),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      category['name'] as String,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                            : (isDarkMode ? Colors.white70 : Colors.black54),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
  
  // Étape 2: Ajout des images
  Widget _buildImagesStep(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ajoutez jusqu\'à 5 photos de votre article:',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'La première photo sera l\'image principale de votre annonce.',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: isDarkMode ? Colors.white54 : Colors.black54,
          ),
        ),
        const SizedBox(height: 20),
        
        // Grille d'images
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 1,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: _images.length + (_images.length < 5 ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _images.length) {
              // Bouton d'ajout d'image
              return GestureDetector(
                onTap: _pickImages,
                child: Container(
                  decoration: BoxDecoration(
                    color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.add_a_photo,
                      size: 30,
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              );
            } else {
              // Image existante
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      image: DecorationImage(
                        image: FileImage(_images[index]),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 5,
                    right: 5,
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
                  if (index == 0)
                    Positioned(
                      bottom: 5,
                      left: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Principale',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            }
          },
        ),
      ],
    );
  }
  
  // Étape 3: Titre et description
  Widget _buildDescriptionStep(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Donnez un titre à votre annonce:',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _titleController,
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          decoration: InputDecoration(
            hintText: 'Ex: iPhone 13 Pro Max 256Go',
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
          ),
          maxLength: 50,
        ),
        const SizedBox(height: 20),
        Text(
          'Décrivez votre article en détail:',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _descriptionController,
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          decoration: InputDecoration(
            hintText: 'Décrivez l\'état, les caractéristiques, etc.',
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
          ),
          maxLines: 5,
          maxLength: 500,
        ),
      ],
    );
  }
  
  // Étape 4: Prix et état
  Widget _buildPriceAndConditionStep(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Définissez le prix de votre article:',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _priceController,
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.white : Colors.black,
          ),
          decoration: InputDecoration(
            hintText: 'Prix en DT',
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
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 30),
        Text(
          'Quel est l\'état de votre article?',
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: _buildConditionOption(
                'Neuf',
                'Jamais utilisé, avec emballage d\'origine',
                Icons.new_releases,
                isDarkMode,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildConditionOption(
                'Très bon',
                'Utilisé quelques fois, comme neuf',
                Icons.thumb_up,
                isDarkMode,
              ),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Row(
          children: [
            Expanded(
              child: _buildConditionOption(
                'Bon',
                'Utilisé mais bien entretenu',
                Icons.check_circle,
                isDarkMode,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: _buildConditionOption(
                'Occasion',
                'Utilisé avec des signes d\'usure',
                Icons.handyman,
                isDarkMode,
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  // Widget pour les options d'état
  Widget _buildConditionOption(String title, String description, IconData icon, bool isDarkMode) {
    final isSelected = _condition == title;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _condition = title;
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
              size: 30,
              color: isSelected
                  ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                  : (isDarkMode ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                    : (isDarkMode ? Colors.white : Colors.black87),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: isDarkMode ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
    // Étape 5: Localisation et récapitulatif
  Widget _buildLocationAndSummaryStep(bool isDarkMode) {
  return SingleChildScrollView(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Où se trouve votre article?',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        
        // Current location button
        ElevatedButton.icon(
          onPressed: _useCurrentLocation,
          icon: const Icon(Icons.my_location),
          label: const Text('Utiliser ma position actuelle'),
          style: ElevatedButton.styleFrom(
            backgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.white,
            foregroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
            elevation: 2,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Map
        Container(
          height: 250,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              center: _selectedLocation ?? const LatLng(36.8065, 10.1815), // Default to Tunis
              zoom: 13.0,
              onTap: (tapPosition, latLng) {
                setState(() {
                  _selectedLocation = latLng;
                  _locationController.text = 'Recherche de l\'Adresse';
                });
                
                // Get address from coordinates
                placemarkFromCoordinates(latLng.latitude, latLng.longitude)
                  .then((placemarks) {
                    if (placemarks.isNotEmpty) {
                      Placemark place = placemarks[0];
                      setState(() {
                        _locationController.text = place.locality ?? '';
                      });
                    } else {
                      setState(() {
                        _locationController.text = '';
                      });
                    }
                  })
                  .catchError((e) {
                    debugPrint('Error during geocoding: $e');
                    setState(() {
                      _locationController.text = '';
                    });
                  });
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
                        Icons.location_on,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey.shade800.withOpacity(0.5) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Catégorie
              Row(
                children: [
                  Icon(
                    _categories.firstWhere((c) => c['name'] == _selectedCategory)['icon'] as IconData,
                    size: 20,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Catégorie: $_selectedCategory',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Titre
              Text(
                _titleController.text.isEmpty ? 'Titre non défini' : _titleController.text,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              
              // Prix
              Text(
                _priceController.text.isEmpty 
                    ? 'Prix non défini' 
                    : '${_priceController.text} DT',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                ),
              ),
              const SizedBox(height: 12),
              
              // État
              Row(
                children: [
                  Icon(
                    _getConditionIcon(_condition),
                    size: 16,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'État: $_condition',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Localisation
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                  child:Text(
                    _locationController.text.isEmpty 
                        ? 'Localisation non définie' 
                        : _locationController.text,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                     overflow: TextOverflow.ellipsis,
                     maxLines: 2,
                  ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Nombre d'images
              Row(
                children: [
                  Icon(
                    Icons.photo_library,
                    size: 16,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_images.length} image${_images.length > 1 ? 's' : ''}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 20),
        Text(
          'En cliquant sur "Publier", votre annonce sera visible par tous les utilisateurs.',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontStyle: FontStyle.italic,
            color: isDarkMode ? Colors.white54 : Colors.black54,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ));
  }
  
  // Obtenir l'icône correspondant à l'état
  IconData _getConditionIcon(String condition) {
    switch (condition) {
      case 'Neuf':
        return Icons.new_releases;
      case 'Très bon':
        return Icons.thumb_up;
      case 'Bon':
        return Icons.check_circle;
      case 'Occasion':
        return Icons.handyman;
      default:
        return Icons.help_outline;
    }
  }
}