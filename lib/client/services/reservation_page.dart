import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../front/app_colors.dart';
import '../../front/custom_app_bar.dart';
import '../../front/custom_button.dart';
import '../../utils/cloudinary_service.dart';

class ReservationPage extends StatefulWidget {
  final String providerId;
  final String providerName;
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
  
  // Variables for map and location
  LatLng? _selectedLocation;
  final MapController _mapController = MapController();
  
  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _initUserLocation();
  }
  
  @override
  void dispose() {
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }
  
  // Initialize user location from Firestore
  Future<void> _initUserLocation() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userData = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userData.exists) {
          final city = userData.data()?['city'] as String?;
          if (city != null && city.isNotEmpty) {
            setState(() {
              _addressController.text = city;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Erreur lors de la récupération de la localisation: $e');
    }
  }
  
  // Get current user location
  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permission denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permission permanently denied');
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _selectedLocation = LatLng(position.latitude, position.longitude);
      });
      
      // Get city name from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude, 
        position.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _addressController.text = _formatAddress(place);
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  // Format address
  String _formatAddress(Placemark place) {
    List<String> addressParts = [
      place.street ?? '',
      place.locality ?? '',
      place.subAdministrativeArea ?? '',
      place.administrativeArea ?? '',
    ];
    return addressParts.where((part) => part.isNotEmpty).join(', ');
  }
  
  // Use current location and update map
  Future<void> _useCurrentLocation() async {
    await _getCurrentLocation();
    if (_selectedLocation != null && mounted) {
      _mapController.move(_selectedLocation!, 15.0);
    }
  }
  
  // Select location on map
  void _onTapMap(TapPosition tapPosition, LatLng point) async {
    setState(() {
      _selectedLocation = point;
    });
    
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _addressController.text = _formatAddress(place);
        });
      }
    } catch (e) {
      debugPrint('Error getting address from location: $e');
    }
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
      
      // Create reservation document with location data
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
        'location': _selectedLocation != null ? {
          'latitude': _selectedLocation!.latitude,
          'longitude': _selectedLocation!.longitude,
        } : null,
        'imageUrls': imageUrls,
        'reservationDateTime': Timestamp.fromDate(reservationDateTime),
        'isImmediate': _isImmediateReservation,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'serviceName': widget.serviceName,
      });
      
      // Create notification for provider
      await FirebaseFirestore.instance
          .collection('provider_requests')
          .doc(widget.providerId)
          .collection('notifications')
          .add({
        'title': 'Nouvelle demande d\'intervention',
        'body': 'Vous avez reçu une demande d\'intervention de $userName pour ${widget.serviceName}',
        'type': 'reservation',
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        'data': {
          'reservationId': reservationId,
          'userId': currentUser.uid,
          'userName': userName,
          'serviceName': widget.serviceName,
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
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;
    
    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightInputBackground,
      appBar: CustomAppBar(
        title: 'Réserver une intervention',
        showBackButton: true,
        backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
        titleColor: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        iconColor: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: primaryColor,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    // Reservation type section with improved styling
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDarkMode ? AppColors.darkInputBackground : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Type de réservation',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SwitchListTile(
                            title: Text(
                              'Intervention immédiate',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                            subtitle: Text(
                              'Le prestataire sera notifié immédiatement',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                              ),
                            ),
                            value: _isImmediateReservation,
                            onChanged: (value) {
                              setState(() {
                                _isImmediateReservation = value;
                              });
                            },
                            activeColor: primaryColor,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          
                          if (!_isImmediateReservation) ...[
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _selectDate(context),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            size: 18,
                                            color: primaryColor,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            DateFormat('dd/MM/yyyy').format(_selectedDate),
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              color: isDarkMode ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _selectTime(context),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.access_time,
                                            size: 18,
                                            color: primaryColor,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            _selectedTime.format(context),
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              color: isDarkMode ? Colors.white : Colors.black87,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Problem description section with improved styling
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDarkMode ? AppColors.darkInputBackground : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Description du problème',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _descriptionController,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: 'Décrivez votre problème en détail...',
                              hintStyle: GoogleFonts.poppins(
                                color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500,
                                fontSize: 14,
                              ),
                              filled: true,
                              fillColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.all(16),
                            ),
                            style: GoogleFonts.poppins(
                              color: isDarkMode ? Colors.white : Colors.black87,
                              fontSize: 14,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Veuillez décrire votre problème';
                              }
                              return null;
                            },
                          ),
                          
                          const SizedBox(height: 16),
                          
                          Text(
                            'Photos du problème (optionnel)',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          
                          // Image picker with improved styling
                          Container(
                            height: _problemImages.isEmpty ? 100 : 120,
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                            child: _problemImages.isEmpty
                                ? Center(
                                    child: TextButton.icon(
                                      onPressed: _pickImage,
                                      icon: Icon(
                                        Icons.add_photo_alternate_outlined,
                                        color: primaryColor,
                                      ),
                                      label: Text(
                                        'Ajouter des photos',
                                        style: GoogleFonts.poppins(
                                          color: primaryColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: _problemImages.length + 1,
                                    padding: const EdgeInsets.all(8),
                                    itemBuilder: (context, index) {
                                      if (index == _problemImages.length) {
                                        return _problemImages.length < 5
                                            ? GestureDetector(
                                                onTap: _pickImage,
                                                child: Container(
                                                  width: 80,
                                                  margin: const EdgeInsets.only(right: 8),
                                                  decoration: BoxDecoration(
                                                    color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
                                                    borderRadius: BorderRadius.circular(8),
                                                    border: Border.all(
                                                      color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                                                    ),
                                                  ),
                                                  child: Icon(
                                                    Icons.add_photo_alternate,
                                                    color: primaryColor,
                                                    size: 32,
                                                  ),
                                                ),
                                              )
                                            : const SizedBox.shrink();
                                      }
                                      
                                      return Stack(
                                        children: [
                                          Container(
                                            width: 80,
                                            height: 80,
                                            margin: const EdgeInsets.only(right: 8),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(8),
                                              image: DecorationImage(
                                                image: FileImage(_problemImages[index]),
                                                fit: BoxFit.cover,
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 0,
                                            right: 8,
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
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Location section with map
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDarkMode ? AppColors.darkInputBackground : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Localisation',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Map container
                          Container(
                            height: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: FlutterMap(
                                mapController: _mapController,
                                options: MapOptions(
                                  center: _selectedLocation ?? LatLng(36.8065, 10.1815), // Default to Tunis
                                  zoom: 15.0,
                                  onTap: _onTapMap,
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'com.example.app',
                                  ),
                                  if (_selectedLocation != null)
                                    MarkerLayer(
                                      markers: [
                                        Marker(
                                          width: 40.0,
                                          height: 40.0,
                                          point: _selectedLocation!,
                                          builder: (ctx) => const Icon(
                                            Icons.location_on,
                                            color: Colors.red,
                                            size: 40,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Current location button
                          CustomButton(
                            text: 'Utiliser ma position actuelle',
                            onPressed: _useCurrentLocation,
                            isPrimary: false,
                            height: 44,
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // Address field
                          TextFormField(
                            controller: _addressController,
                            decoration: InputDecoration(
                              labelText: 'Adresse',
                              hintText: 'Adresse complète',
                              labelStyle: GoogleFonts.poppins(
                                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                              ),
                              hintStyle: GoogleFonts.poppins(
                                color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500,
                              ),
                              filled: true,
                              fillColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.all(16),
                              prefixIcon: Icon(
                                Icons.location_on_outlined,
                                color: primaryColor,
                              ),
                            ),
                            style: GoogleFonts.poppins(
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Veuillez entrer une adresse';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Submit button
                    CustomButton(
                      text: 'Envoyer la demande',
                      onPressed: _submitReservation,
                      isPrimary: true,
                      height: 54,
                      width: double.infinity,
                    ),
                    
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }
}