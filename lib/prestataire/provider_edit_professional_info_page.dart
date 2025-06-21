import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../front/app_colors.dart';
import 'utils/provider_utils.dart';
import '../front/custom_button.dart';
import '../front/custom_text_field.dart';
import '../utils/image_upload_utils.dart';
import '../front/app_spacing.dart';
import '../front/app_typography.dart';
import '../front/custom_snackbar.dart';
import '../front/loading_overlay.dart';

class ProviderEditProfessionalInfoPage extends StatefulWidget {
  final Map<String, dynamic>? initialProviderData;
  final Map<String, dynamic>? initialUserData;

  const ProviderEditProfessionalInfoPage({
    super.key,
    this.initialProviderData,
    this.initialUserData,
  });

  @override
  State<ProviderEditProfessionalInfoPage> createState() => _ProviderEditProfessionalInfoPageState();
}

class _ProviderEditProfessionalInfoPageState extends State<ProviderEditProfessionalInfoPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  
  // Data from provider_registration.dart for editable fields
  final _workingAreaController = TextEditingController();
  List<dynamic> projectPhotoFiles = []; // Can hold File or String (URL)
  LatLng? _selectedLocation;
  String _locationAddress = '';
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  bool _isLoadingLocation = false;
  late Map<String, Map<String, String>> _workingHours;
  late Map<String, bool> _workingDays;
  late Map<String, String> _dayNames;

  @override
  void initState() {
    super.initState();
    _dayNames = ProviderUtils.getDayNames();
    _workingDays = ProviderUtils.initializeWorkingDays();
    _workingHours = ProviderUtils.initializeWorkingHours();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        if (mounted) context.go('/'); // Redirect if not logged in
        return;
      }

      Map<String, dynamic>? providerData;
      if (widget.initialProviderData != null) {
        providerData = widget.initialProviderData;
      } else {
        final doc = await FirebaseFirestore.instance.collection('providers').doc(userId).get();
        providerData = doc.data();
      }

      if (providerData != null) {
        _workingAreaController.text = providerData['workingArea'] ?? '';
        projectPhotoFiles = List<dynamic>.from(providerData['projectPhotos'] ?? []);

        final exactLocation = providerData['exactLocation'] as Map<String, dynamic>?;
        if (exactLocation != null) {
          _selectedLocation = LatLng(
            (exactLocation['latitude'] as num).toDouble(),
            (exactLocation['longitude'] as num).toDouble(),
          );
          _locationAddress = exactLocation['address'] ?? '';
          // _updateMarker(_selectedLocation!); // Removed: will be called in onMapCreated
        }

        _workingDays = (providerData['workingDays'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, value as bool),
        ) ?? ProviderUtils.initializeWorkingDays();

        _workingHours = (providerData['workingHours'] as Map<String, dynamic>?)?.map(
          (key, value) => MapEntry(key, Map<String, String>.from(value as Map<String, dynamic>)),
        ) ?? ProviderUtils.initializeWorkingHours();
      }
      debugPrint('DEBUG: providerData[projectPhotos]: ${providerData?['projectPhotos']}');
      debugPrint('DEBUG: projectPhotoFiles after load: $projectPhotoFiles');
      debugPrint('DEBUG: providerData[exactLocation]: ${providerData?['exactLocation']}');
      debugPrint('DEBUG: _selectedLocation after load: $_selectedLocation');
      debugPrint('DEBUG: _locationAddress after load: $_locationAddress');
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context: context, message: 'Erreur de chargement des données: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _workingAreaController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _pickProjectPhoto() async {
    final List<File> images = await ImageUploadUtils.pickMultipleImagesWithOptions(
      context,
      isDarkMode: Theme.of(context).brightness == Brightness.dark,
    );
    if (images.isNotEmpty) {
      setState(() {
        projectPhotoFiles.addAll(images);
      });
    }
  }

  void _removeProjectPhoto(int index) {
    setState(() {
      projectPhotoFiles.removeAt(index);
    });
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      _updateLocation(LatLng(position.latitude, position.longitude));
    } catch (e) {
      CustomSnackbar.showError(context: context, message: 'Erreur de localisation: $e');
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }
  
  Future<void> _updateLocation(LatLng position) async {
    setState(() {
      _selectedLocation = position;
      _isLoadingLocation = true;
    });
    try {
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(position, 15.0));
      _updateMarker(position);
      final address = await ProviderUtils.getAddressFromCoordinates(position);
      setState(() {
        _locationAddress = address;
        _workingAreaController.text = address;
      });
    } catch (e) {
      debugPrint('Error updating location: $e');
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }
  
  void _updateMarker(LatLng point) {
    debugPrint('DEBUG: _updateMarker called with point: $point');
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('selected_location'),
          position: point,
          infoWindow: const InfoWindow(title: 'Selected Location'),
        ),
      };
    });
  }

  Future<void> _selectTime(BuildContext context, String day, String type) async {
    final TimeOfDay initialTime = ProviderUtils.parseTimeString(_workingHours[day]![type]!);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
              onPrimary: Colors.white,
              surface: isDarkMode ? AppColors.darkInputBackground : Colors.white,
              onSurface: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
            dialogBackgroundColor: isDarkMode ? AppColors.darkBackground : Colors.white,
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          ),
        );
      },
    );
    
    if (pickedTime != null) {
      setState(() {
        final formattedHour = pickedTime.hour.toString().padLeft(2, '0');
        final formattedMinute = pickedTime.minute.toString().padLeft(2, '0');
        final timeString = '$formattedHour:$formattedMinute';
        
        if (type == 'start') {
          final endTime = ProviderUtils.parseTimeString(_workingHours[day]!['end']!);
          if (pickedTime.hour > endTime.hour || (pickedTime.hour == endTime.hour && pickedTime.minute >= endTime.minute)) {
            CustomSnackbar.showError(context: context, message: 'L\'heure de début doit être avant l\'heure de fin');
            return;
          }
          if (ProviderUtils.calculateHoursDifference(pickedTime, endTime) > 12) {
            CustomSnackbar.showError(context: context, message: 'Maximum 12 heures de travail par jour');
            return;
          }
        } else if (type == 'end') {
          final startTime = ProviderUtils.parseTimeString(_workingHours[day]!['start']!);
          if (pickedTime.hour < startTime.hour || (pickedTime.hour == startTime.hour && pickedTime.minute <= startTime.minute)) {
            CustomSnackbar.showError(context: context, message: 'L\'heure de fin doit être après l\'heure de début');
            return;
          }
          if (ProviderUtils.calculateHoursDifference(startTime, pickedTime) > 12) {
            CustomSnackbar.showError(context: context, message: 'Maximum 12 heures de travail par jour');
            return;
          }
        }
        _workingHours[day]![type] = timeString;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    LoadingOverlay.show(context, message: 'Sauvegarde des modifications...');

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;

      // Upload new project photos
      List<String> newProjectPhotoUrls = [];
      for (var item in projectPhotoFiles) {
        if (item is File) {
          final url = await ImageUploadUtils.uploadSingleImage(item);
          if (url != null) {
            newProjectPhotoUrls.add(url);
          }
        } else if (item is String) {
          newProjectPhotoUrls.add(item); // Already a URL
        }
      }

      final updatedData = {
        'projectPhotos': newProjectPhotoUrls,
        'exactLocation': {
          'latitude': _selectedLocation!.latitude,
          'longitude': _selectedLocation!.longitude,
          'address': _locationAddress,
        },
        'workingArea': _workingAreaController.text,
        'workingHours': _workingHours,
        'workingDays': _workingDays,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('providers')
          .doc(userId)
          .update(updatedData);

      if (mounted) {
        CustomSnackbar.showSuccess(context: context, message: 'Informations professionnelles mises à jour avec succès!');
        context.pop(); // Go back to profile page
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context: context, message: 'Erreur de mise à jour: $e');
      }
    } finally {
      if (mounted) LoadingOverlay.hide();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildSectionTitle(String title, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Text(
        title,
        style: AppTypography.h4(context).copyWith(
          color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        ),
      ),
    );
  }

  Widget _buildProjectPhotosSection(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ajoutez des photos de vos projets ou de votre logo (minimum 2 photos)',
          style: GoogleFonts.poppins(
            fontSize: 14, 
            color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ImageUploadUtils.buildImagePickerPreview(
          images: projectPhotoFiles,
          onRemoveImage: _removeProjectPhoto,
          onAddImages: _pickProjectPhoto,
          isLoading: false,
          isDarkMode: isDarkMode,
          height: 102, // Reduced from 120 (15% of 120 is 18, 120-18 = 102)
        ),
        if (projectPhotoFiles.length < 2)
          Card(
            elevation: 2,
            color: isDarkMode ? Colors.amber.shade900.withOpacity(0.3) : Colors.amber.shade50,
            margin: const EdgeInsets.only(top: AppSpacing.md),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.amber.shade800,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Ajoutez au moins 2 photos de projets',
                      style: GoogleFonts.poppins(
                        color: Colors.amber.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Card(
          elevation: 2,
          color: isDarkMode ? AppColors.darkInputBackground : Colors.white,
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb,
                      color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Conseils pour de bonnes photos',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildTip('Utilisez une bonne luminosité', isDarkMode),
                _buildTip('Montrez clairement vos projets terminés', isDarkMode),
                _buildTip('Ajoutez votre logo ou bannière professionnelle', isDarkMode),
                _buildTip('Évitez les photos floues ou de mauvaise qualité', isDarkMode),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTip(String text, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle,
            color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
            size: AppSpacing.iconSm,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Définissez votre zone de travail',
          style: GoogleFonts.poppins(
            fontSize: 14, 
            color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          height: 300,
          decoration: BoxDecoration(
            border: Border.all(color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          ),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                child: GoogleMap(
                  mapType: MapType.normal,
                  initialCameraPosition: CameraPosition(
                    target: _selectedLocation ?? const LatLng(36.8065, 10.1815), // Default to Tunis
                    zoom: 13.0,
                  ),
                  onMapCreated: (GoogleMapController controller) {
                    _mapController = controller;
                    if (_selectedLocation != null) {
                      _updateMarker(_selectedLocation!);
                      // Animate camera to selected location on map creation
                      _mapController?.animateCamera(
                        CameraUpdate.newLatLngZoom(_selectedLocation!, 15.0),
                      );
                    }
                  },
                  onTap: _updateLocation,
                  markers: _markers,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),
              ),
              Positioned(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
                child: FloatingActionButton(
                  mini: true,
                  onPressed: _getCurrentLocation,
                  tooltip: 'Ma position actuelle',
                  backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.my_location),
                ),
              ),
              if (_isLoadingLocation)
                Container(
                  color: Colors.black.withOpacity(0.3),
                  child: const Center(
                    child: CircularProgressIndicator(),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_locationAddress.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isDarkMode ? AppColors.darkInputBackground : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              border: Border.all(color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Adresse sélectionnée:',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _locationAddress,
                  style: GoogleFonts.poppins(
                    color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        CustomTextField(
          controller: _workingAreaController,
          labelText: 'Zone géographique d\'intervention',
          hintText: 'Ex: Tunis, La Marsa, Sousse...',
          validator: (value) => value?.isEmpty ?? true ? 'Champ requis' : null,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Indiquez les zones où vous êtes prêt à vous déplacer pour vos services',
          style: GoogleFonts.poppins(
            fontStyle: FontStyle.italic,
            fontSize: 12,
            color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildWorkingHoursSection(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Définissez vos heures de disponibilité',
          style: GoogleFonts.poppins(
            fontSize: 14, 
            color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Card(
          elevation: 2,
          color: isDarkMode ? AppColors.darkInputBackground : Colors.white,
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Jours de travail', 
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, 
                    fontSize: 16,
                    color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 3,
                  ),
                  itemCount: _workingDays.length,
                  itemBuilder: (context, index) {
                    final day = _workingDays.keys.elementAt(index);
                    final isWorkingDay = _workingDays[day]!;
                    return CheckboxListTile(
                      title: Text(
                        _dayNames[day]!, 
                        style: GoogleFonts.poppins(
                          color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                      value: isWorkingDay,
                      activeColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                      onChanged: (value) {
                        setState(() {
                          _workingDays[day] = value ?? false;
                        });
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        ...(_workingDays.entries.where((entry) => entry.value).map((entry) {
          final day = entry.key;
          return Card(
            elevation: 2,
            color: isDarkMode ? AppColors.darkInputBackground : Colors.white,
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Horaires pour ${_dayNames[day]}',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectTime(context, day, 'start'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                              ),
                              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Heure de début',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  _workingHours[day]!['start']!,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: InkWell(
                          onTap: () => _selectTime(context, day, 'end'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                              ),
                              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Heure de fin',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  _workingHours[day]!['end']!,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
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
              ),
            ),
          );
        }).toList()),
        if (!_workingDays.values.any((isWorking) => isWorking))
          Card(
            elevation: 2,
            color: isDarkMode ? Colors.red.shade900.withOpacity(0.3) : Colors.red.shade50,
            margin: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.md),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Veuillez sélectionner au moins un jour de travail',
                      style: GoogleFonts.poppins(
                        color: Colors.red.shade400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? Colors.black : Colors.white, // Consistent with PrestataireHomePage
      appBar: AppBar(
        title: Text(
          'Modifier Infos Pro',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        backgroundColor: isDarkMode ? Colors.black : Colors.white,
        foregroundColor: isDarkMode ? Colors.white : Colors.black87,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
              ),
            )
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppSpacing.lg), // Added spacing below AppBar
                          _buildSectionTitle('Photos de projets', isDarkMode),
                          _buildProjectPhotosSection(isDarkMode),
                          const SizedBox(height: AppSpacing.sectionSpacing),
                          _buildSectionTitle('Localisation', isDarkMode),
                          _buildLocationSection(isDarkMode),
                          const SizedBox(height: AppSpacing.sectionSpacing),
                          _buildSectionTitle('Horaires de travail', isDarkMode),
                          _buildWorkingHoursSection(isDarkMode),
                          const SizedBox(height: AppSpacing.sectionSpacing),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
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
                    child: Center( // Center the button
                      child: SizedBox( // Constrain button width
                        width: MediaQuery.of(context).size.width * 0.85, // 85% of screen width
                        child: CustomButton(
                          text: 'Sauvegarder les modifications',
                          onPressed: _saveChanges,
                          isLoading: _isLoading,
                          backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                          textColor: Colors.white,
                          height: AppSpacing.buttonLarge,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
