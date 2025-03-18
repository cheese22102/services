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
  late String _title;
  late String _description;
  late double  _price;
  late List<String> _imageUrls;
  final ImagePicker _picker = ImagePicker();

  // Cloudinary credentials (replace with your actual credentials)
  final String cloudName = "dfk7mskxv";
  final String uploadPreset = "plateforme_service";

  @override
  void initState() {
    super.initState();
    _title = widget.post['title'] ?? "";
    _description = widget.post['description'] ?? "";
    _price = widget.post['price'] ?? "";
    _imageUrls = List<String>.from(widget.post['images'] ?? []);
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
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      try {
        await FirebaseFirestore.instance
            .collection('marketplace')
            .doc(widget.post.id)
            .update({
          'title': _title,
          'description': _description,
          'price': _price,
          'images': _imageUrls,
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Post updated successfully")),
        );
        Navigator.pop(context, {
          'title': _title,
          'description': _description,
          'price': _price,
          'images': _imageUrls,
          'userId': widget.post['userId'],
        });
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error updating post: ${e.toString()}")),
        );
      }
    }
  }

  void _removeImage(int index) {
    if (!mounted) return;
    setState(() {
      _imageUrls.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modify Post'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Title field
              TextFormField(
                initialValue: _title,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Title is required' : null,
                onSaved: (value) => _title = value!,
              ),
              const SizedBox(height: 16),
              // Description field
              TextFormField(
                initialValue: _description,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                validator: (value) => value == null || value.isEmpty ? 'Description is required' : null,
                onSaved: (value) => _description = value!,
              ),
              const SizedBox(height: 16),
               // Price field
              TextFormField(
                initialValue: _price.toString(), // <-- Converti en String pour l'affichage
                decoration: const InputDecoration(
                  labelText: 'Price',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.numberWithOptions(decimal: true), // <-- Permet les décimaux
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Price is required';
                  }
                  final price = double.tryParse(value);
                  if (price == null || price <= 0) {
                    return 'Please enter a valid price';
                  }
                  return null;
                },
                onSaved: (value) => _price = double.parse(value!), // <-- Converti en double
              ),
              const SizedBox(height: 16),
              const Text(
                "Images:",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _imageUrls.isEmpty
                  ? const Text("No images available.")
                  : SizedBox(
                      height: 150,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _imageUrls.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              Container(
                                margin: const EdgeInsets.symmetric(horizontal: 8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    _imageUrls[index],
                                    height: 150,
                                    width: 150,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _removeImage(index),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _pickAndUploadImage,
                icon: const Icon(Icons.add_a_photo),
                label: const Text("Add Image"),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _updatePost,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text("Save Changes"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
