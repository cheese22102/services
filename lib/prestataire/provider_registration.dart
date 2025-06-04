import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../front/app_colors.dart';
import 'models/provider_models.dart';
import 'utils/provider_utils.dart';
import '../front/custom_button.dart';
import '../front/custom_text_field.dart';
import '../utils/cloudinary_service.dart';
import '../utils/image_upload_utils.dart'; // Import the new utility
import '../front/custom_app_bar.dart';
import '../front/app_spacing.dart';
import '../front/app_typography.dart';
import '../front/custom_snackbar.dart';
import '../front/loading_overlay.dart'; // Import LoadingOverlay

class ServiceItem {
  final String name;
  final String? imageUrl;

  ServiceItem({required this.name, this.imageUrl});
}

class CertificationInput {
  final TextEditingController nameController;
  File? file; // For new uploads

  CertificationInput({required this.nameController, this.file});

  void dispose() {
    nameController.dispose();
  }
}

class ProviderRegistrationForm extends StatefulWidget {
  final Map<String, dynamic>? initialData; // New: Optional initial data

  const ProviderRegistrationForm({super.key, this.initialData});

  @override
  State<ProviderRegistrationForm> createState() => _ProviderRegistrationFormState();
}

class _ProviderRegistrationFormState extends State<ProviderRegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _pageController = PageController();
  int _currentPage = 0;
  final int _totalSteps = 6;
  
  // Controllers
  final _bioController = TextEditingController();
  final _workingAreaController = TextEditingController();
  Map<String, TextEditingController> _experienceControllers = {}; // New: Map for experience controllers
  
  // Form data
  List<ServiceItem> selectedServices = [];
  List<Experience> experiences = [];
  Map<String, CertificationInput> _certificationInputs = {}; // New: Map for certification inputs
  File? idCardFile; // For new upload
  String? idCardUrl; // For existing URL
  File? selfieWithIdFile; // For new upload
  String? selfieWithIdUrl; // For existing URL
  File? patenteFile; // For new upload
  String? patenteUrl; // For existing URL
  List<dynamic> projectPhotoFiles = []; // Changed to dynamic to hold File or String (URL)

  List<ServiceItem> availableServices = [];
  
  // Map functionality
  LatLng? _selectedLocation;
  String _locationAddress = '';
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  bool _isLoadingLocation = false;
  
  // Working hours
  late Map<String, Map<String, String>> _workingHours;
  late Map<String, bool> _workingDays;
  late Map<String, String> _dayNames;

  @override
  void initState() {
    super.initState();
    _loadServices();
    _dayNames = ProviderUtils.getDayNames();
    // Initialize working days and hours
    _workingDays = ProviderUtils.initializeWorkingDays();
    _workingHours = ProviderUtils.initializeWorkingHours();
    
    // Load initial data if provided
    if (widget.initialData != null) {
      _prefillForm(widget.initialData!);
    }

    // Initialize experience controllers for initially selected services (if any)
    _updateExperienceControllers();
    // Initialize certification inputs for initially selected services (if any)
    _updateCertificationInputs();
  }

  void _prefillForm(Map<String, dynamic> data) {
    _bioController.text = data['bio'] ?? '';
    _workingAreaController.text = data['workingArea'] ?? '';

    // Prefill experiences
    final List<dynamic> experienceData = data['experiences'] ?? [];
    for (var exp in experienceData) {
      final serviceName = exp['service'] as String;
      final int years = exp['years'] as int? ?? 0; // Years are now stored as int
      String experienceRangeString = '';
      switch (years) {
        case 1:
          experienceRangeString = '<1-1';
          break;
        case 2:
          experienceRangeString = '2-3';
          break;
        case 3:
          experienceRangeString = '3-4';
          break;
        case 5:
          experienceRangeString = '5+';
          break;
        default:
          experienceRangeString = '';
      }
      _experienceControllers[serviceName] = TextEditingController(text: experienceRangeString);
    }

    // Prefill certifications
    final List<String> certNames = List<String>.from(data['certifications'] ?? []);
    for (int i = 0; i < certNames.length; i++) {
      final String certName = certNames[i];
      _certificationInputs[certName] = CertificationInput(
        nameController: TextEditingController(text: certName),
        file: null, // Files cannot be prefilled from URLs directly, user has to re-upload
      );
    }

    // Prefill image URLs for display (not File objects)
    idCardUrl = data['idCardUrl'] as String?;
    selfieWithIdUrl = data['selfieWithIdUrl'] as String?;
    patenteUrl = data['patenteUrl'] as String?;
    projectPhotoFiles = List<dynamic>.from(data['projectPhotos'] ?? []); // Prefill with URLs

    // Prefill location
    final exactLocation = data['exactLocation'] as Map<String, dynamic>?;
    if (exactLocation != null) {
      _selectedLocation = LatLng(
        exactLocation['latitude'] as double,
        exactLocation['longitude'] as double,
      );
      _locationAddress = exactLocation['address'] as String;
      _workingAreaController.text = _locationAddress;
      _updateMarker(_selectedLocation!); // Update marker on map
    }

    // Prefill working hours and days
    // Explicitly cast values to bool to avoid _TypeError
    _workingDays = (data['workingDays'] as Map<String, dynamic>?)?.map(
      (key, value) => MapEntry(key, value as bool),
    ) ?? ProviderUtils.initializeWorkingDays();

    // Explicitly cast values to Map<String, String> to avoid _TypeError
    _workingHours = (data['workingHours'] as Map<String, dynamic>?)?.map(
      (key, value) => MapEntry(key, Map<String, String>.from(value as Map<String, dynamic>)),
    ) ?? ProviderUtils.initializeWorkingHours();

    // Trigger UI update
    setState(() {}); 
  }

  // New method to manage experience controllers based on selected services
  void _updateExperienceControllers() {
    final newControllers = <String, TextEditingController>{};
    for (var serviceItem in selectedServices) {
      // Reuse existing controller if it exists, otherwise create a new one
      newControllers[serviceItem.name] = _experienceControllers[serviceItem.name] ?? TextEditingController();
    }
    // Dispose controllers that are no longer needed
    _experienceControllers.forEach((serviceName, controller) {
      if (!newControllers.containsKey(serviceName)) {
        controller.dispose();
      }
    });
    _experienceControllers = newControllers;
  }

  // New method to manage certification inputs based on selected services
  void _updateCertificationInputs() {
    final newInputs = <String, CertificationInput>{};
    for (var serviceItem in selectedServices) {
      // Reuse existing input if it exists, otherwise create a new one
      newInputs[serviceItem.name] = _certificationInputs[serviceItem.name] ??
          CertificationInput(nameController: TextEditingController());
    }
    // Dispose inputs that are no longer needed
    _certificationInputs.forEach((serviceName, input) {
      if (!newInputs.containsKey(serviceName)) {
        input.dispose();
      }
    });
    _certificationInputs = newInputs;
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bioController.dispose();
    _workingAreaController.dispose();
    _experienceControllers.forEach((key, controller) => controller.dispose()); // Dispose all experience controllers
    _certificationInputs.forEach((key, input) => input.dispose()); // Dispose all certification inputs
    super.dispose();
  }

  Future<void> _loadServices() async {
    final snapshot = await FirebaseFirestore.instance.collection('services').get();
    setState(() {
      availableServices = snapshot.docs.map((doc) {
        final data = doc.data();
        return ServiceItem(
          name: data['name'] as String? ?? 'Unknown Service',
          imageUrl: data['imageUrl'] as String?,
        );
      }).toList();

      // If initial data was provided, and services are now loaded, prefill selected services
      if (widget.initialData != null && selectedServices.isEmpty) {
        final List<String> serviceNames = List<String>.from(widget.initialData!['services'] ?? []);
        selectedServices = availableServices.where((service) => serviceNames.contains(service.name)).toList();
        _updateExperienceControllers();
        _updateCertificationInputs();
      }
    });
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

  // Add method to remove project photo
  void _removeProjectPhoto(int index) {
    setState(() {
      projectPhotoFiles.removeAt(index);
    });
  }

  // Add confirmation dialog
  Future<bool> _showConfirmationDialog() async {
    bool confirm = false;
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Confirmation',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'En confirmant ces informations, certaines d\'entre elles ne pourront plus être modifiées ultérieurement. Êtes-vous sûr de vouloir continuer?',
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Annuler',
                style: GoogleFonts.poppins(
                  color: Colors.grey,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                confirm = true;
                Navigator.of(context).pop();
              },
              child: Text(
                'Confirmer',
                style: GoogleFonts.poppins(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
    return confirm;
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    
    try {
      // Check location permissions
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
      
      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      // Update map and address
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
      // Move map to selected position
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(position, 15.0),
      );
      _updateMarker(position);
      
      // Get address from coordinates
      final address = await ProviderUtils.getAddressFromCoordinates(position);
      
      setState(() {
        _locationAddress = address;
        _workingAreaController.text = address;
      });
    } catch (e) {
      print('Error updating location: $e');
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }
  
  void _updateMarker(LatLng point) {
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

  Future<void> _pickImage(ImageSource source, Function(File) onImagePicked) async {
    final pickedFile = await _picker.pickImage(source: source);
    if (pickedFile != null) {
      onImagePicked(File(pickedFile.path));
    }
  }

  void _showImageSourceOptions(BuildContext context, Function(File) onImagePicked) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? AppColors.darkInputBackground : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Choisir une source',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
              ),
              const Divider(),
              ListTile(
                leading: Icon(
                  Icons.photo_library,
                  color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                ),
                title: Text(
                  'Galerie',
                  style: GoogleFonts.poppins(
                    color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.gallery, onImagePicked);
                },
              ),
              ListTile(
                leading: Icon(
                  Icons.camera_alt,
                  color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                ),
                title: Text(
                  'Appareil photo',
                  style: GoogleFonts.poppins(
                    color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickImage(ImageSource.camera, onImagePicked);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickIdCard() async {
    _showImageSourceOptions(context, (file) {
      setState(() {
        idCardFile = file;
      });
    });
  }

  Future<void> _pickSelfieWithId() async {
    _showImageSourceOptions(context, (file) {
      setState(() {
        selfieWithIdFile = file;
      });
    });
  }

  Future<void> _pickPatente() async {
    _showImageSourceOptions(context, (file) {
      setState(() {
        patenteFile = file;
      });
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
        
          // If setting start time, ensure it's before end time
          if (type == 'start') {
            final endTime = ProviderUtils.parseTimeString(_workingHours[day]!['end']!);
            if (pickedTime.hour > endTime.hour || 
                (pickedTime.hour == endTime.hour && pickedTime.minute >= endTime.minute)) {
              CustomSnackbar.showError(context: context, message: 'L\'heure de début doit être avant l\'heure de fin');
              return;
            }
            
            // Check if total hours would exceed 12
            if (ProviderUtils.calculateHoursDifference(pickedTime, endTime) > 12) {
              CustomSnackbar.showError(context: context, message: 'Maximum 12 heures de travail par jour');
              return;
            }
          } 
        // If setting end time, ensure it's after start time
        else if (type == 'end') {
          final startTime = ProviderUtils.parseTimeString(_workingHours[day]!['start']!);
          if (pickedTime.hour < startTime.hour || 
              (pickedTime.hour == startTime.hour && pickedTime.minute <= startTime.minute)) {
            CustomSnackbar.showError(context: context, message: 'L\'heure de fin doit être après l\'heure de début');
            return;
          }
          
          // Check if total hours would exceed 12
          if (ProviderUtils.calculateHoursDifference(startTime, pickedTime) > 12) {
            CustomSnackbar.showError(context: context, message: 'Maximum 12 heures de travail par jour');
            return;
          }
        }
        
        _workingHours[day]![type] = timeString;
      });
    }
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

    bool _validateCurrentPage() {
    switch (_currentPage) {
      case 0: // Services page
        if (selectedServices.isEmpty) {
          CustomSnackbar.showError(context: context, message: 'Sélectionnez au moins un service');
          return false;
        }
        return true;
      case 1: // Professional info page
        // Validate years of experience for each selected service
        for (var serviceItem in selectedServices) {
          final controller = _experienceControllers[serviceItem.name];
          if (controller == null || controller.text.isEmpty) {
            CustomSnackbar.showError(context: context, message: 'Veuillez sélectionner les années d\'expérience pour ${serviceItem.name}');
            return false;
          }
        }
        // Validate certifications for each selected service
        for (var serviceItem in selectedServices) { // Changed to serviceItem
          final certificationInput = _certificationInputs[serviceItem.name]; // Use serviceItem.name
          if (certificationInput == null || certificationInput.nameController.text.isEmpty) {
            CustomSnackbar.showError(context: context, message: 'Veuillez entrer le nom de la certification pour ${serviceItem.name}'); // Use serviceItem.name
            return false;
          }
          if (certificationInput.file == null) {
            CustomSnackbar.showError(context: context, message: 'Veuillez ajouter une photo pour la certification de ${serviceItem.name}'); // Use serviceItem.name
            return false;
          }
        }
        return _formKey.currentState?.validate() ?? false;
      case 2: // Documents page
        if (idCardFile == null) {
          CustomSnackbar.showError(context: context, message: 'Photo de carte d\'identité requise');
          return false;
        }
        if (selfieWithIdFile == null) {
          CustomSnackbar.showError(context: context, message: 'Selfie avec carte d\'identité requis');
          return false;
        }
        return true;
      case 3: // Project photos page
        if (projectPhotoFiles.length < 2) {
          CustomSnackbar.showError(context: context, message: 'Ajoutez au moins 2 photos de projets');
          return false;
        }
        return true;
      case 4: // Location page
        if (_selectedLocation == null) {
          CustomSnackbar.showError(context: context, message: 'Veuillez sélectionner votre localisation sur la carte');
          return false;
        }
        return _formKey.currentState?.validate() ?? false;
      case 5: // Working hours page
        if (!_workingDays.values.any((isWorking) => isWorking)) {
          CustomSnackbar.showError(context: context, message: 'Sélectionnez au moins un jour de travail');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

    Future<void> _submitForm() async {
    if (!_validateCurrentPage()) return;
    
    // Show confirmation dialog
    bool confirmed = await _showConfirmationDialog();
    if (!confirmed) return;
    
    LoadingOverlay.show(context); // Show loading overlay

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;

      // Upload ID Card
      final idCardUrlToSave = idCardFile != null ? await CloudinaryService.uploadImage(idCardFile!) : (widget.initialData?['idCardUrl'] as String?);
      if (idCardUrlToSave == null) throw Exception("Échec upload pièce d'identité");
      
      // Upload Selfie with ID
      final selfieWithIdUrlToSave = selfieWithIdFile != null ? await CloudinaryService.uploadImage(selfieWithIdFile!) : (widget.initialData?['selfieWithIdUrl'] as String?);
      if (selfieWithIdUrlToSave == null) throw Exception("Échec upload selfie avec pièce d'identité");

      // Upload project photos
      List<String> finalProjectPhotoUrls = [];
      for (var item in projectPhotoFiles) {
        if (item is File) {
          final url = await ImageUploadUtils.uploadSingleImage(item);
          if (url != null) {
            finalProjectPhotoUrls.add(url);
          }
        } else if (item is String) {
          finalProjectPhotoUrls.add(item); // Already a URL
        }
      }
      if (finalProjectPhotoUrls.isEmpty && projectPhotoFiles.isNotEmpty) {
        throw Exception("Échec de l'upload des photos de projets");
      }

      // Upload Patente (optional)
      String? patenteUrlToSave;
      if (patenteFile != null) {
        patenteUrlToSave = await ImageUploadUtils.uploadSingleImage(patenteFile!);
      } else {
        patenteUrlToSave = widget.initialData?['patenteUrl'] as String?;
      }

      // Upload Certifications
      List<String> certificationNames = [];
      List<String> certificationUrls = [];
      for (var entry in _certificationInputs.entries) {
        final input = entry.value;
        if (input.nameController.text.isNotEmpty) { // Check if name is not empty
          if (input.file != null) { // If new file is provided, upload it
            final url = await ImageUploadUtils.uploadSingleImage(input.file!);
            if (url != null) {
              certificationNames.add(input.nameController.text);
              certificationUrls.add(url);
            }
          } else { // If no new file, try to use existing URL from initialData
            final initialCertFiles = List<String>.from(widget.initialData?['certificationFiles'] ?? []);
            final initialCertNames = List<String>.from(widget.initialData?['certifications'] ?? []);
            
            // Find the URL for this certification name from initial data
            int initialIndex = initialCertNames.indexOf(input.nameController.text);
            if (initialIndex != -1 && initialIndex < initialCertFiles.length) {
              certificationNames.add(input.nameController.text);
              certificationUrls.add(initialCertFiles[initialIndex]);
            }
          }
        }
      }

      // Create experiences from collected data
      final experiences = _experienceControllers.entries.map((entry) {
        int yearsValue;
        switch (entry.value.text) {
          case '<1-1':
            yearsValue = 1;
            break;
          case '2-3':
            yearsValue = 2;
            break;
          case '3-4':
            yearsValue = 3;
            break;
          case '5+':
            yearsValue = 5;
            break;
          default:
            yearsValue = 0; // Fallback for unexpected values
        }
        return Experience(
          service: entry.key,
          years: yearsValue,
        );
      }).toList();

      // Create provider data with only the required fields
      final providerData = {
        'userId': userId,
        'services': selectedServices.map((s) => s.name).toList(), // Convert ServiceItem to String
        'experiences': experiences.map((e) => e.toMap()).toList(),
        'certifications': certificationNames, // Use the new list of names
        'certificationFiles': certificationUrls, // Use the new list of URLs
        'bio': _bioController.text,
        'idCardUrl': idCardUrlToSave, // Use the uploaded URL or existing
        'selfieWithIdUrl': selfieWithIdUrlToSave, // Use the uploaded URL or existing
        'patenteUrl': patenteUrlToSave, // Use the uploaded URL or existing
        'status': 'pending',
        'submissionDate': FieldValue.serverTimestamp(),
        'projectPhotos': finalProjectPhotoUrls, // Use the final list of URLs
        // Add location data
        'exactLocation': {
          'latitude': _selectedLocation!.latitude,
          'longitude': _selectedLocation!.longitude,
          'address': _locationAddress,
        },
        'workingArea': _workingAreaController.text,
        // Add working hours data
        'workingHours': _workingHours,
        'workingDays': _workingDays,
      };

      // If this is a resubmission of a rejected application, remove rejection fields
      if (widget.initialData?['status'] == 'rejected') {
        providerData['rejectionDate'] = FieldValue.delete();
        providerData['rejectionReason'] = FieldValue.delete();
      }

      // Create or update provider in Firestore, merging with existing data
      await FirebaseFirestore.instance
          .collection('providers')
          .doc(userId)
          .set(providerData, SetOptions(merge: true));

      if (mounted) {
        CustomSnackbar.showSuccess(
          context: context,
          message: 'Demande soumise avec succès. En attente de validation.',
        );
        context.go('/prestataireHome');
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.showError(context: context, message: 'Erreur: $e');
      }
    } finally {
      LoadingOverlay.hide(); // Hide loading overlay
    }
  }

  // Helper method to build section headers

  Widget _buildServicesPage() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choisissez les services que vous proposez à vos clients (1-3)',
            style: GoogleFonts.poppins(
              fontSize: 14, 
              color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 24),
          
          if (availableServices.isEmpty)
            const Center(child: CircularProgressIndicator())
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, // 3 items per row
                childAspectRatio: 0.8, // Adjust aspect ratio as needed
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: availableServices.length,
              itemBuilder: (context, index) {
                final serviceItem = availableServices[index];
                final isSelected = selectedServices.any((s) => s.name == serviceItem.name); // Check by name
                
                return _buildServiceSelectionItem(
                  context,
                  serviceItem,
                  isSelected,
                  isDarkMode,
                  (selected) {
                    setState(() {
                      if (selected) {
                        if (selectedServices.length < 3) { // Limit to 3 services
                          selectedServices.add(serviceItem);
                        } else {
                          CustomSnackbar.showError(context: context, message: 'Vous ne pouvez sélectionner que 3 services maximum.');
                        }
                      } else {
                        selectedServices.removeWhere((s) => s.name == serviceItem.name); // Remove by name
                      }
                      _updateExperienceControllers();
                      _updateCertificationInputs();
                    });
                  },
                );
              },
            ),
          
          if (selectedServices.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.red.shade900.withOpacity(0.3) : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red.shade400,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Veuillez sélectionner au moins un service',
                        style: GoogleFonts.poppins(
                          color: Colors.red.shade400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          
          const SizedBox(height: 16),
          
          if (selectedServices.isNotEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Services sélectionnés:',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                ...selectedServices.map((serviceItem) => Padding( // Changed to serviceItem
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        serviceItem.name, // Use serviceItem.name
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ],
            ),
        ],
      ),
    );
  }
    Widget _buildProfessionalInfoPage() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Parlez-nous de votre expérience et vos compétences',
            style: GoogleFonts.poppins(
              fontSize: 14, 
              color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 24),
          
          CustomTextField(
            controller: _bioController,
            labelText: 'Biographie professionnelle',
            hintText: 'Décrivez votre parcours et vos compétences...',
            validator: (value) => value?.isEmpty ?? true ? 'Champ requis' : null,
          ),
          
          const SizedBox(height: 16),
          
          const SizedBox(height: 16),
          
          // Dynamic years of experience input for each selected service
          ...(selectedServices.isNotEmpty
              ? [
                  Card(
                    elevation: 2,
                    color: isDarkMode ? AppColors.darkInputBackground : Colors.white,
                    margin: const EdgeInsets.only(bottom: 24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Années d\'expérience par service',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...selectedServices.map((serviceItem) {
                            final List<String> experienceRanges = ['>1-1', '2-3', '3-4', '5+'];
                            final String? selectedRange = _experienceControllers[serviceItem.name]?.text;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Années d\'expérience pour ${serviceItem.name}:',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8.0, // horizontal spacing
                                    runSpacing: 8.0, // vertical spacing
                                    children: experienceRanges.map((range) {
                                      final bool isSelected = selectedRange == range;
                                      return ElevatedButton(
                                        onPressed: () {
                                          setState(() {
                                            _experienceControllers[serviceItem.name] = TextEditingController(text: range);
                                          });
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isSelected
                                              ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                                              : (isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200),
                                          foregroundColor: isSelected
                                              ? Colors.white
                                              : (isDarkMode ? Colors.white70 : Colors.black87),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            side: BorderSide(
                                              color: isSelected
                                                  ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                                                  : (isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300),
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        ),
                                        child: Text(
                                          range,
                                          style: GoogleFonts.poppins(fontSize: 14),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                ]
              : [
                  const SizedBox(height: 24), // Spacing if no services selected
                ]),
          
          // Dynamic certifications input for each selected service
          ...(selectedServices.isNotEmpty
              ? [
                  Card(
                    elevation: 2,
                    color: isDarkMode ? AppColors.darkInputBackground : Colors.white,
                    margin: const EdgeInsets.only(bottom: 24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Certifications par service (optionnel)', // Updated title
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...selectedServices.map((serviceItem) { // Changed to serviceItem
                            // Safely get the certification input, providing a dummy if null
                            final currentInput = _certificationInputs[serviceItem.name] ?? CertificationInput(nameController: TextEditingController(text: 'ERROR: Missing controller for ${serviceItem.name}')); // Use serviceItem.name
                            
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: Row( // Use Row to place text field and button side-by-side
                                children: [
                                  Expanded(
                                    child: CustomTextField(
                                      controller: currentInput.nameController,
                                      labelText: 'Certification pour ${serviceItem.name}', // Use serviceItem.name
                                      hintText: 'Nom de la certification',
                                      validator: (value) => null, // Validation will be in _validateCurrentPage
                                    ),
                                  ),
                                  const SizedBox(width: 8), // Spacing between text field and button
                                  // Small button with image+ icon
                                  SizedBox(
                                    width: 48, // Fixed width for the button
                                    height: 48, // Fixed height for the button
                                    child: ElevatedButton(
                                      onPressed: () => _showImageSourceOptions(context, (file) {
                                        setState(() {
                                          currentInput.file = file; // Assign file to the current input
                                        });
                                      }),
                                      style: ElevatedButton.styleFrom(
                                        padding: EdgeInsets.zero, // Remove default padding
                                        backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                      child: Icon(
                                        currentInput.file != null ? Icons.image : Icons.add_photo_alternate, // Change icon if image is picked
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  ),
                                  // Display selected image thumbnail if available
                                  if (currentInput.file != null) ...[
                                    const SizedBox(width: 8),
                                    Stack(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(8),
                                            image: DecorationImage(
                                              image: FileImage(currentInput.file!), // Safe due to outer if
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: -8,
                                          right: -8,
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                currentInput.file = null; // Set file to null
                                              });
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: const BoxDecoration(
                                                color: Colors.black54,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                size: 16,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                    ),
                  ),
                ]
              : [
                  const SizedBox(height: 24), // Spacing if no services selected
                ]),
        ],
      ),
    );
  }

  Widget _buildDocumentsPage() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nous avons besoin de vérifier votre identité',
            style: GoogleFonts.poppins(
              fontSize: 14, 
              color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 24),
          
          // ID Card
          Card(
            elevation: 2,
            color: isDarkMode ? AppColors.darkInputBackground : Colors.white,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.badge,
                        color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Carte d\'identité *',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Prenez une photo claire de votre carte d\'identité',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (idCardFile != null)
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              idCardFile!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              idCardFile = null;
                            });
                          },
                        ),
                      ],
                    )
                  else if (idCardUrl != null && idCardUrl!.isNotEmpty)
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              idCardUrl!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              idCardUrl = null; // Clear URL if user wants to re-upload
                            });
                          },
                        ),
                      ],
                    )
                  else
                    CustomButton(
                      text: 'Ajouter une photo',
                      onPressed: _pickIdCard,
                      backgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
                      textColor: isDarkMode ? Colors.white : Colors.black87,
                    ),
                ],
              ),
            ),
          ),
          
          // Selfie with ID
          Card(
            elevation: 2,
            color: isDarkMode ? AppColors.darkInputBackground : Colors.white,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.face,
                        color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Selfie avec carte d\'identité *',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Prenez un selfie en tenant votre carte d\'identité',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (selfieWithIdFile != null)
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              selfieWithIdFile!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              selfieWithIdFile = null;
                            });
                          },
                        ),
                      ],
                    )
                  else if (selfieWithIdUrl != null && selfieWithIdUrl!.isNotEmpty)
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              selfieWithIdUrl!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              selfieWithIdUrl = null; // Clear URL if user wants to re-upload
                            });
                          },
                        ),
                      ],
                    )
                  else
                    CustomButton(
                      text: 'Ajouter une photo',
                      onPressed: _pickSelfieWithId,
                      backgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
                      textColor: isDarkMode ? Colors.white : Colors.black87,
                    ),
                ],
              ),
            ),
          ),
          
          // Patente (optional)
          Card(
            elevation: 2,
            color: isDarkMode ? AppColors.darkInputBackground : Colors.white,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.description,
                        color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Patente (optionnel)',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Si vous avez une patente, ajoutez-la ici',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (patenteFile != null)
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              patenteFile!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              patenteFile = null;
                            });
                          },
                        ),
                      ],
                    )
                  else if (patenteUrl != null && patenteUrl!.isNotEmpty)
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Container(
                          height: 200,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              patenteUrl!,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              patenteUrl = null; // Clear URL if user wants to re-upload
                            });
                          },
                        ),
                      ],
                    )
                  else
                    CustomButton(
                      text: 'Ajouter une photo',
                      onPressed: _pickPatente,
                      backgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300,
                      textColor: isDarkMode ? Colors.white : Colors.black87,
                    ),
                ],
              ),
            ),
          ),
          
          Text(
            '* Documents obligatoires',
            style: GoogleFonts.poppins(
              fontStyle: FontStyle.italic,
              fontSize: 12,
              color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildLocationPage() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Définissez votre zone de travail',
            style: GoogleFonts.poppins(
              fontSize: 14, 
              color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 24),
          
          // Map widget
          Container(
            height: 300,
            decoration: BoxDecoration(
              border: Border.all(color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
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
                  top: 10,
                  right: 10,
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
          
          const SizedBox(height: 16),
          
          if (_locationAddress.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode ? AppColors.darkInputBackground : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
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
                  const SizedBox(height: 4),
                  Text(
                    _locationAddress,
                    style: GoogleFonts.poppins(
                      color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),
          
          CustomTextField(
            controller: _workingAreaController,
            labelText: 'Zone géographique d\'intervention',
            hintText: 'Ex: Tunis, La Marsa, Sousse...',
            validator: (value) => value?.isEmpty ?? true ? 'Champ requis' : null,
          ),
          
          const SizedBox(height: 8),
          Text(
            'Indiquez les zones où vous êtes prêt à vous déplacer pour vos services',
            style: GoogleFonts.poppins(
              fontStyle: FontStyle.italic,
              fontSize: 12,
              color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // Add this new method for the project photos page
  Widget _buildProjectPhotosPage() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ajoutez des photos de vos projets ou de votre logo (minimum 2 photos)',
            style: GoogleFonts.poppins(
              fontSize: 14, 
              color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 24),
          
          ImageUploadUtils.buildImagePickerPreview(
            images: projectPhotoFiles,
            onRemoveImage: _removeProjectPhoto,
            onAddImages: _pickProjectPhoto,
            isLoading: false, // No longer using local _isLoading
            isDarkMode: isDarkMode,
            height: 120, // Adjust height as needed
          ),

          // Warning if not enough photos
          if (projectPhotoFiles.length < 2)
            Card(
              elevation: 2,
              color: isDarkMode ? Colors.amber.shade900.withOpacity(0.3) : Colors.amber.shade50,
              margin: const EdgeInsets.only(top: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.amber.shade800,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ajoutez au moins 2 photos de projets', // Corrected message
                        style: GoogleFonts.poppins(
                          color: Colors.amber.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 24),

          // Tips for good photos
          Card(
            elevation: 2,
            color: isDarkMode ? AppColors.darkInputBackground : Colors.white,
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb,
                        color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                      ),
                      const SizedBox(width: 8),
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
                  const SizedBox(height: 8),
                  _buildTip('Utilisez une bonne luminosité'),
                  _buildTip('Montrez clairement vos projets terminés'),
                  _buildTip('Ajoutez votre logo ou bannière professionnelle'),
                  _buildTip('Évitez les photos floues ou de mauvaise qualité'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildTip(String text) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle,
            color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
            size: 16,
          ),
          const SizedBox(width: 8),
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

  Widget _buildWorkingHoursPage() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Définissez vos heures de disponibilité',
            style: GoogleFonts.poppins(
              fontSize: 14, 
              color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 24),
          
          // Working days selection with improved UI
          Card(
            elevation: 2,
            color: isDarkMode ? AppColors.darkInputBackground : Colors.white,
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
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
                  const SizedBox(height: 8),
                  
                  // Days of week with checkboxes in a grid
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
          
          // Working hours for each selected day
          ...(_workingDays.entries.where((entry) => entry.value).map((entry) {
            final day = entry.key;
            return Card(
              elevation: 2,
              color: isDarkMode ? AppColors.darkInputBackground : Colors.white,
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
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
                    const SizedBox(height: 16),
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
                                borderRadius: BorderRadius.circular(8),
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
                                  const SizedBox(height: 4),
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
                        const SizedBox(width: 16),
                        Expanded(
                          child: InkWell(
                            onTap: () => _selectTime(context, day, 'end'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                                ),
                                borderRadius: BorderRadius.circular(8),
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
                                  const SizedBox(height: 4),
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
              margin: const EdgeInsets.only(top: 16, bottom: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.red.shade400,
                    ),
                    const SizedBox(width: 8),
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
      ),
    );
  }

  // Helper method to get step title
  String _getStepTitle() {
    switch (_currentPage) {
      case 0:
        return 'Services proposés';
      case 1:
        return 'Informations professionnelles';
      case 2:
        return 'Documents d\'identité';
      case 3:
        return 'Photos de projets';
      case 4:
        return 'Localisation';
      case 5:
        return 'Horaires de travail';
      default:
        return '';
    }
  }

    @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Inscription Prestataire',
        showBackButton: true,
      ),
      body: Form( // Removed _isLoading check here
              key: _formKey,
              child: Column(
                children: [
                  // Progress indicator
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                    child: Column(
                      children: [
                        Row(
                          children: List.generate(_totalSteps, (index) {
                            return Expanded(
                              child: Container(
                                height: 4,
                                margin: EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                                decoration: BoxDecoration(
                                  color: index <= _currentPage
                                      ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                                      : (isDarkMode ? Colors.grey.shade800 : Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(AppSpacing.radiusXs),
                                ),
                              ),
                            );
                          }),
                        ),
                        SizedBox(height: AppSpacing.sm),
                        Text(
                          _getStepTitle(),
                          style: AppTypography.h4(context),
                        ),
                      ],
                    ),
                  ),
                  
                  // Page view
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(), // Corrected typo here
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      children: [
                        _buildServicesPage(),
                        _buildProfessionalInfoPage(),
                        _buildDocumentsPage(),
                        _buildProjectPhotosPage(), // Add new page for project photos
                        _buildLocationPage(),
                        _buildWorkingHoursPage(),
                      ],
                    ),
                  ),
                  
                  // ... rest of the build method
            
            // Navigation buttons
            Container(
              padding: const EdgeInsets.all(16),
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
                      text: 'Précédent',
                      onPressed: _previousPage,
                      backgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                      textColor: isDarkMode ? Colors.white : Colors.black87,
                    )
                  else
                    const SizedBox(width: 120),
                    
                  CustomButton( // Removed _isLoading check here
                          text: _currentPage == _totalSteps - 1 ? 'Soumettre' : 'Suivant',
                          onPressed: () {
                            if (_validateCurrentPage()) {
                              if (_currentPage < _totalSteps - 1) {
                                _nextPage();
                              } else {
                                _submitForm();
                              }
                            }
                          },
                          backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                          textColor: Colors.white,
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getServiceIcon(String serviceName) {
    switch (serviceName.toLowerCase()) {
      case 'plomberie':
        return Icons.plumbing;
      case 'électricité':
        return Icons.electrical_services;
      case 'jardinage':
        return Icons.yard;
      case 'ménage':
        return Icons.cleaning_services;
      case 'peinture':
        return Icons.format_paint;
      case 'menuiserie':
        return Icons.handyman;
      case 'informatique':
        return Icons.computer;
      case 'déménagement':
        return Icons.local_shipping;
      case 'réparation':
        return Icons.build;
      default:
        return Icons.miscellaneous_services;
    }
  }

  Widget _buildServiceSelectionItem(
    BuildContext context,
    ServiceItem serviceItem,
    bool isSelected,
    bool isDarkMode,
    Function(bool) onSelected,
  ) {
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;
    final serviceIcon = _getServiceIcon(serviceItem.name);

    return GestureDetector(
      onTap: () {
        onSelected(!isSelected); // Toggle selection
      },
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? (isDarkMode ? AppColors.primaryGreen.withOpacity(0.2) : AppColors.primaryDarkGreen.withOpacity(0.2))
              : (isDarkMode ? AppColors.darkInputBackground : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                : (isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Stack( // Wrap the content in a Stack
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 70, // Define a fixed size for the image container
                  height: 70,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12), // Rounded corners for the image
                    child: serviceItem.imageUrl != null && serviceItem.imageUrl!.isNotEmpty
                        ? Image.network(
                            serviceItem.imageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  strokeWidth: 2.0,
                                  color: primaryColor,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: isDarkMode ? Colors.grey.shade800.withOpacity(0.5) : Colors.grey.shade200,
                              child: Icon(serviceIcon, color: primaryColor, size: 35),
                            ),
                          )
                        : Container(
                            color: isDarkMode ? Colors.grey.shade800.withOpacity(0.5) : Colors.grey.shade200,
                            child: Icon(serviceIcon, color: primaryColor, size: 35),
                          ),
                  ),
                ),
                const SizedBox(height: 8), // Spacing between image and text
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    serviceItem.name,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 12, 
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (isSelected) // Show checkmark if selected
              Positioned(
                top: 4,
                right: 4,
                child: Icon(
                  Icons.check_circle,
                  color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
