import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '/widgets/custom_card.dart';
import '/widgets/custom_button.dart';
import '/widgets/labeled_text_field.dart';
import '/widgets/product_state_option.dart';
import '/widgets/image_upload_section.dart';
import '/widgets/custom_dialog.dart';

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
  String? _etatProduit;
  final List<File> _images = [];  // Changed from _imageUrls
  List<String> _existingImageUrls = [];  // To store existing image URLs
  final _picker = ImagePicker();
  bool _isUploading = false;
  bool _isImageUploading = false;
  String? _titleError;
  String? _descriptionError;
  String? _priceError;

  final String cloudName = "dfk7mskxv";
  final String uploadPreset = "plateforme_service";

  @override
  void initState() {
    super.initState();
    final data = widget.post.data() as Map<String, dynamic>;
    _titleController.text = data['title'];
    _descriptionController.text = data['description'];
    _priceController.text = data['price'].toString();
    _etatProduit = data['etat'];
    _existingImageUrls = List<String>.from(data['images'] ?? []);
  }

  // Add image removal method
  void _removeImage(int index) {
    setState(() {
      if (index < _existingImageUrls.length) {
        _existingImageUrls.removeAt(index);
      } else {
        _images.removeAt(index - _existingImageUrls.length);
      }
    });
  }

  // Update image picker method
  Future<void> _pickImages() async {
    try {
      setState(() => _isImageUploading = true);
      final pickedFiles = await _picker.pickMultiImage(
        imageQuality: 70,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      
      if (pickedFiles.isNotEmpty) {
        final totalImages = _existingImageUrls.length + _images.length + pickedFiles.length;
        if (totalImages > 5) {
          CustomDialog.show(
            context,
            "Limite d'images atteinte",
            "Vous pouvez ajouter un maximum de 5 images. Seules les premières images seront ajoutées.",
          );
          final remainingSlots = 5 - (_existingImageUrls.length + _images.length);
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

  // Update the update post method
  Future<void> _updatePost() async {
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
                const Text("Modification en cours..."),
              ],
            ),
          );
        },
      );

      // Upload new images
      List<String> allImageUrls = List.from(_existingImageUrls);
      int uploadedCount = 0;
      
      for (var image in _images) {
        String? url = await _uploadImageToCloudinary(image);
        if (url != null) {
          allImageUrls.add(url);
          uploadedCount++;
          
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

      await widget.post.reference.update({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text),
        'images': allImageUrls,
        'etat': _etatProduit,
        'isValidated': false,
        'lastModified': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        context.pop(); // Close progress dialog
        context.pop(); // Return to previous screen
        CustomDialog.show(
          context,
          "Succès",
          "Post modifié avec succès ! Il est maintenant en attente de validation.",
          onConfirm: () => context.go('/clientHome/marketplace'),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close progress dialog
        CustomDialog.show(
          context,
          "Erreur",
          "Une erreur est survenue lors de la modification: ${e.toString()}",
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
        title: const Text('Modifier le Post'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
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
                  images: [..._existingImageUrls.map((url) => File(url)), ..._images],
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
        onPressed: _isUploading ? null : _updatePost,
        text: _isUploading ? 'Modification en cours...' : 'Modifier',
        isLoading: _isUploading,
      ),
    );
  }

  bool _validateFields() {
    bool isValid = true;
    
    setState(() {
      _titleError = null;
      _descriptionError = null;
      _priceError = null;
    });
    
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
    
    if (_existingImageUrls.isEmpty && _images.isEmpty) {
      errors.add("Veuillez ajouter au moins une image");
    }
    
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


// Move _uploadImageToCloudinary inside the class
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
    }
    return null;
  } catch (e) {
    if (mounted) {
      CustomDialog.show(
        context,
        "Erreur",
        "Une erreur est survenue lors du téléchargement de l'image: ${e.toString()}",
      );
    }
    return null;
  }
}
}
