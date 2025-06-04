import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../front/app_colors.dart';
import '../../front/app_spacing.dart';
import '../../front/app_typography.dart';
import '../../front/custom_app_bar.dart';
import '../../front/custom_button.dart';
import '../../front/custom_snackbar.dart';
import '../../front/loading_overlay.dart';
import '../../utils/cloudinary_service.dart';
import '../../utils/image_upload_utils.dart';

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
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isImmediateReservation = false;
  bool _isLoading = false;
  
  List<File> _problemImages = [];
  
  // Variables for map and location
  LatLng? _selectedLocation;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};

  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate);
    _getCurrentLocation().then((_) {
      if (_selectedLocation != null) {
        _updateMarker(_selectedLocation!);
      }
    });
    _initUserLocation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _timeController.text = _selectedTime.format(context);
  }
  
  @override
  void dispose() {
    _descriptionController.dispose();
    _addressController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _pageController.dispose();
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
      debugPrint('Error fetching location: $e');
    }
  }
  
  // Get current user location
  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          CustomSnackbar.showInfo(context: context, message: "Les services de localisation sont désactivés. Veuillez les activer dans les paramètres de votre appareil.");
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            CustomSnackbar.showInfo(context: context, message: "Autorisation de localisation refusée. Veuillez accorder l'accès à la localisation pour utiliser cette fonctionnalité.");
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          CustomSnackbar.showInfo(context: context, message: "L'autorisation de localisation est définitivement refusée. Veuillez l'activer manuellement dans les paramètres de votre appareil.");
        }
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
      if (mounted) {
        CustomSnackbar.showError(context: context, message: "Erreur lors de la récupération de la localisation: ${e.toString()}");
      }
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
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_selectedLocation!, 15.0),
      );
      _updateMarker(_selectedLocation!);
    }
  }
  
  // Select location on map
  void _onTapMap(LatLng point) async {
    setState(() {
      _selectedLocation = point;
    });
    _updateMarker(point);
    
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
  
  void _updateMarker(LatLng point) {
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('selected_location'),
          infoWindow: const InfoWindow(title: 'Emplacement sélectionné'),
          position: point,
        ),
      };
    });
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
            colorScheme: isDarkMode
                ? ColorScheme.dark(
                    primary: AppColors.primaryGreen,
                    onPrimary: Colors.white,
                    onSurface: Colors.white,
                    surface: AppColors.darkBackground,
                  )
                : ColorScheme.light(
                    primary: AppColors.primaryDarkGreen,
                    onPrimary: Colors.white,
                    onSurface: Colors.black,
                    surface: Colors.white,
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
        _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate);
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
            colorScheme: isDarkMode
                ? ColorScheme.dark(
                    primary: AppColors.primaryGreen,
                    onPrimary: Colors.white,
                    onSurface: Colors.white,
                    surface: AppColors.darkBackground,
                  )
                : ColorScheme.light(
                    primary: AppColors.primaryDarkGreen,
                    onPrimary: Colors.white,
                    onSurface: Colors.black,
                    surface: Colors.white,
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
        _timeController.text = _selectedTime.format(context);
      });
    }
  }
  
  Future<void> _pickImages() async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final List<File> picked = await ImageUploadUtils.pickMultipleImagesWithOptions(
      context,
      isDarkMode: isDarkMode,
    );
    if (picked.isNotEmpty) {
      setState(() {
        if (_problemImages.length + picked.length > 5) {
          CustomSnackbar.showInfo(context: context, message: "Maximum 5 images autorisées");
          final remainingSlots = 5 - _problemImages.length;
          _problemImages.addAll(picked.take(remainingSlots));
        } else {
          _problemImages.addAll(picked);
        }
      });
    }
  }
  
  void _removeImage(int index) {
    setState(() {
      _problemImages.removeAt(index);
    });
  }
  
  Future<void> _submitReservation() async {
    if (!_validateCurrentPage()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });
    LoadingOverlay.show(context);
    
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
        'title': "Nouvelle demande d'intervention",
        'body': "Vous avez reçu une demande d'intervention de $userName pour ${widget.serviceName}",
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
      
      CustomSnackbar.showSuccess(
        context: context,
        message: "Demande de réservation envoyée avec succès !",
      );
      Navigator.pop(context);
    } catch (e) {
      debugPrint('Error submitting reservation: $e');
      if (!mounted) return;
      
      CustomSnackbar.showError(context: context, message: "Erreur lors de l'envoi de la demande: ${e.toString()}");
    } finally {
      if (mounted) {
        LoadingOverlay.hide();
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _validateCurrentPage() {
    switch (_currentPage) {
      case 0: // Reservation type page
        return true;
      case 1: // Problem description page
        if (_descriptionController.text.trim().isEmpty) {
          CustomSnackbar.showError(context: context, message: "Veuillez décrire votre problème");
          return false;
        }
        return true;
      case 2: // Location page
        if (_selectedLocation == null || _addressController.text.trim().isEmpty) {
          CustomSnackbar.showError(context: context, message: "Veuillez sélectionner votre localisation et entrer une adresse");
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _nextPage() {
    if (_formKey.currentState != null && !_formKey.currentState!.validate()) {
      return;
    }

    if (_validateCurrentPage()) {
      if (_currentPage < 2) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _showConfirmationDialog();
      }
    }
  }

  Future<void> _showConfirmationDialog() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDarkMode ? AppColors.darkBackground : Colors.white,
          title: Text(
            "Confirmer la réservation",
            style: AppTypography.h4(context, color: isDarkMode ? Colors.white : Colors.black87),
          ),
          content: Text(
            "Êtes-vous sûr de vouloir envoyer cette demande de réservation ?",
            style: AppTypography.bodyMedium(context, color: isDarkMode ? Colors.white70 : Colors.black54),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                "Annuler",
                style: AppTypography.bodyLarge(context, color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen),
              ),
            ),
            CustomButton(
              text: "Confirmer",
              onPressed: () => Navigator.of(context).pop(true),
              isPrimary: true,
              height: AppSpacing.buttonMedium,
              width: 150,
              textStyle: AppTypography.bodyLarge(context, color: Colors.white),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      _submitReservation();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;
    
    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightInputBackground,
      appBar: CustomAppBar(
        title: "Réserver une Intervention",
        showBackButton: true,
      ),
      body: Column(
        children: [
          // Progress indicator
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: SmoothPageIndicator(
              controller: _pageController,
              count: 3,
              effect: WormEffect(
                dotHeight: AppSpacing.sm + 2,
                dotWidth: AppSpacing.sm + 2,
                activeDotColor: primaryColor,
                dotColor: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
              ),
            ),
          ),
          
                // Page view
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _buildReservationTypePage(context, isDarkMode, primaryColor),
                        _buildProblemPage(context, isDarkMode, primaryColor),
                        _buildLocationPage(context, isDarkMode, primaryColor),
                      ],
                    ),
                  ),
                ),
                
                // Navigation buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey.shade900 : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentPage > 0)
                  CustomButton(
                    text: "Précédent",
                    onPressed: _previousPage,
                    backgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                    textColor: isDarkMode ? Colors.white : Colors.black87,
                    height: AppSpacing.buttonLarge,
                  )
                else
                  const SizedBox(width: 120),
                  
                CustomButton(
                  text: _currentPage == 2 ? "Envoyer" : "Suivant",
                  onPressed: _nextPage,
                  isPrimary: true,
                  isLoading: _isLoading,
                  height: AppSpacing.buttonLarge,
                  width: 150,
                  backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReservationTypePage(BuildContext context, bool isDarkMode, Color primaryColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            context,
            "Type de réservation",
            isDarkMode,
          ),
          const SizedBox(height: AppSpacing.sectionSpacing),
          _buildReservationTypeSection(context, isDarkMode, primaryColor),
        ],
      ),
    );
  }

  Widget _buildProblemPage(BuildContext context, bool isDarkMode, Color primaryColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            context,
            "Description du problème",
            isDarkMode,
          ),
          const SizedBox(height: AppSpacing.sectionSpacing),
          _buildProblemDescriptionSection(context, isDarkMode, primaryColor),
        ],
      ),
    );
  }

  Widget _buildLocationPage(BuildContext context, bool isDarkMode, Color primaryColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(
            context,
            "Localisation",
            isDarkMode,
          ),
          const SizedBox(height: AppSpacing.sectionSpacing),
          _buildLocationSection(context, isDarkMode, primaryColor),
        ],
      ),
    );
  }
  
  Widget _buildSectionTitle(BuildContext context, String title, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Text(
        title,
        style: AppTypography.h4(context, color: isDarkMode ? Colors.white : Colors.black87),
      ),
    );
  }
  
  Widget _buildReservationTypeSection(BuildContext context, bool isDarkMode, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          title: Text(
            "Intervention immédiate",
            style: AppTypography.bodyLarge(context, color: isDarkMode ? Colors.white : Colors.black87),
          ),
          subtitle: Text(
            "Le prestataire sera notifié immédiatement",
            style: AppTypography.bodySmall(context, color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700),
          ),
          value: _isImmediateReservation,
          onChanged: (value) {
            setState(() {
              _isImmediateReservation = value;
            });
          },
          activeColor: primaryColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
        ),
        
        if (!_isImmediateReservation) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _buildDatePicker(context, isDarkMode, primaryColor),
              ),
              const SizedBox(width: AppSpacing.elementSpacing),
              Expanded(
                child: _buildTimePicker(context, isDarkMode, primaryColor),
              ),
            ],
          ),
        ],
      ],
    );
  }
  
  Widget _buildDatePicker(BuildContext context, bool isDarkMode, Color primaryColor) {
    return TextFormField(
      controller: _dateController,
      readOnly: true,
      onTap: () => _selectDate(context),
      decoration: InputDecoration(
        labelText: "Date de début",
        labelStyle: AppTypography.labelLarge(context, color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700),
        filled: true,
        fillColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(width: 0, style: BorderStyle.none),
        ),
        contentPadding: const EdgeInsets.all(AppSpacing.md),
        prefixIcon: Icon(
          Icons.calendar_today,
          size: AppSpacing.iconSm,
          color: primaryColor,
        ),
      ),
      style: AppTypography.bodyMedium(context, color: isDarkMode ? Colors.white : Colors.black87),
    );
  }
  
  Widget _buildTimePicker(BuildContext context, bool isDarkMode, Color primaryColor) {
    return TextFormField(
      controller: _timeController,
      readOnly: true,
      onTap: () => _selectTime(context),
      decoration: InputDecoration(
        labelText: "Heure de début",
        labelStyle: AppTypography.labelLarge(context, color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700),
        filled: true,
        fillColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(width: 0, style: BorderStyle.none),
        ),
        contentPadding: const EdgeInsets.all(AppSpacing.md),
        prefixIcon: Icon(
          Icons.access_time,
          size: AppSpacing.iconSm,
          color: primaryColor,
        ),
      ),
      style: AppTypography.bodyMedium(context, color: isDarkMode ? Colors.white : Colors.black87),
    );
  }
  
  Widget _buildProblemDescriptionSection(BuildContext context, bool isDarkMode, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDescriptionField(context, isDarkMode, primaryColor),
        
        const SizedBox(height: AppSpacing.md),
        
        _buildImagePickerSection(context, isDarkMode, primaryColor),
      ],
    );
  }
  
  Widget _buildDescriptionField(BuildContext context, bool isDarkMode, Color primaryColor) {
    return TextFormField(
      controller: _descriptionController,
      maxLines: 4,
      decoration: InputDecoration(
        hintText: "Décrivez votre problème en détail...",
        hintStyle: AppTypography.bodyMedium(context, color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500),
        filled: true,
        fillColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(AppSpacing.md),
      ),
      style: AppTypography.bodyMedium(context, color: isDarkMode ? Colors.white : Colors.black87),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return "Veuillez décrire votre problème";
        }
        return null;
      },
    );
  }
  
  Widget _buildImagePickerSection(BuildContext context, bool isDarkMode, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Photos du problème (optionnel)",
          style: AppTypography.labelLarge(context, color: isDarkMode ? Colors.white : Colors.black87),
        ),
        const SizedBox(height: AppSpacing.sm),
        ImageUploadUtils.buildImagePickerPreview(
          images: _problemImages,
          onRemoveImage: _removeImage,
          onAddImages: _pickImages,
          isLoading: _isLoading,
          isDarkMode: isDarkMode,
          height: 120,
        ),
      ],
    );
  }
  
  Widget _buildLocationSection(BuildContext context, bool isDarkMode, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current location button
        CustomButton(
          text: "Utiliser ma position actuelle",
          onPressed: _useCurrentLocation,
          isPrimary: false,
          height: AppSpacing.buttonMedium,
        ),
        
        const SizedBox(height: AppSpacing.md),

        // Map container
        Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: CameraPosition(
                target: _selectedLocation ?? const LatLng(36.8065, 10.1815),
                zoom: 15.0,
              ),
              onMapCreated: (GoogleMapController controller) {
                _mapController = controller;
                if (_selectedLocation != null) {
                  _updateMarker(_selectedLocation!);
                }
              },
              onTap: _onTapMap,
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            ),
          ),
        ),
        
        const SizedBox(height: AppSpacing.md),
        
        // Address field
        _buildAddressField(context, isDarkMode, primaryColor),
      ],
    );
  }
  
  Widget _buildAddressField(BuildContext context, bool isDarkMode, Color primaryColor) {
    return TextFormField(
      controller: _addressController,
      decoration: InputDecoration(
        labelText: "Adresse",
        hintText: "Adresse complète",
        labelStyle: AppTypography.labelLarge(context, color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700),
        hintStyle: AppTypography.bodyMedium(context, color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500),
        filled: true,
        fillColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.all(AppSpacing.md),
        prefixIcon: Icon(
          Icons.location_on_outlined,
          size: AppSpacing.iconSm,
          color: primaryColor,
        ),
      ),
      style: AppTypography.bodyMedium(context, color: isDarkMode ? Colors.white : Colors.black87),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return "Adresse requise";
        }
        return null;
      },
    );
  }
}
