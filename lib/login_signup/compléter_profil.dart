import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';  // Add this import
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../widgets/custom_button.dart';
import '../widgets/custom_dialog.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/auth_page_template.dart';


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

      if (!mounted) return;
      
      // Updated navigation using context.go
      context.go(_role == "client" ? '/clientHome' : '/prestataireHome');
      
    } catch (e) {
      CustomDialog.show(context, 'Erreur', 'Échec de la mise à jour du profil: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AuthPageTemplate(
      title: "Complétez votre profil",
      subtitle: "Ajoutez vos informations pour continuer",
      imagePath: "assets/images/profile_setup.png", // Add this image to assets
      showBackButton: false,
      children: [
        // Profile Image Picker
        Center(
          child: Stack(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[800] : const Color(0xFFF5F5F5),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                      width: 2,
                    ),
                    image: _profileImage != null
                        ? DecorationImage(
                            image: FileImage(_profileImage!),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _profileImage == null
                      ? Icon(
                          Icons.add_a_photo,
                          size: 40,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        )
                      : null,
                ),
              ),
              if (_profileImage != null)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.edit,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        Form(
          key: _formKey,
          child: Column(
            children: [
              // First Name Field
              LabeledTextField(
                controller: _firstNameController,
                label: 'Prénom',
                icon: Icons.person,
                hint: 'Entrez votre prénom',
                validator: (value) => 
                    value?.isEmpty ?? true ? 'Le prénom est requis' : null,
              ),
              const SizedBox(height: 20),

              // Last Name Field
              LabeledTextField(
                controller: _lastNameController,
                label: 'Nom',
                icon: Icons.person_outline,
                hint: 'Entrez votre nom',
                validator: (value) => 
                    value?.isEmpty ?? true ? 'Le nom est requis' : null,
              ),
              const SizedBox(height: 20),

              // Role Selection
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Type de compte',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.work_outline,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _role,
                              isExpanded: true,
                              dropdownColor: isDark ? Colors.grey[900] : Colors.white,
                              items: [
                                DropdownMenuItem(
                                  value: 'client',
                                  child: Text('Client'),
                                ),
                                DropdownMenuItem(
                                  value: 'prestataire',
                                  child: Text('Prestataire de services'),
                                ),
                              ],
                              onChanged: (value) => setState(() => _role = value!),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Complete Registration Button
              CustomButton(
                text: 'Terminer l\'inscription',
                onPressed: _isLoading ? null : _saveUserInfo,
                isLoading: _isLoading,
              ),

              const SizedBox(height: 24),
              
              // Information note
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.blue[900] : Colors.blue[50])!,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue[300]!,
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.blue[700],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Vous pourrez modifier ces informations plus tard dans les paramètres de votre profil.',
                        style: TextStyle(
                          color: isDark ? Colors.blue[100] : Colors.blue[900],
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}