import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_fonts/google_fonts.dart';
import 'front/app_colors.dart';

class ProfileEditPage extends StatefulWidget {
  final String? providerId;
  final Map<String, dynamic>? providerData;
  final Map<String, dynamic>? userData;

  const ProfileEditPage({
    super.key, 
    this.providerId,
    this.providerData,
    this.userData,
  });

  @override
  _ProfileEditPageState createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _ageController = TextEditingController();
  String _selectedGender = 'homme';
  
  bool _isLoading = false;
  File? _newProfileImage;
  String? _currentAvatarUrl;
  final String cloudName = "dfk7mskxv";
  final String uploadPreset = "plateforme_service";

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      // If userData is provided through widget, use it
      if (widget.userData != null) {
        setState(() {
          _firstNameController.text = widget.userData?['firstname'] ?? '';
          _lastNameController.text = widget.userData?['lastname'] ?? '';
          _phoneController.text = widget.userData?['phone'] ?? '';
          _ageController.text = widget.userData?['age']?.toString() ?? '';
          _selectedGender = widget.userData?['gender'] ?? 'homme';
          _currentAvatarUrl = widget.userData?['avatarUrl'];
        });
      } else {
        // Otherwise load from Firestore
        final userData = await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .get();

        if (userData.exists) {
          setState(() {
            _firstNameController.text = userData.data()?['firstname'] ?? '';
            _lastNameController.text = userData.data()?['lastname'] ?? '';
            _phoneController.text = userData.data()?['phone'] ?? '';
            _ageController.text = userData.data()?['age']?.toString() ?? '';
            _selectedGender = userData.data()?['gender'] ?? 'homme';
            _currentAvatarUrl = userData.data()?['avatarUrl'];
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de chargement: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    
    if (pickedFile != null) {
      setState(() => _newProfileImage = File(pickedFile.path));
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
      }
    } catch (e) {
      print('Upload error: $e');
    }
    return null;
  }

  Future<void> _deleteAccount() async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le compte'),
        content: const Text(
          'Cette action est irréversible. Tous vos posts et données seront supprimés. Voulez-vous continuer ?'
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => context.pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    ) ?? false;

    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final uid = user.uid;
  
      // Supprimer les posts de l'utilisateur
      final posts = await FirebaseFirestore.instance
          .collection('marketplace')
          .where('userId', isEqualTo: uid)
          .get();
      
      for (var doc in posts.docs) {
        await doc.reference.delete();
      }
  
      // Supprimer le document utilisateur
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .delete();
  
      // Unlink Google provider if connected
      if (user.providerData.any((element) => element.providerId == 'google.com')) {
        await user.unlink('google.com');
      }
  
      // Delete the Firebase account
      await user.delete();
  
      // Sign out from Firebase and Google
      await GoogleSignIn().signOut();
      await FirebaseAuth.instance.signOut();
  
      if (!mounted) return;
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la suppression: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      String? avatarUrl = _currentAvatarUrl;
      if (_newProfileImage != null) {
        avatarUrl = await _uploadImageToCloudinary(_newProfileImage!);
      }

      // Parse age to integer
      int? age;
      if (_ageController.text.isNotEmpty) {
        age = int.tryParse(_ageController.text);
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({
        'firstname': _firstNameController.text.trim(),
        'lastname': _lastNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'gender': _selectedGender,
        if (age != null) 'age': age,
        if (avatarUrl != null) 'avatarUrl': avatarUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profil mis à jour avec succès'),
          backgroundColor: Theme.of(context).brightness == Brightness.dark 
              ? AppColors.primaryGreen 
              : AppColors.primaryDarkGreen,
        ),
      );
      context.pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de mise à jour: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;
    final backgroundColor = isDarkMode ? Colors.grey.shade900 : Colors.white;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Modifier le profil',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        backgroundColor: backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryColor),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            )
          : Container(
              color: backgroundColor,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                              backgroundImage: _newProfileImage != null
                                  ? FileImage(_newProfileImage!)
                                  : (_currentAvatarUrl != null
                                      ? NetworkImage(_currentAvatarUrl!)
                                      : null) as ImageProvider?,
                              child: (_newProfileImage == null && _currentAvatarUrl == null)
                                  ? Icon(
                                      Icons.person,
                                      size: 60,
                                      color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: primaryColor,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.2),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.edit,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // First Name Field
                      _buildTextField(
                        controller: _firstNameController,
                        labelText: 'Prénom',
                        hintText: 'Entrez votre prénom',
                        prefixIcon: Icons.person,
                        validator: (value) => value?.isEmpty ?? true ? 'Champ requis' : null,
                        isDarkMode: isDarkMode,
                      ),
                      const SizedBox(height: 16),
                      
                      // Last Name Field
                      _buildTextField(
                        controller: _lastNameController,
                        labelText: 'Nom',
                        hintText: 'Entrez votre nom',
                        prefixIcon: Icons.person_outline,
                        validator: (value) => value?.isEmpty ?? true ? 'Champ requis' : null,
                        isDarkMode: isDarkMode,
                      ),
                      const SizedBox(height: 16),
                      
                      // Phone Field with Tunisian validation
                      _buildTextField(
                        controller: _phoneController,
                        labelText: 'Téléphone',
                        hintText: 'Numéro à 8 chiffres',
                        prefixIcon: Icons.phone,
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Champ requis';
                          }
                          if (!RegExp(r'^[0-9]{8}$').hasMatch(value)) {
                            return 'Numéro tunisien invalide (8 chiffres)';
                          }
                          return null;
                        },
                        isDarkMode: isDarkMode,
                      ),
                      const SizedBox(height: 16),
                      
                      // Age Field with minimum 18 validation
                      _buildTextField(
                        controller: _ageController,
                        labelText: 'Âge',
                        hintText: 'Minimum 18 ans',
                        prefixIcon: Icons.calendar_today,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Champ requis';
                          }
                          final age = int.tryParse(value);
                          if (age == null) {
                            return 'Entrez un nombre valide';
                          }
                          if (age < 18) {
                            return 'Vous devez avoir au moins 18 ans';
                          }
                          return null;
                        },
                        isDarkMode: isDarkMode,
                      ),
                      const SizedBox(height: 16),
                      
                      // Gender Dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.person_pin,
                              color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Genre:',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedGender,
                                  isExpanded: true,
                                  dropdownColor: isDarkMode ? Colors.grey.shade800 : Colors.white,
                                  items: [
                                    DropdownMenuItem(
                                      value: 'homme',
                                      child: Text(
                                        'Homme',
                                        style: GoogleFonts.poppins(
                                          color: textColor,
                                        ),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 'femme',
                                      child: Text(
                                        'Femme',
                                        style: GoogleFonts.poppins(
                                          color: textColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    if (value != null) {
                                      setState(() {
                                        _selectedGender = value;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: _buildButton(
                              text: 'Enregistrer',
                              onPressed: _saveChanges,
                              isPrimary: true,
                              isDarkMode: isDarkMode,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildButton(
                              text: 'Supprimer le compte',
                              onPressed: _deleteAccount,
                              isPrimary: false,
                              isDestructive: true,
                              isDarkMode: isDarkMode,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
  
  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required IconData prefixIcon,
    FormFieldValidator<String>? validator,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    required bool isDarkMode,
  }) {
    final borderColor = isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300;
    final fillColor = isDarkMode ? Colors.grey.shade800 : Colors.grey.shade50;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          labelText,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: GoogleFonts.poppins(
              color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
              fontSize: 14,
            ),
            filled: true,
            fillColor: fillColor,
            prefixIcon: Icon(
              prefixIcon,
              color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red.shade700),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          ),
          style: GoogleFonts.poppins(
            color: textColor,
            fontSize: 14,
          ),
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
        ),
      ],
    );
  }
  
  Widget _buildButton({
    required String text,
    required VoidCallback onPressed,
    required bool isPrimary,
    bool isDestructive = false,
    required bool isDarkMode,
  }) {
    Color backgroundColor;
    Color textColor;
    
    if (isDestructive) {
      backgroundColor = Colors.red.shade700;
      textColor = Colors.white;
    } else if (isPrimary) {
      backgroundColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;
      textColor = Colors.white;
    } else {
      backgroundColor = isDarkMode ? Colors.grey.shade800 : Colors.white;
      textColor = isDarkMode ? Colors.white : Colors.black87;
    }
    
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: isPrimary || isDestructive
              ? BorderSide.none
              : BorderSide(
                  color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                ),
        ),
        elevation: isPrimary || isDestructive ? 2 : 0,
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    super.dispose();
  }
}