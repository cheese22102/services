import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';
import '../front/custom_button.dart';
import '../front/custom_snackbar.dart';
import '../front/app_colors.dart';
import '../front/custom_text_field.dart';
import '../front/loading_overlay.dart';
import '../front/page_transition.dart';

class Signup2Page extends StatefulWidget {
  const Signup2Page({super.key});

  @override
  _Signup2PageState createState() => _Signup2PageState();
}

class _Signup2PageState extends State<Signup2Page> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  
  String _role = "client";
  String _gender = "homme"; // Default to homme
  int _age = 25; // Default age
  File? _profileImage;
  bool _isLoading = false;
  int _currentStep = 0; // Track the current step in the walkthrough
  
  // For image upload
  final String cloudName = "dfk7mskxv";
  final String uploadPreset = "plateforme_service";

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
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

  Future<void> _saveUserInfo() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    // Show loading overlay
    LoadingOverlay.show(context, message: 'Enregistrement de votre profil...');
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("Utilisateur non connecté");
      }
      
      // Upload profile image if selected
      String? photoURL;
      if (_profileImage != null) {
        photoURL = await _uploadImageToCloudinary(_profileImage!);
      }
      
      // Prepare user data
      final userData = {
        'firstname': _firstNameController.text.trim(),
        'lastname': _lastNameController.text.trim(),
        'role': _role,
        'updatedAt': FieldValue.serverTimestamp(),
        'gender': _gender,
        'age': _age,
        'phone': _phoneController.text.trim(),
      };
      
      // Add photo URL if available
      if (photoURL != null) {
        userData['photoURL'] = photoURL;
      }
      
      // Update user profile in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(userData);
      
      // Hide loading overlay
      LoadingOverlay.hide();
      
      if (!mounted) return;
      
      // Show success message and navigate after a short delay
      // This prevents the context issue during navigation
      final navigateTo = _role == "client" ? '/clientHome' : '/prestataireHome';
      
      // Show success message
      CustomSnackbar.showSuccess(
        context: context,
        message: 'Profil complété avec succès!',
      );
      
      // Add a small delay before navigation to allow the snackbar to be seen
      // and to prevent context issues
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!mounted) return;
      
      // Navigate based on role
      context.go(navigateTo, extra: getSlideTransitionInfo(SlideDirection.leftToRight));
      
    } catch (e) {
      // Hide loading overlay
      LoadingOverlay.hide();
      
      if (!mounted) return;
      
      CustomSnackbar.showError(
        context: context,
        message: 'Erreur: ${e.toString()}',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Move to next step in the walkthrough
  void _nextStep() {
    if (_currentStep < 2) { // We have 3 steps (0, 1, 2)
      // Make sure any loading overlay is hidden before changing steps
      LoadingOverlay.hide();
      
      setState(() {
        _currentStep++;
        _isLoading = false; // Reset loading state when changing steps
      });
    } else {
      _saveUserInfo();
    }
  }

  // Move to previous step in the walkthrough
  void _previousStep() {
    if (_currentStep > 0) {
      // Make sure any loading overlay is hidden before changing steps
      LoadingOverlay.hide();
      
      setState(() {
        _currentStep--;
        _isLoading = false; // Reset loading state when changing steps
      });
    }
  }

  // Validate current step before proceeding
  bool _validateCurrentStep() {
    if (_currentStep == 0) {
      // Validate name fields
      return _firstNameController.text.isNotEmpty && 
             _lastNameController.text.isNotEmpty;
    } else if (_currentStep == 1) {
      // Validate phone number (8 digits for Tunisia)
      final phoneRegex = RegExp(r'^[0-9]{8}$');
      return phoneRegex.hasMatch(_phoneController.text);
    }
    return true; // Step 2 doesn't need validation
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentStep > 0 
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back_ios,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
                onPressed: _previousStep,
              )
            : null,
        title: Text(
          'Complétez votre profil',
          style: GoogleFonts.poppins(
            fontSize: size.width * 0.05,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: size.width * 0.06,
              vertical: size.height * 0.02,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Progress indicator
                  LinearProgressIndicator(
                    value: (_currentStep + 1) / 3,
                    backgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                    ),
                  ),
                  SizedBox(height: size.height * 0.02),
                  
                  // Step indicator
                  Center(
                    child: Text(
                      'Étape ${_currentStep + 1} sur 3',
                      style: GoogleFonts.poppins(
                        fontSize: size.width * 0.04,
                        color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                  SizedBox(height: size.height * 0.03),
                  
                  // Profile image (shown on all steps)
                  if (_currentStep == 0)
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 60,
                              backgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                              backgroundImage: _profileImage != null 
                                  ? FileImage(_profileImage!) 
                                  : null,
                              child: _profileImage == null
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
                                  color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  SizedBox(height: size.height * 0.03),
                  
                  // Step content
                  _buildCurrentStep(context, size, isDarkMode),
                  
                  SizedBox(height: size.height * 0.04),
                  
                  // Next/Submit button
                  CustomButton(
                    text: _currentStep < 2 ? 'Continuer' : 'Terminer',
                    onPressed: _validateCurrentStep() ? _nextStep : null,
                    isLoading: _currentStep == 2 && _isLoading, // Only show loading on final step
                    width: double.infinity,
                    useFullScreenLoader: _currentStep == 2, // Only use full screen loader on final step
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildCurrentStep(BuildContext context, Size size, bool isDarkMode) {
    switch (_currentStep) {
      case 0:
        return _buildPersonalInfoStep(context, size, isDarkMode);
      case 1:
        return _buildContactInfoStep(context, size, isDarkMode);
      case 2:
        return _buildPreferencesStep(context, size, isDarkMode);
      default:
        return const SizedBox.shrink();
    }
  }
  
  Widget _buildPersonalInfoStep(BuildContext context, Size size, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Informations personnelles',
          style: GoogleFonts.poppins(
            fontSize: size.width * 0.06,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        SizedBox(height: size.height * 0.01),
        Text(
          'Veuillez entrer votre nom et prénom',
          style: GoogleFonts.poppins(
            fontSize: size.width * 0.04,
            color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        SizedBox(height: size.height * 0.03),
        
        // First name field
        CustomTextField(
          controller: _firstNameController,
          labelText: 'Prénom',
          hintText: 'Entrez votre prénom',
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Veuillez entrer votre prénom';
            }
            return null;
          },
        ),
        SizedBox(height: size.height * 0.02),
        
        // Last name field
        CustomTextField(
          controller: _lastNameController,
          labelText: 'Nom',
          hintText: 'Entrez votre nom',
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Veuillez entrer votre nom';
            }
            return null;
          },
        ),
      ],
    );
  }
  
  Widget _buildContactInfoStep(BuildContext context, Size size, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Coordonnées',
          style: GoogleFonts.poppins(
            fontSize: size.width * 0.06,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        SizedBox(height: size.height * 0.01),
        Text(
          'Veuillez entrer votre numéro de téléphone',
          style: GoogleFonts.poppins(
            fontSize: size.width * 0.04,
            color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        SizedBox(height: size.height * 0.03),
        
        // Phone number field
        CustomTextField(
          controller: _phoneController,
          labelText: 'Numéro de téléphone',
          hintText: 'Entrez votre numéro (8 chiffres)',
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Veuillez entrer votre numéro de téléphone';
            }
            if (!RegExp(r'^[0-9]{8}$').hasMatch(value)) {
              return 'Le numéro doit contenir 8 chiffres';
            }
            return null;
          },
        ),
      ],
    );
  }
  
  Widget _buildPreferencesStep(BuildContext context, Size size, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Préférences',
          style: GoogleFonts.poppins(
            fontSize: size.width * 0.06,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        SizedBox(height: size.height * 0.01),
        Text(
          'Quelques informations supplémentaires',
          style: GoogleFonts.poppins(
            fontSize: size.width * 0.04,
            color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        SizedBox(height: size.height * 0.03),
        
        // Gender selection
        Text(
          'Genre',
          style: GoogleFonts.poppins(
            fontSize: size.width * 0.04,
            fontWeight: FontWeight.w500,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        SizedBox(height: size.height * 0.01),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: Text(
                  'Homme',
                  style: GoogleFonts.poppins(
                    fontSize: size.width * 0.04,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                value: 'homme',
                groupValue: _gender,
                onChanged: (value) {
                  setState(() {
                    _gender = value!;
                  });
                },
                activeColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: Text(
                  'Femme',
                  style: GoogleFonts.poppins(
                    fontSize: size.width * 0.04,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                value: 'femme',
                groupValue: _gender,
                onChanged: (value) {
                  setState(() {
                    _gender = value!;
                  });
                },
                activeColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        SizedBox(height: size.height * 0.03),
        
        // Age slider
        Text(
          'Âge: $_age ans',
          style: GoogleFonts.poppins(
            fontSize: size.width * 0.04,
            fontWeight: FontWeight.w500,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        Slider(
          value: _age.toDouble(),
          min: 18,
          max: 80,
          divisions: 62,
          label: _age.toString(),
          onChanged: (double value) {
            setState(() {
              _age = value.round();
            });
          },
          activeColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
          inactiveColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
        ),
        SizedBox(height: size.height * 0.03),
        
        // Role selection
        Text(
          'Type de compte',
          style: GoogleFonts.poppins(
            fontSize: size.width * 0.04,
            fontWeight: FontWeight.w500,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        SizedBox(height: size.height * 0.01),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _role,
              isExpanded: true,
              dropdownColor: isDarkMode ? Colors.grey.shade900 : Colors.white,
              icon: Icon(
                Icons.arrow_drop_down,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              items: [
                DropdownMenuItem(
                  value: 'client',
                  child: Text(
                    'Client',
                    style: GoogleFonts.poppins(
                      fontSize: size.width * 0.04,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                DropdownMenuItem(
                  value: 'prestataire',
                  child: Text(
                    'Prestataire de services',
                    style: GoogleFonts.poppins(
                      fontSize: size.width * 0.04,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _role = value!),
            ),
          ),
        ),
      ],
    );
  }
}