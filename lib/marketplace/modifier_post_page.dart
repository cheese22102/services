import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ModifyPostPage extends StatefulWidget {
final DocumentSnapshot post;

const ModifyPostPage({super.key, required this.post});

  @override
  State<ModifyPostPage> createState() => _ModifyPostPageState();
}

class _ModifyPostPageState extends State<ModifyPostPage> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  late String _title;
  late String _description;
  late double _price;
  String? _etatProduit;
  List<String> _imageUrls = [];
  bool _isUploading = false;

  // Add Cloudinary credentials
  final String cloudName = "dfk7mskxv";
  final String uploadPreset = "plateforme_service";

  @override
  void initState() {
    super.initState();
    final data = widget.post.data() as Map<String, dynamic>;
    _title = data['title'];
    _description = data['description'];
    _price = data['price'].toDouble();
    _etatProduit = data['etat'];
    _imageUrls = List<String>.from(data['images'] ?? []);
  }

  // Add the build method
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier le post'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                initialValue: _title,
                decoration: const InputDecoration(labelText: 'Titre'),
                validator: (value) => value?.isEmpty ?? true ? 'Ce champ est requis' : null,
                onSaved: (value) => _title = value!,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _description,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 3,
                validator: (value) => value?.isEmpty ?? true ? 'Ce champ est requis' : null,
                onSaved: (value) => _description = value!,
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _price.toString(),
                decoration: const InputDecoration(labelText: 'Prix'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Ce champ est requis';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Veuillez entrer un nombre valide';
                  }
                  return null;
                },
                onSaved: (value) => _price = double.parse(value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _etatProduit,
                decoration: const InputDecoration(labelText: 'État du produit'),
                items: const [
                  DropdownMenuItem(value: 'Neuf', child: Text('Neuf')),
                  DropdownMenuItem(value: 'Occasion', child: Text('Occasion')),
                ],
                onChanged: (value) => setState(() => _etatProduit = value),
                validator: (value) => value == null ? 'Ce champ est requis' : null,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._imageUrls.map((url) => Stack(
                    children: [
                      Image.network(url, width: 100, height: 100, fit: BoxFit.cover),
                      Positioned(
                        right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => setState(() => _imageUrls.remove(url)),
                        ),
                      ),
                    ],
                  )).toList(),
                  if (_imageUrls.length < 5)
                    IconButton(
                      onPressed: _pickAndUploadImage,
                      icon: const Icon(Icons.add_photo_alternate),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isUploading ? null : () {
                  if (_formKey.currentState?.validate() ?? false) {
                    _formKey.currentState?.save();
                    _updatePost();
                  }
                },
                child: _isUploading
                    ? const CircularProgressIndicator()
                    : const Text('Modifier le post'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      File imageFile = File(pickedFile.path);
      String? url = await _uploadImageToCloudinary(imageFile);
      if (url != null) {
        if (!mounted) return;
        setState(() {
          _imageUrls.add(url);
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error uploading image")),
        );
      }
    }
  }

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
        print("Upload failed. Status code: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      print("Error uploading image: $e");
      return null;
    }
  }

  Future<void> _updatePost() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isUploading = true);
      try {
        await widget.post.reference.update({
          'title': _title,
          'description': _description,
          'price': _price,
          'images': _imageUrls,
          'etatProduit': _etatProduit,
          'isValidated': false,  // Reset validation status
          'lastModified': FieldValue.serverTimestamp(),  // Add modification timestamp
        });

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Post modifié avec succès et en attente de validation'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } finally {
        setState(() => _isUploading = false);
      }
    }
  }
}
