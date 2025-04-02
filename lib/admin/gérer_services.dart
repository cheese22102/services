import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../config/constants.dart';

// Service Model integrated in the same file
class Service {
  final String id;
  final String name;
  final String imageUrl;
  final Timestamp createdAt;
  final double minPrice;
  final double maxPrice;

  Service({
    required this.id,
    required this.name,
    required this.imageUrl, 
    required this.createdAt,
    this.minPrice = 0.0, // Default value
    this.maxPrice = 0.0, // Default value
  });

  factory Service.fromMap(String id, Map<String, dynamic> map) {
    return Service(
      id: id,
      name: map['name'] ?? '',
      imageUrl: map['imageUrl'] ?? '', 
      createdAt: map['createdAt'] ?? Timestamp.now(),
      minPrice: (map['minPrice'] ?? 0.0).toDouble(),
      maxPrice: (map['maxPrice'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'imageUrl': imageUrl,
      'createdAt': createdAt,
      'minPrice': minPrice,
      'maxPrice': maxPrice,
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
  final _minPriceController = TextEditingController(); // New controller
  final _maxPriceController = TextEditingController(); // New controller
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

        // Parse price values
        final minPrice = double.tryParse(_minPriceController.text) ?? 0.0;
        final maxPrice = double.tryParse(_maxPriceController.text) ?? 0.0;

        // Add service to Firestore
        await FirebaseFirestore.instance.collection('services').add({
          'name': _nameController.text.trim(),
          'imageUrl': imageUrl,
          'createdAt': Timestamp.now(),
          'minPrice': minPrice,
          'maxPrice': maxPrice,
        });

        _nameController.clear();
        _minPriceController.clear();
        _maxPriceController.clear();
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
    _minPriceController.text = service.minPrice.toString();
    _maxPriceController.text = service.maxPrice.toString();
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
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minPriceController,
                      decoration: const InputDecoration(
                        labelText: 'Prix minimum (DT)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Requis';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Nombre invalide';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _maxPriceController,
                      decoration: const InputDecoration(
                        labelText: 'Prix maximum (DT)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Requis';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Nombre invalide';
                        }
                        final min = double.tryParse(_minPriceController.text) ?? 0;
                        final max = double.tryParse(value) ?? 0;
                        if (max < min) {
                          return 'Doit être ≥ min';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
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
              _minPriceController.clear();
              _maxPriceController.clear();
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

                  // Parse price values
                  final minPrice = double.tryParse(_minPriceController.text) ?? 0.0;
                  final maxPrice = double.tryParse(_maxPriceController.text) ?? 0.0;

                  await FirebaseFirestore.instance
                      .collection('services')
                      .doc(service.id)
                      .update({
                    'name': _nameController.text.trim(),
                    'imageUrl': imageUrl,
                    'minPrice': minPrice,
                    'maxPrice': maxPrice,
                  });

                  if (mounted) {
                    Navigator.pop(context);
                    _nameController.clear();
                    _minPriceController.clear();
                    _maxPriceController.clear();
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
      appBar: AppBar(
        title: const Text('Gestion des Services'),
        elevation: 2,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ajouter un nouveau service',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TextFormField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  labelText: 'Nom du service',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey[50],
                                ),
                                validator: (value) =>
                                    value?.isEmpty ?? true ? 'Ce champ est requis' : null,
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Fourchette de prix (DT/heure)',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _minPriceController,
                                      decoration: InputDecoration(
                                        labelText: 'Prix minimum',
                                        prefixText: 'DT ',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey[50],
                                      ),
                                      keyboardType: TextInputType.number,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Prix requis';
                                        }
                                        final number = double.tryParse(value);
                                        if (number == null) {
                                          return 'Prix invalide';
                                        }
                                        if (number < 0) {
                                          return 'Prix doit être positif';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _maxPriceController,
                                      decoration: InputDecoration(
                                        labelText: 'Prix maximum',
                                        prefixText: 'DT ',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        filled: true,
                                        fillColor: Colors.grey[50],
                                      ),
                                      keyboardType: TextInputType.number,
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Prix requis';
                                        }
                                        final number = double.tryParse(value);
                                        if (number == null) {
                                          return 'Prix invalide';
                                        }
                                        if (number < 0) {
                                          return 'Prix doit être positif';
                                        }
                                        final minPrice = double.tryParse(_minPriceController.text) ?? 0;
                                        if (number < minPrice) {
                                          return 'Doit être ≥ prix minimum';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),
                        Column(
                          children: [
                            Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.grey[50],
                              ),
                              child: _isImageUploading
                                  ? const Center(child: CircularProgressIndicator())
                                  : _selectedImage != null
                                      ? ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.file(
                                            _selectedImage!,
                                            fit: BoxFit.cover,
                                          ),
                                        )
                                      : Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: const [
                                            Icon(
                                              Icons.add_photo_alternate,
                                              size: 50,
                                              color: Colors.grey,
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'Ajouter une image',
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                            ),
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _isImageUploading ? null : _pickImage,
                              icon: const Icon(Icons.photo_camera),
                              label: const Text('Choisir une image'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _isUploading ? null : _addService,
                        icon: const Icon(Icons.add),
                        label: _isUploading
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Ajout en cours...'),
                                ],
                              )
                            : const Text('Ajouter le service'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Services existants',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('services')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Une erreur est survenue',
                            style: TextStyle(color: Colors.red[700]),
                          ),
                        );
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final services = snapshot.data?.docs.map((doc) => Service.fromMap(
                            doc.id,
                            doc.data() as Map<String, dynamic>,
                          )).toList() ??
                          [];

                      if (services.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(20),
                            child: Text(
                              'Aucun service disponible',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: services.length,
                        separatorBuilder: (context, index) => const Divider(),
                        itemBuilder: (context, index) {
                          final service = services[index];
                          return Card(
                            elevation: 2,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(12),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: service.imageUrl.isEmpty
                                    ? Container(
                                        width: 60,
                                        height: 60,
                                        color: Colors.grey[200],
                                        child: const Icon(
                                          Icons.image_not_supported,
                                          color: Colors.grey,
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                'Prix: ${service.minPrice} - ${service.maxPrice} DT/heure',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    color: Colors.blue,
                                    onPressed: () => _editService(service),
                                    tooltip: 'Modifier',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    color: Colors.red,
                                    onPressed: () => _deleteService(service.id),
                                    tooltip: 'Supprimer',
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}