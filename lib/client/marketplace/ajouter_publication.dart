import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_dialog.dart';
import '../../widgets/product_state_option.dart';
import '../../widgets/image_upload_section.dart';
import '../../widgets/labeled_text_field.dart';

class AddPostPage extends StatefulWidget {
  const AddPostPage({super.key});

  @override
  State<AddPostPage> createState() => _AddPostPageState();
}

class _AddPostPageState extends State<AddPostPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  String? _etatProduit; // "Neuf" ou "Occasion"
  final List<File> _images = [];
  final _picker = ImagePicker();
  bool _isUploading = false;
  bool _isImageUploading = false;
  String? _titleError;
  String? _descriptionError;
  String? _priceError;

  final String cloudName = "dfk7mskxv";
  final String uploadPreset = "plateforme_service";

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  // Méthode pour supprimer une image de la liste
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

  // Update the validation method
  bool _validateFields() {
    bool isValid = true;
    
    setState(() {
      _titleError = null;
      _descriptionError = null;
      _priceError = null;
    });
    
    // Validate all fields first
    List<String> errors = [];
    
    if (_titleController.text.trim().isEmpty) {
      setState(() => _titleError = "Le titre est obligatoire");
      errors.add("Le titre est obligatoire");
    } else if (_titleController.text.length < 3) {
      setState(() => _titleError = "Le titre doit contenir au moins 3 caractères");
      errors.add("Le titre doit contenir au moins 3 caractères");
    }
    
    if (_descriptionController.text.trim().isEmpty) {
      setState(() => _descriptionError = "La description est obligatoire");
      errors.add("La description est obligatoire");
    } else if (_descriptionController.text.length < 10) {
      setState(() => _descriptionError = "La description doit contenir au moins 10 caractères");
      errors.add("La description doit contenir au moins 10 caractères");
    }
    
    if (_priceController.text.trim().isEmpty) {
      setState(() => _priceError = "Le prix est obligatoire");
      errors.add("Le prix est obligatoire");
    } else {
      try {
        double price = double.parse(_priceController.text);
        if (price <= 0) {
          setState(() => _priceError = "Le prix doit être supérieur à 0");
          errors.add("Le prix doit être supérieur à 0");
        }
      } catch (e) {
        setState(() => _priceError = "Veuillez entrer un prix valide");
        errors.add("Veuillez entrer un prix valide");
      }
    }
    
    if (_etatProduit == null) {
      errors.add("Veuillez sélectionner l'état du produit");
    }
    
    if (_images.isEmpty) {
      errors.add("Veuillez ajouter au moins une image");
    }
    
    // If there are errors, show them in a custom dialog
    if (errors.isNotEmpty) {
      CustomDialog.show(
        context,
        "Erreurs de validation",
        errors.join("\n• "),
      );
      isValid = false;
    }
    
    return isValid;
  }

  // Update the image picker error handling
  Future<void> _pickImages() async {
    try {
      setState(() => _isImageUploading = true);
      final pickedFiles = await _picker.pickMultiImage(
        imageQuality: 70,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      
      if (pickedFiles.isNotEmpty) {
        if (_images.length + pickedFiles.length > 5) {
          CustomDialog.show(
            context,
            "Limite d'images atteinte",
            "Vous pouvez ajouter un maximum de 5 images. Seules les premières images seront ajoutées.",
          );
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
      CustomDialog.show(
        context,
        "Erreur",
        "Une erreur est survenue lors de la sélection des images: ${e.toString()}",
      );
    } finally {
      setState(() => _isImageUploading = false);
    }
  }

  // Update the submission dialog
  Future<void> _submitPost() async {
    if (!_validateFields() || _isUploading) return;
    
    setState(() => _isUploading = true);
    
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Theme.of(context).brightness == Brightness.dark 
                ? const Color(0xFF1E1E1E) 
                : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
              side: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.grey[700]! 
                    : Colors.grey[300]!,
                width: 1,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                const Text("Publication en cours..."),
              ],
            ),
          );
        },
      );
      
      List<String> imageUrls = [];
      int uploadedCount = 0;
      
      // Upload des images
      for (var image in _images) {
        String? url = await _uploadImageToCloudinary(image);
        if (url != null) {
          imageUrls.add(url);
          uploadedCount++;
          
          // Mettre à jour le dialogue de progression
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (BuildContext context) {
                return AlertDialog(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        value: uploadedCount / _images.length,
                      ),
                      const SizedBox(height: 16),
                      Text("Téléchargement des images: $uploadedCount/${_images.length}"),
                    ],
                  ),
                );
              },
            );
          }
        }
      }
      
      if (imageUrls.isEmpty) {
        throw Exception("Échec du téléchargement des images");
      }

      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Utilisateur non connecté");
      }

      Map<String, dynamic> postData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text),
        'etat': _etatProduit,
        'userId': user.uid,
        'images': imageUrls,
        'createdAt': FieldValue.serverTimestamp(),  // Changed from 'timestamp'
        'isValidated': false,
      };

      await FirebaseFirestore.instance.collection('marketplace').add(postData);

      // Fermer le dialogue de progression
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Update navigation after successful submission
      if (mounted) {
        context.go('/clientHome/marketplace');
        CustomDialog.show(
          context,
          "Succès",
          "Post soumis avec succès ! Il est maintenant en attente de validation.",
          onConfirm: () => context.go('/clientHome/marketplace'),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close progress dialog
        CustomDialog.show(
          context,
          "Erreur",
          "Une erreur est survenue lors de la publication: ${e.toString()}",
        );
      }
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter un Post'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/clientHome/marketplace'),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).colorScheme.primary.withOpacity(0.05),
              Theme.of(context).colorScheme.surface,
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomCard(
                  title: "Informations du produit",
                  child: Column(
                    children: [
                      LabeledTextField(
                        label: 'Titre du produit',
                        controller: _titleController,
                        hint: 'Entrez le titre',
                        icon: Icons.title,
                        validator: (value) => _titleError,
                      ),
                      const SizedBox(height: 16),
                      LabeledTextField(
                        label: 'Description',
                        controller: _descriptionController,
                        hint: 'Décrivez votre produit',
                        icon: Icons.description,
                        validator: (value) => _descriptionError,
                      ),
                      const SizedBox(height: 16),
                      LabeledTextField(
                        label: 'Prix (TND)',
                        controller: _priceController,
                        hint: 'Entrez le prix',
                        icon: Icons.attach_money,
                        validator: (value) => _priceError,
                        suffixIcon: const Text(' TND  ', style: TextStyle(color: Colors.grey)),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                CustomCard(
                  title: "État du produit",
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ProductStateOption(
                        label: "Neuf",
                        icon: Icons.new_releases,
                        isSelected: _etatProduit == "Neuf",
                        onTap: () => setState(() => _etatProduit = "Neuf"),
                      ),
                      ProductStateOption(
                        label: "Occasion",
                        icon: Icons.history,
                        isSelected: _etatProduit == "Occasion",
                        onTap: () => setState(() => _etatProduit = "Occasion"),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                ImageUploadSection(
                  images: _images,
                  onPickImages: _pickImages,
                  onRemoveImage: _removeImage,
                  isUploading: _isImageUploading,
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: CustomButton(
        onPressed: _isUploading ? null : _submitPost,
        text: _isUploading ? 'Publication en cours...' : 'Publier',
        isLoading: _isUploading,
      ),
    );
  }

}
