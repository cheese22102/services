import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AddPostPage extends StatefulWidget {
  const AddPostPage({super.key});

  @override
  State<AddPostPage> createState() => _AddPostPageState();
}

class _AddPostPageState extends State<AddPostPage> {
  final _formKey = GlobalKey<FormState>();
  String _title = '';
  String _description = '';
  String _price = '';
  List<File> _images = [];
  final _picker = ImagePicker();

  final String cloudName = "dfk7mskxv";
  final String uploadPreset = "plateforme_service";

  Future<void> _pickImages() async {
    final pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _images = pickedFiles.map((file) => File(file.path)).toList();
      });
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
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<void> _submitPost() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      if (_images.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Veuillez ajouter au moins une image.")),
        );
        return;
      }

      try {
        List<String> imageUrls = [];
        for (var image in _images) {
          String? url = await _uploadImageToCloudinary(image);
          if (url != null) {
            imageUrls.add(url);
          }
        }

        if (imageUrls.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Erreur lors du téléchargement des images.")),
          );
          return;
        }

        User? user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Utilisateur non connecté.")),
          );
          return;
        }

        Map<String, dynamic> postData = {
          'title': _title,
          'description': _description,
          'price': _price,
          'userId': user.uid,
          'images': imageUrls,
        };

        await FirebaseFirestore.instance.collection('marketplace').add(postData);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Post ajouté avec succès !")),
        );

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur: ${e.toString()}")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter un Post'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Affichage des images en carrousel horizontal
                      if (_images.isNotEmpty)
                        SizedBox(
                          height: 120,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: _images.map((image) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(image, width: 120, height: 120, fit: BoxFit.cover),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Card(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              TextFormField(
                                decoration: const InputDecoration(
                                  labelText: 'Titre',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) => value!.isEmpty ? 'Le titre est requis' : null,
                                onSaved: (value) => _title = value!,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                decoration: const InputDecoration(
                                  labelText: 'Description',
                                  border: OutlineInputBorder(),
                                ),
                                maxLines: 4,
                                validator: (value) => value!.isEmpty ? 'La description est requise' : null,
                                onSaved: (value) => _description = value!,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                decoration: const InputDecoration(
                                  labelText: 'Prix',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) => value!.isEmpty ? 'Le prix est requis' : null,
                                onSaved: (value) => _price = value!,
                              ),
                              const SizedBox(height: 32),
                              ElevatedButton(
                                onPressed: _submitPost,
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Publier le Post'),
                              ),
                            ],
                          ),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickImages,
        backgroundColor: Colors.green,
        label: const Text("Ajouter des images"),
        icon: const Icon(Icons.image),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
