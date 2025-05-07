import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../front/app_colors.dart';
import '../../front/custom_app_bar.dart';
import '../../front/custom_button.dart';
import '../../front/custom_text_field.dart';
import '../../utils/cloudinary_service.dart';

class ReservationPage extends StatefulWidget {
  final String providerId;
  final String providerName; // This will now be fetched from users collection
  final String serviceName;

  const ReservationPage({
    super.key,
    required this.providerId,
    required this.providerName,
    required this.serviceName,
  });

  @override
  State<ReservationPage> createState() => _ReservationPageState();
}

class _ReservationPageState extends State<ReservationPage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isImmediateReservation = false;
  bool _isLoading = false;
  
List<File> _problemImages = [];
final _picker = ImagePicker();
  
  @override
  void dispose() {
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }
  
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
              onPrimary: Colors.white,
              onSurface: isDarkMode ? Colors.white : Colors.black,
            ),
            dialogBackgroundColor: isDarkMode ? AppColors.darkBackground : Colors.white,
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }
  
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
              onPrimary: Colors.white,
              onSurface: isDarkMode ? Colors.white : Colors.black,
            ),
            dialogBackgroundColor: isDarkMode ? AppColors.darkBackground : Colors.white,
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }
  
  // Add these methods after _pickImages()
  
  // Method to pick images (replace the _pickImage reference with this)
  Future<void> _pickImage() async {
    try {
      final pickedFiles = await _picker.pickMultiImage(
        imageQuality: 70,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      
      if (pickedFiles.isNotEmpty) {
        if (_problemImages.length + pickedFiles.length > 5) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Maximum 5 images allowed')),
          );
          final remainingSlots = 5 - _problemImages.length;
          final filesToAdd = pickedFiles.take(remainingSlots).toList();
          setState(() {
            _problemImages.addAll(filesToAdd.map((file) => File(file.path)));
          });
        } else {
          setState(() {
            _problemImages.addAll(pickedFiles.map((file) => File(file.path)));
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting images: $e')),
      );
    }
  }
  
  // Method to remove an image
  void _removeImage(int index) {
    setState(() {
      _problemImages.removeAt(index);
    });
  }
  
  Future<void> _submitReservation() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      List<String> imageUrls = [];
    if (_problemImages.isNotEmpty) {
      imageUrls = await CloudinaryService.uploadImages(_problemImages);
    }
      
      // Create reservation datetime
      DateTime reservationDateTime;
      if (_isImmediateReservation) {
        reservationDateTime = DateTime.now();
      } else {
        reservationDateTime = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          _selectedTime.hour,
          _selectedTime.minute,
        );
      }
      
      // Get user data for notification
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      final userData = userDoc.data() ?? {};
      final userName = '${userData['firstname'] ?? ''} ${userData['lastname'] ?? ''}'.trim();
      
      // Create reservation document
      final reservationId = const Uuid().v4();
      await FirebaseFirestore.instance
          .collection('reservations')
          .doc(reservationId)
          .set({
        'reservationId': reservationId,
        'providerId': widget.providerId,
        'userId': currentUser.uid,
        'description': _descriptionController.text,
        'address': _addressController.text,
        'imageUrls': imageUrls, // Store the Cloudinary URLs
        'reservationDateTime': Timestamp.fromDate(reservationDateTime),
        'isImmediate': _isImmediateReservation,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'serviceName': widget.serviceName, // Add the service name to the reservation
      });
      
      // Create notification for provider
      await FirebaseFirestore.instance
          .collection('provider_requests')
          .doc(widget.providerId)
          .collection('notifications')
          .add({
        'title': 'Nouvelle demande d\'intervention',
        'body': 'Vous avez reçu une demande d\'intervention de $userName pour ${widget.serviceName}', // Include service name in notification
        'type': 'reservation',
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        'data': {
          'reservationId': reservationId,
          'userId': currentUser.uid,
          'userName': userName,
          'serviceName': widget.serviceName, // Include service name in notification data
        },
      });
      
      Navigator.pop(context);
    } catch (e) {
      print('Error submitting reservation: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'envoi de la demande: $e')),
      );
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
        title: 'Réserver une intervention',
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
                    // Provider info card
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
                            'Prestataire',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.providerName,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Service',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.serviceName,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Description field
                    Text(
                      'Description du problème',
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
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Problem images
                    Text(
                      'Photos du problème (optionnel)',
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
                        color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        // Add image button
                        GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                              ),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.add_photo_alternate,
                                size: 40,
                                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 12),
                        
                        // Image previews
                        Expanded(
                          child: SizedBox(
                            height: 100,
                            child: _problemImages.isEmpty
                                ? Center(
                                    child: Text(
                                      'Aucune photo sélectionnée',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _problemImages.length,
                                    itemBuilder: (context, index) {
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 8),
                                        child: Stack(
                                          children: [
                                            Container(
                                              width: 100,
                                              height: 100,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(12),
                                                image: DecorationImage(
                                                  image: FileImage(_problemImages[index]),
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
                                                    color: Colors.black.withOpacity(0.7),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.close,
                                                    color: Colors.white,
                                                    size: 16,
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
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Address field
                    Text(
                      'Adresse d\'intervention',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    CustomTextField(
                      labelText: 'Adresse',
                      controller: _addressController,
                      hintText: 'Entrez l\'adresse complète',
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer une adresse';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Reservation type
                    Text(
                      'Type d\'intervention',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _isImmediateReservation = true;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _isImmediateReservation
                                    ? (isDarkMode ? AppColors.primaryGreen.withOpacity(0.2) : AppColors.primaryDarkGreen.withOpacity(0.1))
                                    : (isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _isImmediateReservation
                                      ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                                      : (isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300),
                                  width: _isImmediateReservation ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.flash_on,
                                    color: _isImmediateReservation
                                        ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                                        : (isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                                    size: 32,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Immédiate',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: _isImmediateReservation
                                          ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                                          : (isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _isImmediateReservation = false;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: !_isImmediateReservation
                                    ? (isDarkMode ? AppColors.primaryGreen.withOpacity(0.2) : AppColors.primaryDarkGreen.withOpacity(0.1))
                                    : (isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: !_isImmediateReservation
                                      ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                                      : (isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300),
                                  width: !_isImmediateReservation ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.calendar_today,
                                    color: !_isImmediateReservation
                                        ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                                        : (isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                                    size: 32,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Planifiée',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: !_isImmediateReservation
                                          ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                                          : (isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // Date and time pickers (only shown for scheduled reservations)
                    if (!_isImmediateReservation) ...[
                      const SizedBox(height: 24),
                      
                      Text(
                        'Date et heure',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Date picker
                      GestureDetector(
                        onTap: () => _selectDate(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDarkMode ? AppColors.darkInputBackground : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                DateFormat('dd/MM/yyyy').format(_selectedDate),
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.arrow_drop_down,
                                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Time picker
                      GestureDetector(
                        onTap: () => _selectTime(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isDarkMode ? AppColors.darkInputBackground : Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _selectedTime.format(context),
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.arrow_drop_down,
                                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 32),
                    
                    // Submit button
                    CustomButton(
                      onPressed: _submitReservation,
                      text: 'Envoyer la demande',
                      backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                      textColor: Colors.white,
                    ),
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}