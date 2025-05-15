import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';
import '../../front/app_colors.dart';
import '../../front/custom_app_bar.dart';
import '../../front/custom_button.dart';
import '../../front/custom_text_field.dart';
import '../../utils/cloudinary_service.dart';

class ReclamationFormPage extends StatefulWidget {
  final String reservationId;
  
  const ReclamationFormPage({
    super.key,
    required this.reservationId,
  });

  @override
  State<ReclamationFormPage> createState() => _ReclamationFormPageState();
}

class _ReclamationFormPageState extends State<ReclamationFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  bool _isLoading = false;
  Map<String, dynamic>? _reservationData;
  String? _targetId; // The ID of the provider or client who is the target of the reclamation
  
  List<File> _evidenceImages = [];
  final _picker = ImagePicker();
  
  @override
  void initState() {
    super.initState();
    _fetchReservationDetails();
  }
  
  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
  
  Future<void> _fetchReservationDetails() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final reservationDoc = await FirebaseFirestore.instance
          .collection('reservations')
          .doc(widget.reservationId)
          .get();
      
      if (!reservationDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Réservation introuvable')),
          );
          context.pop();
        }
        return;
      }
      
      final data = reservationDoc.data()!;
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      
      // Determine the target ID (the other party)
      if (currentUserId == data['userId']) {
        // Current user is the client, target is the provider
        _targetId = data['providerId'];
      } else if (currentUserId == data['providerId']) {
        // Current user is the provider, target is the client
        _targetId = data['userId'];
      }
      
      setState(() {
        _reservationData = data;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }
  
  Future<void> _pickImage() async {
    try {
      final pickedFiles = await _picker.pickMultiImage(
        imageQuality: 70,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      
      if (pickedFiles.isNotEmpty) {
        if (_evidenceImages.length + pickedFiles.length > 3) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Maximum 3 images autorisées')),
          );
          final remainingSlots = 3 - _evidenceImages.length;
          final filesToAdd = pickedFiles.take(remainingSlots).toList();
          setState(() {
            _evidenceImages.addAll(filesToAdd.map((file) => File(file.path)));
          });
        } else {
          setState(() {
            _evidenceImages.addAll(pickedFiles.map((file) => File(file.path)));
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sélection des images: $e')),
      );
    }
  }
  
  void _removeImage(int index) {
    setState(() {
      _evidenceImages.removeAt(index);
    });
  }
  
  Future<void> _submitReclamation() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous devez être connecté pour soumettre une réclamation')),
      );
      return;
    }
    
    if (_targetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de déterminer le destinataire de la réclamation')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Upload images if any
      List<String> imageUrls = [];
      if (_evidenceImages.isNotEmpty) {
        imageUrls = await CloudinaryService.uploadImages(_evidenceImages);
      }
      
      // Create reclamation ID
      final reclamationId = const Uuid().v4();
      
      // Save reclamation to Firestore
      await FirebaseFirestore.instance
          .collection('reclamations')
          .doc(reclamationId)
          .set({
        'id': reclamationId,
        'reservationId': widget.reservationId,
        'submitterId': currentUserId,
        'targetId': _targetId,
        'title': _titleController.text,
        'description': _descriptionController.text,
        'imageUrls': imageUrls,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'isNotified': false,
      });
      
      // Update reservation to mark that it has a reclamation
      await FirebaseFirestore.instance
          .collection('reservations')
          .doc(widget.reservationId)
          .update({
        'hasReclamation': true,
      });
      
      // Send notification to admin
      await FirebaseFirestore.instance
          .collection('admin_notifications')
          .add({
        'type': 'reclamation',
        'reclamationId': reclamationId,
        'reservationId': widget.reservationId,
        'title': 'Nouvelle réclamation',
        'body': 'Une nouvelle réclamation a été soumise',
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Réclamation soumise avec succès')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la soumission: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Soumettre une réclamation',
        showBackButton: true,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Reservation info card
                    if (_reservationData != null)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDarkMode ? AppColors.darkInputBackground : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Réservation',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _reservationData!['serviceName'] ?? 'Service non spécifié',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 24),
                    
                    // Title field
                    Text(
                      'Titre de la réclamation',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CustomTextField(
                      labelText: 'Titre',
                      controller: _titleController,
                      hintText: 'Ex: Service non conforme, Problème de qualité...',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un titre';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Description field
                    Text(
                      'Description détaillée',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CustomTextField(
                      labelText: 'Description',
                      controller: _descriptionController,
                      hintText: 'Décrivez votre problème en détail...',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez décrire votre problème';
                        }
                        if (value.length < 20) {
                          return 'La description doit contenir au moins 20 caractères';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Evidence images
                    Text(
                      'Photos (optionnel)',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ajoutez jusqu\'à 3 photos pour illustrer votre problème',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Image picker
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDarkMode ? AppColors.darkInputBackground : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Selected images
                          if (_evidenceImages.isNotEmpty)
                            SizedBox(
                              height: 100,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _evidenceImages.length,
                                itemBuilder: (context, index) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Stack(
                                      children: [
                                        Container(
                                          width: 100,
                                          height: 100,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                            image: DecorationImage(
                                              image: FileImage(_evidenceImages[index]),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 4,
                                          right: 4,
                                          child: GestureDetector(
                                            onTap: () => _removeImage(index),
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.close,
                                                size: 16,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          
                          if (_evidenceImages.isNotEmpty)
                            const SizedBox(height: 16),
                          
                          // Add image button
                          if (_evidenceImages.length < 3)
                            ElevatedButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.add_photo_alternate),
                              label: const Text('Ajouter des photos'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isDarkMode ? AppColors.darkInputBackground : Colors.white,
                                foregroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                                side: BorderSide(
                                  color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Submit button
                    CustomButton(
                      text: 'Soumettre la réclamation',
                      onPressed: _submitReclamation,
                      backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}