import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../widgets/custom_button.dart';
import '../widgets/custom_dialog.dart';
import '../client_home_page.dart';
import '../prestataire_home_page.dart';
import '../widgets/dark_mode_switch.dart';

class Signup2Page extends StatefulWidget {
  const Signup2Page({super.key});

  @override
  _Signup2PageState createState() => _Signup2PageState();
}

class _Signup2PageState extends State<Signup2Page> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  String _role = "client";
  File? _profileImage;
  bool _isLoading = false;

  final String cloudName = "dfk7mskxv";
  final String uploadPreset = "plateforme_service";

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    
    if (pickedFile != null) {
      setState(() => _profileImage = File(pickedFile.path));
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

  Future<void> _saveUserInfo() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser!;
      String? avatarUrl;
      
      if (_profileImage != null) {
        avatarUrl = await _uploadImageToCloudinary(_profileImage!);
        if (avatarUrl == null) {
          throw Exception('Failed to upload image');
        }
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'firstname': _firstNameController.text.trim(),
        'lastname': _lastNameController.text.trim(),
        'role': _role,
        'avatarUrl': avatarUrl,
        'profileCompleted': true,
      });

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => _role == "client" 
              ? const ClientHomePage() 
              : const PrestataireHomePage(),
          transitionsBuilder: (_, animation, __, child) => SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
      );
    } catch (e) {
      CustomDialog.show(context, 'Erreur', 'Échec de la mise à jour du profil: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compléter le profil'),
        actions: const [DarkModeSwitch()],
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: _pickImage,
                      child: CircleAvatar(
                        radius: 50,
                        backgroundColor: Theme.of(context).primaryColor,
                        backgroundImage: _profileImage != null 
                            ? FileImage(_profileImage!) 
                            : null,
                        child: _profileImage == null
                            ? Icon(Icons.add_a_photo, 
                                size: 40, 
                                color: Theme.of(context).scaffoldBackgroundColor)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _firstNameController,
                      decoration: InputDecoration(
                        labelText: 'Prénom',
                        prefixIcon: Icon(Icons.person, 
                            color: Theme.of(context).primaryColor),
                      ),
                      validator: (value) => value!.isEmpty ? 'Champ obligatoire' : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: InputDecoration(
                        labelText: 'Nom',
                        prefixIcon: Icon(Icons.person_outline, 
                            color: Theme.of(context).primaryColor),
                      ),
                      validator: (value) => value!.isEmpty ? 'Champ obligatoire' : null,
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      value: _role,
                      items: const [
                        DropdownMenuItem(value: 'client', child: Text('Client')),
                        DropdownMenuItem(value: 'prestataire', child: Text('Prestataire')),
                      ],
                      onChanged: (value) => setState(() => _role = value!),
                      decoration: InputDecoration(
                        labelText: 'Rôle',
                        prefixIcon: Icon(Icons.work, 
                            color: Theme.of(context).primaryColor),
                      ),
                    ),
                    const SizedBox(height: 30),
                    CustomButton(
                      text: 'Terminer l\'inscription',
                      onPressed: _isLoading ? null : _saveUserInfo,
                      icon: Icons.check_circle_outline,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}