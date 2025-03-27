import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../config/constants.dart';  // Add this import

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

  Future<String?> _uploadImageToCloudinary(File imageFile) async {
    final url = "https://api.cloudinary.com/v1_1/${AppConstants.cloudName}/image/upload";
    try {
      var request = http.MultipartRequest('POST', Uri.parse(url));
      request.fields['upload_preset'] = AppConstants.uploadPreset;
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
        // Upload image
        final imageUrl = await _uploadImageToCloudinary(_selectedImage!);
        if (imageUrl == null) throw Exception("Échec du téléchargement de l'image");

        // Add service to Firestore
        await FirebaseFirestore.instance.collection('services').add({
          'name': _nameController.text.trim(),
          'imageUrl': imageUrl,
          'createdAt': Timestamp.now(),
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

  void _editService(Service service) {
    _nameController.text = service.name;
    setState(() => _selectedImage = null); // Reset selected image

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier le service'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nom du service'),
                validator: (value) =>
                    value?.isEmpty ?? true ? 'Ce champ est requis' : null,
              ),
              const SizedBox(height: 16),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _isImageUploading
                    ? const Center(child: CircularProgressIndicator())
                    : _selectedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _selectedImage!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              service.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.error),
                            ),
                          ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _isImageUploading ? null : _pickImage,
                child: const Text('Changer l\'image'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _nameController.clear();
              setState(() => _selectedImage = null);
            },
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState?.validate() ?? false) {
                setState(() => _isUploading = true);
                try {
                  String imageUrl = service.imageUrl;
                  if (_selectedImage != null) {
                    final newImageUrl = await _uploadImageToCloudinary(_selectedImage!);
                    if (newImageUrl == null) throw Exception("Échec du téléchargement de l'image");
                    imageUrl = newImageUrl;
                  }

                  await FirebaseFirestore.instance
                      .collection('services')
                      .doc(service.id)
                      .update({
                    'name': _nameController.text.trim(),
                    'imageUrl': imageUrl,
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    _nameController.clear();
                    setState(() => _selectedImage = null);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Service modifié avec succès')),
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
            },
            child: _isUploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white),
                  )
                : const Text('Modifier'),
          ),
        ],
      ),
    );
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestion des Services')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nom du service',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'Ce champ est requis' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _isImageUploading
                            ? const Center(child: CircularProgressIndicator())
                            : _selectedImage != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(
                                      _selectedImage!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : const Icon(Icons.add_photo_alternate, size: 40),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _isImageUploading ? null : _pickImage,
                        child: const Text('Choisir une image'),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isUploading ? null : _addService,
                    child: _isUploading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Ajouter'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('services')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Une erreur est survenue'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final services = snapshot.data?.docs.map((doc) => Service.fromMap(
                      doc.id,
                      doc.data() as Map<String, dynamic>,
                    )).toList() ?? [];

                return ListView.builder(
                  itemCount: services.length,
                  itemBuilder: (context, index) {
                    final service = services[index];
                    // Update the ListTile to show an icon if imageUrl is empty
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: service.imageUrl.isEmpty
                            ? const Icon(Icons.image_not_supported)
                            : Image.network(
                                service.imageUrl,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const Icon(Icons.error),
                              ),
                      ),
                      title: Text(service.name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _editService(service),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _deleteService(service.id),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}