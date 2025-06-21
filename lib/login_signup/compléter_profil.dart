import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:google_fonts/google_fonts.dart';
import '../front/custom_button.dart';
import '../front/custom_snackbar.dart';
import '../front/app_colors.dart';
import '../front/custom_text_field.dart';
import '../front/loading_overlay.dart';
import '../front/page_transition.dart';
import '../utils/cloudinary_service.dart';

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
  final _ageController = TextEditingController(text: '25'); 

  String _role = "client";
  String _gender = "homme";
  File? _profileImage;
  bool _isLoading = false;
  int _currentStep = 0;
  
  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _ageController.dispose(); // Dispose age controller
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

  // Removed _uploadImageToCloudinary as it's now in CloudinaryService

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
      
      // Upload profile image if selected using CloudinaryService
      String? avatarUrl;
      if (_profileImage != null) {
        avatarUrl = await CloudinaryService.uploadImage(_profileImage!);
      }
      
      // Prepare user data
      final userData = {
        'firstname': _firstNameController.text.trim(),
        'lastname': _lastNameController.text.trim(),
        'role': _role,
        'updatedAt': FieldValue.serverTimestamp(),
        'gender': _gender,
        'age': int.tryParse(_ageController.text) ?? 25, // Parse age from text field
        'phone': _phoneController.text.trim(),
      };
      
      // Add photo URL if available
      if (avatarUrl != null) {
        userData['avatarUrl'] = avatarUrl;
      }
      
      // Update user profile in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            ...userData,
            'profileCompleted': true, // Mark profile as completed
          });
      
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
    FocusScope.of(context).unfocus(); // Dismiss keyboard
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
    FocusScope.of(context).unfocus(); // Dismiss keyboard
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
    } else if (_currentStep == 2) {
      // Validate age for step 2
      final age = int.tryParse(_ageController.text);
      return age != null && age >= 18 && age <= 80;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightInputBackground,
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
            fontSize: 24, // Consistent font size
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
              horizontal: 24, // Consistent horizontal padding
              vertical: 16, // Consistent vertical padding
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
                  const SizedBox(height: 24), // Consistent spacing
                  
                  // Step indicator
                  Center(
                    child: Text(
                      'Étape ${_currentStep + 1} sur 3',
                      style: GoogleFonts.poppins(
                        fontSize: 16, // Consistent font size
                        color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32), // Consistent spacing
                  
                  // Profile image (shown on all steps)
                  if (_currentStep == 0)
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 50, // Reduced radius
                              backgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                              backgroundImage: _profileImage != null 
                                  ? FileImage(_profileImage!) 
                                  : null,
                              child: _profileImage == null
                                  ? Icon(
                                      Icons.person,
                                      size: 50, // Reduced size
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
                  const SizedBox(height: 32), // Consistent spacing
                  
                  // Step content
                  _buildCurrentStep(context, size, isDarkMode),
                  
                  const SizedBox(height: 32), // Consistent spacing
                  
                  // Next/Submit button
                  CustomButton(
                    text: _currentStep < 2 ? 'Continuer' : 'Terminer',
                    onPressed: _validateCurrentStep() ? _nextStep : null,
                    isLoading: _currentStep == 2 && _isLoading, // Only show loading on final step
                    width: double.infinity,
                    height: 50, // Consistent button height
                    useFullScreenLoader: _currentStep == 2, // Only use full screen loader on final step
                    backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen, // Consistent primary color
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
            fontSize: 24, // Consistent font size
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8), // Consistent spacing
        Text(
          'Veuillez entrer votre nom et prénom',
          style: GoogleFonts.poppins(
            fontSize: 16, // Consistent font size
            color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 24), // Consistent spacing
        
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
        const SizedBox(height: 16), // Consistent spacing
        
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
            fontSize: 24, // Consistent font size
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8), // Consistent spacing
        Text(
          'Veuillez entrer votre numéro de téléphone',
          style: GoogleFonts.poppins(
            fontSize: 16, // Consistent font size
            color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 24), // Consistent spacing
        
        // Phone number field with enhanced Tunisian validation
        CustomTextField(
          controller: _phoneController,
          labelText: 'Numéro de téléphone',
          hintText: 'Entrez votre numéro (8 chiffres)',
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Veuillez entrer votre numéro de téléphone';
            }
            
            // Check if it's exactly 8 digits
            if (!RegExp(r'^[0-9]{8}$').hasMatch(value)) {
              return 'Le numéro doit contenir 8 chiffres';
            }
            
            // Validate Tunisian phone number prefixes
            final firstDigit = value.substring(0, 1);
            if (!['2', '3', '4', '5', '9', '7'].contains(firstDigit)) {
              return 'Numéro invalide. Doit commencer par 2, 3, 4, 5, 7 ou 9';
            }
            
            // Additional validation for specific carrier prefixes
            final prefix = value.substring(0, 2);
            
            // Ooredoo: 5x, 9x
            // Tunisie Telecom: 2x, 4x, 7x
            // Orange: 3x
            final validPrefixes = [
              // Tunisie Telecom
              '20', '21', '22', '23', '24', '25', '26', '27', '28', '29',
              '40', '41', '42', '43', '44', '45', '46', '47', '48', '49',
              '70', '71', '72', '73', '74', '75', '76', '77', '78', '79',
              // Ooredoo
              '50', '51', '52', '53', '54', '55', '56', '57', '58', '59',
              '90', '91', '92', '93', '94', '95', '96', '97', '98', '99',
              // Orange
              '30', '31', '32', '33', '34', '35', '36', '37', '38', '39',
            ];
            
            if (!validPrefixes.contains(prefix)) {
              return 'Préfixe de numéro invalide';
            }
            
            return null;
          },
          prefixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 12),
              const Icon(Icons.phone),
              const SizedBox(width: 8),
              // Tunisia flag emoji
              Text(
                '🇹🇳',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        // Removed the carrier explanation text
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
            fontSize: 24, // Consistent font size
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8), // Consistent spacing
        Text(
          'Quelques informations supplémentaires',
          style: GoogleFonts.poppins(
            fontSize: 16, // Consistent font size
            color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 24), // Consistent spacing
        
        // Gender selection
        Text(
          'Genre',
          style: GoogleFonts.poppins(
            fontSize: 16, // Consistent font size
            fontWeight: FontWeight.w500,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8), // Consistent spacing
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: Text(
                  'Homme',
                  style: GoogleFonts.poppins(
                    fontSize: 16, // Consistent font size
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
                    fontSize: 16, // Consistent font size
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
        const SizedBox(height: 24), // Consistent spacing
        
        // Age input
        CustomTextField(
          controller: _ageController,
          labelText: 'Âge',
          hintText: 'Entrez votre âge',
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Veuillez entrer votre âge';
            }
            final age = int.tryParse(value);
            if (age == null || age < 18 || age > 80) {
              return 'L\'âge doit être entre 18 et 80 ans';
            }
            return null;
          },
        ),
        const SizedBox(height: 24), // Consistent spacing
        
        // Role selection (images)
        Text(
          'Je suis...', // Playful message
          style: GoogleFonts.poppins(
            fontSize: 16, // Consistent font size
            fontWeight: FontWeight.w500,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8), // Consistent spacing
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildRoleOption(
              context,
              'client',
              'Client',
              'assets/images/person.png',
              isDarkMode,
            ),
            _buildRoleOption(
              context,
              'prestataire',
              'Prestataire de services',
              'assets/images/prestataire.png',
              isDarkMode,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleOption(BuildContext context, String roleValue, String roleText, String imagePath, bool isDarkMode) {
    final isSelected = _role == roleValue;
    return SizedBox( // Wrap with SizedBox for fixed height
      height: 155, // Fixed height for the entire card
      child: GestureDetector(
        onTap: () {
          setState(() {
            _role = roleValue;
          });
        },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, // Center content vertically
        children: [
          Container(
            width: 100,
            height: 100,
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                    : (isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                      : (isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300),
                  width: 2,
                ),
              ),
              child: Center(
                child: Image.asset(
                  imagePath,
                  height: 60,
                  width: 60,
                  fit: BoxFit.contain, // Changed from cover to contain
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: 80, // Constrain width to force wrapping
              child: Text(
                roleText,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                      : (isDarkMode ? Colors.white : Colors.black87),
                ),
                textAlign: TextAlign.center, // Ensure text is centered within its constrained width
                maxLines: 2, // Allow up to 2 lines
                overflow: TextOverflow.ellipsis, // Add ellipsis if it still overflows
              ),
            ),
          ],
        ),
      ),
    );
  }
}
