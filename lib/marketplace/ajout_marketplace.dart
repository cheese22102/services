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
  String _title = '';
  String _description = '';
  String _price = '';
  String? _etatProduit; // "Neuf" ou "Occasion"
  List<File> _images = [];
  final _picker = ImagePicker();
  bool _isUploading = false;

  final String cloudName = "dfk7mskxv";
  final String uploadPreset = "plateforme_service";

  // Méthode pour sélectionner plusieurs images
  Future<void> _pickImages() async {
    final pickedFiles = await _picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _images = pickedFiles.map((file) => File(file.path)).toList();
      });
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
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  // Soumission du post
  Future<void> _submitPost() async {
    if (_formKey.currentState!.validate() &&
        _etatProduit != null &&
        _images.isNotEmpty &&
        !_isUploading) {
      _formKey.currentState!.save();
      setState(() => _isUploading = true);
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
            const SnackBar(
                content: Text("Erreur lors du téléchargement des images.")),
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
'price': double.tryParse(_price) ?? 0.0,
          'etat': _etatProduit,
          'userId': user.uid,
          'images': imageUrls,
          'timestamp': FieldValue.serverTimestamp(),
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
      } finally {
        setState(() => _isUploading = false);
      }
    } else if (_etatProduit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Veuillez sélectionner l'état du produit.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter un Post'),
        backgroundColor: Colors.green,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 100), // espace pour les boutons fixes
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Card des informations du post
                      Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
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
                                validator: (value) => value!.isEmpty
                                    ? 'Le titre est requis'
                                    : null,
                                onSaved: (value) => _title = value!,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                decoration: const InputDecoration(
                                  labelText: 'Description',
                                  border: OutlineInputBorder(),
                                ),
                                maxLines: 4,
                                validator: (value) => value!.isEmpty
                                    ? 'La description est requise'
                                    : null,
                                onSaved: (value) => _description = value!,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                decoration: const InputDecoration(
                                  labelText: 'Prix (TND)',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) => value!.isEmpty
                                    ? 'Le prix est requis'
                                    : null,
                                onSaved: (value) => _price = value!,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Sélection de l'état du produit avec icônes et descriptions
                      const Text("État du produit", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      // Remplacement du Row par un Wrap pour éviter l'overflow
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 24,
                        runSpacing: 8,
                        children: [
                          _buildEtatOption("Neuf", Icons.new_releases, Colors.green),
                          _buildEtatOption("Occasion", Icons.handshake, Colors.orange),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Section Images du produit
                      const Text("Images du produit", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      _images.isEmpty
                          ? const Center(child: Text("Aucune image ajoutée", style: TextStyle(color: Colors.red)))
                          : Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: List.generate(_images.length, (index) {
                                return Stack(
                                  alignment: Alignment.topRight,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.file(
                                        _images[index],
                                        width: 100,
                                        height: 100,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    // Bouton de suppression
                                    GestureDetector(
                                      onTap: () => _removeImage(index),
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.red,
                                        ),
                                        padding: const EdgeInsets.all(4),
                                        child: const Icon(Icons.close, size: 16, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                );
                              }),
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
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickImages,
                      icon: const Icon(Icons.image),
                      label: const Text("Ajouter des images"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: (_images.isNotEmpty && !_isUploading)
                          ? _submitPost
                          : null,
                      icon: const Icon(Icons.upload),
                      label: const Text("Publier le Post"),
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
    );
  }

  Widget _buildEtatOption(String etat, IconData icon, Color color) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _etatProduit = etat;
        });
      },
      child: Column(
        children: [
          Icon(
            icon,
            size: 48,
            color: _etatProduit == etat ? color : Colors.grey,
          ),
          const SizedBox(height: 4),
          Text(
            etat,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _etatProduit == etat ? color : Colors.grey,
            ),
          ),
          // Description sous l'icône
          Text(
            etat == "Neuf"
                ? "Produit neuf, jamais utilisé"
                : "Produit d'occasion, peut présenter des signes d'utilisation",
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
