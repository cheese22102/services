import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../front/app_colors.dart';
import '../front/custom_button.dart';
import 'package:go_router/go_router.dart';
import '../utils/cloudinary_service.dart';


// Service Model integrated in the same file
class Service {
  final String id;
  final String name;
  final String imageUrl;
  final Timestamp createdAt;

  Service({
    required this.id,
    required this.name,
    required this.imageUrl, 
    required this.createdAt,
  });

  factory Service.fromMap(String id, Map<String, dynamic> map) {
    return Service(
      id: id,
      name: map['name'] ?? '',
      imageUrl: map['imageUrl'] ?? '', 
      createdAt: map['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'imageUrl': imageUrl,
      'createdAt': createdAt,
    };
  }
}

class ServicesManagementPage extends StatefulWidget {
  const ServicesManagementPage({super.key});

  @override
  State<ServicesManagementPage> createState() => _ServicesManagementPageState();
}

class _ServicesManagementPageState extends State<ServicesManagementPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _picker = ImagePicker();
  File? _selectedImage;
  bool _isUploading = false;
  bool _isImageUploading = false;

  // Remove these lines
  // final String cloudName = "dfk7mskxv";
  // final String uploadPreset = "plateforme_service";

  Future<void> _pickImage() async {
    try {
      setState(() => _isImageUploading = true);
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Erreur lors de la sélection de l'image: ${e.toString()}"),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isImageUploading = false);
    }
  }

  void _addService() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (_selectedImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Veuillez sélectionner une image"),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _isUploading = true);
      
      try {
        // Upload image using CloudinaryService
        final imageUrl = await CloudinaryService.uploadImage(_selectedImage!);
        if (imageUrl == null) throw Exception("Échec du téléchargement de l'image");

        // Removed price parsing

        // Add service to Firestore
        await FirebaseFirestore.instance.collection('services').add({
          'name': _nameController.text.trim(),
          'imageUrl': imageUrl,
          'createdAt': Timestamp.now(),
          // Removed price fields
        });

        _nameController.clear();
        setState(() => _selectedImage = null);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Service ajouté avec succès')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: ${e.toString()}')),
          );
        }
      } finally {
        setState(() => _isUploading = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Gestion des Services',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        backgroundColor: isDarkMode ? AppColors.darkBackground : Colors.white,
        elevation: 2,
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'), // Update navigation to use GoRouter
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: isDarkMode ? AppColors.darkBackground : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ajouter un nouveau service',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Responsive layout for form fields
                      isSmallScreen
                          ? _buildVerticalForm(isDarkMode, primaryColor)
                          : _buildHorizontalForm(isDarkMode, primaryColor),
                      const SizedBox(height: 20),
                      CustomButton(
                        text: 'Ajouter le service',
                        onPressed: _isUploading ? null : _addService,
                        isLoading: _isUploading,
                        height: 50,
                        width: double.infinity,
                        isPrimary: true,
                        borderRadius: 12,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: isDarkMode ? AppColors.darkBackground : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Services existants',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildServicesList(isDarkMode, primaryColor),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // New method for vertical layout (small screens)
  Widget _buildVerticalForm(bool isDarkMode, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name field
        TextFormField(
          controller: _nameController,
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            labelText: 'Nom du service',
            labelStyle: GoogleFonts.poppins(
              color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
            ),
            hintText: 'Entrez le nom du service',
            hintStyle: GoogleFonts.poppins(
              color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: primaryColor,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: isDarkMode ? AppColors.darkInputBackground : AppColors.lightInputBackground,
          ),
          validator: (value) =>
              value?.isEmpty ?? true ? 'Ce champ est requis' : null,
        ),
        const SizedBox(height: 20),
        
        // Image selection
        Center(
          child: Column(
            children: [
              Container(
                width: 200,
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                ),
                child: _isImageUploading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: primaryColor,
                        ),
                      )
                    : _selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          )
                        : Center(
                            child: Icon(
                              Icons.add_photo_alternate,
                              size: 50,
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[400],
                            ),
                          ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: 200, // Fixed width to prevent overflow
                child: CustomButton(
                  text: 'Image',
                  icon: const Icon(Icons.image, size: 16),
                  onPressed: _isImageUploading ? null : _pickImage,
                  height: 40,
                  isPrimary: true,
                  borderRadius: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // New method for horizontal layout (larger screens)
  Widget _buildHorizontalForm(bool isDarkMode, Color primaryColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name field
        Expanded(
          flex: 3,
          child: TextFormField(
            controller: _nameController,
            style: GoogleFonts.poppins(
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              labelText: 'Nom du service',
              labelStyle: GoogleFonts.poppins(
                color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
              ),
              hintText: 'Entrez le nom du service',
              hintStyle: GoogleFonts.poppins(
                color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: primaryColor,
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: isDarkMode ? AppColors.darkInputBackground : AppColors.lightInputBackground,
            ),
            validator: (value) =>
                value?.isEmpty ?? true ? 'Ce champ est requis' : null,
          ),
        ),
        const SizedBox(width: 20),
        
        // Image selection
        Expanded(
          flex: 2,
          child: Column(
            children: [
              Container(
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: isDarkMode ? Colors.grey[800] : Colors.grey[100],
                ),
                child: _isImageUploading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: primaryColor,
                        ),
                      )
                    : _selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          )
                        : Center(
                            child: Icon(
                              Icons.add_photo_alternate,
                              size: 50,
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[400],
                            ),
                          ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 40,
                child: CustomButton(
                  text: 'Sélectionner',
                  icon: const Icon(Icons.image, size: 16),
                  onPressed: _isImageUploading ? null : _pickImage,
                  isPrimary: true,
                  borderRadius: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // New method for services list
  Widget _buildServicesList(bool isDarkMode, Color primaryColor) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('services')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Une erreur est survenue',
              style: GoogleFonts.poppins(
                color: Colors.red[700],
                fontSize: 16,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: primaryColor,
            ),
          );
        }

        final services = snapshot.data?.docs.map((doc) => Service.fromMap(
              doc.id,
              doc.data() as Map<String, dynamic>,
            )).toList() ??
            [];

        if (services.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Aucun service disponible',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: services.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final service = services[index];
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: isDarkMode ? Colors.grey[850] : Colors.white,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: service.imageUrl.isEmpty
                      ? Container(
                          width: 60,
                          height: 60,
                          color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
                          child: Icon(
                            Icons.image_not_supported,
                            color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          ),
                        )
                      : Image.network(
                          service.imageUrl,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.error),
                        ),
                ),
                title: Text(
                  service.name,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      color: primaryColor,
                      onPressed: () => _editService(service),
                      tooltip: 'Modifier',
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      color: Colors.red[400],
                      onPressed: () => _deleteService(service.id),
                      tooltip: 'Supprimer',
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Update the edit dialog to be responsive
  void _editService(Service service) {
    _nameController.text = service.name;
    setState(() => _selectedImage = null); // Reset selected image

    showDialog(
      context: context,
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;
        
        return AlertDialog(
          backgroundColor: isDarkMode ? AppColors.darkBackground : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Modifier le service',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  style: GoogleFonts.poppins(
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Nom du service',
                    labelStyle: GoogleFonts.poppins(
                      color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: primaryColor,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: isDarkMode ? AppColors.darkInputBackground : AppColors.lightInputBackground,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 100,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _selectedImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  _selectedImage!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : service.imageUrl.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      service.imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const Icon(Icons.error),
                                    ),
                                  )
                                : Center(
                                    child: Icon(
                                      Icons.image,
                                      color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.add_photo_alternate),
                      color: primaryColor,
                      tooltip: 'Changer l\'image',
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _nameController.clear();
                Navigator.of(context).pop();
              },
              child: Text(
                'Annuler',
                style: GoogleFonts.poppins(
                  color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (_nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Le nom du service est requis'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                setState(() => _isUploading = true);
                Navigator.of(context).pop();

                try {
                  final updatedData = <String, dynamic>{
                    'name': _nameController.text.trim(),
                    'updatedAt': Timestamp.now(),
                  };

                  // Use CloudinaryService instead of _uploadImageToCloudinary
                  if (_selectedImage != null) {
                    final imageUrl = await CloudinaryService.uploadImage(_selectedImage!);
                    if (imageUrl == null) throw Exception("Échec du téléchargement de l'image");
                    updatedData['imageUrl'] = imageUrl;
                  }

                  await FirebaseFirestore.instance
                      .collection('services')
                      .doc(service.id)
                      .update(updatedData);

                  _nameController.clear();
                  setState(() => _selectedImage = null);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Service mis à jour avec succès')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur: ${e.toString()}')),
                    );
                  }
                } finally {
                  setState(() => _isUploading = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Enregistrer',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Update the delete dialog to match the style
  void _deleteService(String serviceId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Voulez-vous vraiment supprimer ce service ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await FirebaseFirestore.instance
                    .collection('services')
                    .doc(serviceId)
                    .delete();
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Service supprimé avec succès')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: ${e.toString()}')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}