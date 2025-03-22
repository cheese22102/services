import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

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
  List<File> _images = [];
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

  // Méthode pour sélectionner plusieurs images
  Future<void> _pickImages() async {
    try {
      setState(() => _isImageUploading = true);
      final pickedFiles = await _picker.pickMultiImage(
        imageQuality: 70, // Compression pour optimiser le chargement
        maxWidth: 1200,
        maxHeight: 1200,
      );
      
      if (pickedFiles.isNotEmpty) {
        // Limiter le nombre d'images à 5 maximum
        if (_images.length + pickedFiles.length > 5) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Maximum 5 images autorisées"),
              backgroundColor: Colors.orange,
            ),
          );
          // Ajouter seulement les images jusqu'à atteindre 5 au total
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de la sélection des images: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isImageUploading = false);
    }
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

  // Validation des champs
  bool _validateFields() {
    bool isValid = true;
    
    // Réinitialiser les erreurs
    setState(() {
      _titleError = null;
      _descriptionError = null;
      _priceError = null;
    });
    
    // Valider le titre
    if (_titleController.text.trim().isEmpty) {
      setState(() => _titleError = "Le titre est obligatoire");
      isValid = false;
    } else if (_titleController.text.length < 3) {
      setState(() => _titleError = "Le titre doit contenir au moins 3 caractères");
      isValid = false;
    }
    
    // Valider la description
    if (_descriptionController.text.trim().isEmpty) {
      setState(() => _descriptionError = "La description est obligatoire");
      isValid = false;
    } else if (_descriptionController.text.length < 10) {
      setState(() => _descriptionError = "La description doit contenir au moins 10 caractères");
      isValid = false;
    }
    
    // Valider le prix
    if (_priceController.text.trim().isEmpty) {
      setState(() => _priceError = "Le prix est obligatoire");
      isValid = false;
    } else {
      try {
        double price = double.parse(_priceController.text);
        if (price <= 0) {
          setState(() => _priceError = "Le prix doit être supérieur à 0");
          isValid = false;
        }
      } catch (e) {
        setState(() => _priceError = "Veuillez entrer un prix valide");
        isValid = false;
      }
    }
    
    // Valider l'état du produit
    if (_etatProduit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez sélectionner l'état du produit"),
          backgroundColor: Colors.red,
        ),
      );
      isValid = false;
    }
    
    // Valider les images
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Veuillez ajouter au moins une image"),
          backgroundColor: Colors.red,
        ),
      );
      isValid = false;
    }
    
    return isValid;
  }

  // Soumission du post
  Future<void> _submitPost() async {
    if (!_validateFields() || _isUploading) {
      return;
    }
    
    setState(() => _isUploading = true);
    
    try {
      // Afficher un dialogue de progression
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("Publication en cours..."),
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

      // Afficher un message de succès
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Post soumis avec succès ! Il est maintenant en attente de validation. Vous serez notifié."),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),  // Increased duration to allow reading
        ),
      );

      // Retourner à la page précédente après un court délai
      Future.delayed(const Duration(seconds: 2), () {  // Increased delay
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/marketplace',
          (route) => false,
        );
      });
    } catch (e) {
      // Fermer le dialogue de progression en cas d'erreur
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur: ${e.toString()}"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/marketplace',
          (route) => false,
        );
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ajouter un Post'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          elevation: 0,
          centerTitle: true,
        ),
        body: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).colorScheme.primary.withOpacity(0.05),
                    Theme.of(context).colorScheme.background,
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 100),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Product Information Card
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)
                          ),
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Informations du produit",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                TextFormField(
                                  controller: _titleController,
                                  decoration: InputDecoration(
                                    labelText: 'Titre',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    prefixIcon: Icon(Icons.title, 
                                      color: Theme.of(context).colorScheme.primary
                                    ),
                                    errorText: _titleError,
                                    filled: true,
                                    fillColor: Theme.of(context).colorScheme.surface,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _descriptionController,
                                  decoration: InputDecoration(
                                    labelText: 'Description',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    prefixIcon: Icon(Icons.description,
                                      color: Theme.of(context).colorScheme.primary
                                    ),
                                    errorText: _descriptionError,
                                    filled: true,
                                    fillColor: Theme.of(context).colorScheme.surface,
                                  ),
                                  maxLines: 4,
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _priceController,
                                  decoration: InputDecoration(
                                    labelText: 'Prix (TND)',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    prefixIcon: Icon(Icons.attach_money,
                                      color: Theme.of(context).colorScheme.primary
                                    ),
                                    suffixText: 'TND',
                                    errorText: _priceError,
                                    filled: true,
                                    fillColor: Theme.of(context).colorScheme.surface,
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      // Product State Section
                      Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)
                        ),
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "État du produit",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildEtatOption(
                                    "Neuf",
                                    Icons.new_releases,
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 16),
                                  _buildEtatOption(
                                    "Occasion",
                                    Icons.history,
                                    Theme.of(context).colorScheme.secondary,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Section images
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Images du produit",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "${_images.length}/5 images",
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _images.isEmpty
                                ? Center(
                                    child: Column(
                                      children: [
                                        Icon(
                                          Icons.image_outlined,
                                          size: 48,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          "Aucune image ajoutée",
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        ElevatedButton.icon(
                                          onPressed: _pickImages,
                                          icon: const Icon(Icons.add_photo_alternate),
                                          label: const Text("Ajouter des images"),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Theme.of(context).colorScheme.primary,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 24,
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: List.generate(_images.length, (index) {
                                      return Stack(
                                        children: [
                                          Container(
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(12),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.1),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(12),
                                              child: Image.file(
                                                _images[index],
                                                width: 120,
                                                height: 120,
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 8,
                                            right: 8,
                                            child: GestureDetector(
                                              onTap: () => _removeImage(index),
                                              child: Container(
                                                padding: const EdgeInsets.all(4),
                                                decoration: BoxDecoration(
                                                  color: Colors.red,
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withOpacity(0.2),
                                                      blurRadius: 2,
                                                      offset: const Offset(0, 1),
                                                    ),
                                                  ],
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }),
                                  ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Boutons fixes en bas
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).colorScheme.shadow.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isImageUploading ? null : _pickImages,
                      icon: _isImageUploading 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.image),
                      label: Text(_isImageUploading ? "Chargement..." : "Ajouter des images"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (_images.isNotEmpty && !_isUploading) ? _submitPost : null,
                      icon: _isUploading 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.upload),
                      label: Text(_isUploading ? "Publication..." : "Publier le Post"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildEtatOption(String etat, IconData icon, Color color) {
    final isSelected = _etatProduit == etat;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _etatProduit = etat;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 140,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.grey.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 32,
                color: isSelected ? color : Colors.grey,
              ),
              const SizedBox(height: 8),
              Text(
                etat,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? color : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
