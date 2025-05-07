import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../front/app_colors.dart';
import 'models/provider_models.dart';
import 'utils/provider_utils.dart';
import '../front/custom_button.dart';
import '../front/custom_text_field.dart';


class ProviderRegistrationForm extends StatefulWidget {
  const ProviderRegistrationForm({super.key});

  @override
  State<ProviderRegistrationForm> createState() => _ProviderRegistrationFormState();
}

class _ProviderRegistrationFormState extends State<ProviderRegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  final _pageController = PageController();
  int _currentPage = 0;
  
  // Controllers
  final _bioController = TextEditingController();
  final _yearsController = TextEditingController();
  final _certificationController = TextEditingController();
  final _workingAreaController = TextEditingController();
  
  // Form data
  List<String> selectedServices = [];
  List<Experience> experiences = [];
  List<String> certifications = [];
  List<File> certificationFiles = [];
  File? idCardFile;
  File? selfieWithIdFile;
  File? patenteFile;
  List<File> projectPhotoFiles = [];

  bool _isLoading = false;
  List<String> availableServices = [];
  
  // Map functionality
  LatLng? _selectedLocation;
  String _locationAddress = '';
  final MapController _mapController = MapController();
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
  }

  @override
  void dispose() {
    _pageController.dispose();
    _bioController.dispose();
    _yearsController.dispose();
    _certificationController.dispose();
    _workingAreaController.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    final snapshot = await FirebaseFirestore.instance.collection('services').get();
    setState(() {
      availableServices = snapshot.docs.map((doc) => doc['name'] as String).toList();
    });
  }

  Future<void> _pickProjectPhoto() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        projectPhotoFiles.add(File(image.path));
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de localisation: $e')),
      );
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
      _mapController.move(position, 15.0);
      
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

  Future<void> _addCertification() async {
    if (_certificationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer le nom de la certification')),
      );
      return;
    }

    _showImageSourceOptions(context, (file) {
      setState(() {
        certifications.add(_certificationController.text);
        certificationFiles.add(file);
        _certificationController.clear();
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('L\'heure de début doit être avant l\'heure de fin')),
            );
            return;
          }
          
          // Check if total hours would exceed 12
          if (ProviderUtils.calculateHoursDifference(pickedTime, endTime) > 12) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Maximum 12 heures de travail par jour')),
            );
            return;
          }
        } 
        // If setting end time, ensure it's after start time
        else if (type == 'end') {
          final startTime = ProviderUtils.parseTimeString(_workingHours[day]!['start']!);
          if (pickedTime.hour < startTime.hour || 
              (pickedTime.hour == startTime.hour && pickedTime.minute <= startTime.minute)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('L\'heure de fin doit être après l\'heure de début')),
            );
            return;
          }
          
          // Check if total hours would exceed 12
          if (ProviderUtils.calculateHoursDifference(startTime, pickedTime) > 12) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Maximum 12 heures de travail par jour')),
            );
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sélectionnez au moins un service')),
          );
          return false;
        }
        return true;
      case 1: // Professional info page
        return _formKey.currentState?.validate() ?? false;
      case 2: // Documents page
        if (idCardFile == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo de carte d\'identité requise')),
          );
          return false;
        }
        if (selfieWithIdFile == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selfie avec carte d\'identité requis')),
          );
          return false;
        }
        return true;
      case 3: // Project photos page
        if (projectPhotoFiles.length < 2) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ajoutez au moins 2 photos de projets')),
          );
          return false;
        }
        return true;
      case 4: // Location page
        if (_selectedLocation == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Veuillez sélectionner votre localisation sur la carte')),
          );
          return false;
        }
        return _formKey.currentState?.validate() ?? false;
      case 5: // Working hours page
        if (!_workingDays.values.any((isWorking) => isWorking)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sélectionnez au moins un jour de travail')),
          );
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
    
    setState(() => _isLoading = true);

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;

      // Upload ID Card
      final idCardUrl = await ProviderUtils.uploadFileToCloudinary(idCardFile!);
      if (idCardUrl == null) throw Exception("Échec upload pièce d'identité");
      
      // Upload Selfie with ID
      final selfieWithIdUrl = await ProviderUtils.uploadFileToCloudinary(selfieWithIdFile!);
      if (selfieWithIdUrl == null) throw Exception("Échec upload selfie avec pièce d'identité");

      // Upload project photos
      List<String> projectPhotoUrls = [];
      for (var file in projectPhotoFiles) {
        final url = await ProviderUtils.uploadFileToCloudinary(file);
        if (url != null) {
          projectPhotoUrls.add(url);
        }
      }

      // ... rest of the method

      // Upload Patente (optional)
      String? patenteUrl;
      if (patenteFile != null) {
        patenteUrl = await ProviderUtils.uploadFileToCloudinary(patenteFile!);
      }

      // Upload Certifications
      List<String> certificationUrls = [];
      for (var file in certificationFiles) {
        final url = await ProviderUtils.uploadFileToCloudinary(file);
        if (url != null) certificationUrls.add(url);
      }

      // Create experiences from years of experience
      final yearsOfExperience = int.tryParse(_yearsController.text) ?? 0;
      final experiences = selectedServices.map((service) => 
        Experience(
          service: service,
          years: yearsOfExperience,
        )
      ).toList();

      // Create provider data with only the required fields
      final providerData = {
        'userId': userId,
        'services': selectedServices,
        'experiences': experiences.map((e) => e.toMap()).toList(),
        'certifications': certifications,
        'certificationFiles': certificationUrls,
        'bio': _bioController.text,
        'idCardUrl': idCardUrl,
        'selfieWithIdUrl': selfieWithIdUrl,
        'patenteUrl': patenteUrl,
        'status': 'pending',
        'submissionDate': FieldValue.serverTimestamp(),
        'projectPhotos': projectPhotoUrls,
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

      // Create provider in Firestore
      await FirebaseFirestore.instance
          .collection('providers')
          .doc(userId)
          .set(providerData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Demande soumise avec succès. En attente de validation.'),
            duration: Duration(seconds: 3),
          ),
        );
        context.go('/prestataireHome');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Helper method to build section headers
  Widget _buildSectionHeader(String title, String subtitle) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title, 
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold, 
            fontSize: 20,
            color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: GoogleFonts.poppins(
            fontSize: 14, 
            color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildServicesPage() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            'Services proposés', 
            'Choisissez les services que vous proposez à vos clients (1-3)'
          ),
          
          if (availableServices.isEmpty)
            const Center(child: CircularProgressIndicator())
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: availableServices.map((service) {
                final isSelected = selectedServices.contains(service);
                return FilterChip(
                  label: Text(
                    service, 
                    style: GoogleFonts.poppins(
                      color: isSelected 
                        ? Colors.white 
                        : (isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                    ),
                  ),
                  selected: isSelected,
                  checkmarkColor: Colors.white,
                  selectedColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                  backgroundColor: isDarkMode ? AppColors.darkInputBackground : Colors.grey.shade200,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected 
                        ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                        : Colors.transparent,
                    ),
                  ),
                  onSelected: selectedServices.length >= 3 && !isSelected
                      ? null
                      : (selected) {
                          setState(() {
                            if (selected) {
                              selectedServices.add(service);
                            } else {
                              selectedServices.remove(service);
                            }
                          });
                        },
                  showCheckmark: true,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                );
              }).toList(),
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
                ...selectedServices.map((service) => Padding(
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
                        service,
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
          _buildSectionHeader(
            'Informations professionnelles', 
            'Parlez-nous de votre expérience et vos compétences'
          ),
          
          CustomTextField(
            controller: _bioController,
            labelText: 'Biographie professionnelle',
            hintText: 'Décrivez votre parcours et vos compétences...',
            validator: (value) => value?.isEmpty ?? true ? 'Champ requis' : null,
          ),
          
          const SizedBox(height: 16),
          
         const SizedBox(height: 16),
          
          Text(
            'Années d\'expérience',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _buildExperienceButton('1-2 ans', '1'),
              _buildExperienceButton('2-4 ans', '3'),
              _buildExperienceButton('5+ ans', '5'),
              _buildExperienceButton('10+ ans', '10'),
            ],
          ),
          
          const SizedBox(height: 24),
          
          const SizedBox(height: 24),
          
          Text(
            'Certifications (optionnel)',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 16,
              color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  controller: _certificationController,
                  labelText: 'Nom de la certification',
                  hintText: 'Ex: Diplôme, Formation...',
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  Icons.add_circle,
                  color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                  size: 36,
                ),
                onPressed: _addCertification,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          if (certifications.isNotEmpty) ...[
            Text(
              'Certifications ajoutées:',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(certifications.length, (index) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDarkMode ? AppColors.darkInputBackground : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            certifications[index],
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w500,
                              color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Document ajouté',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          certifications.removeAt(index);
                          certificationFiles.removeAt(index);
                        });
                      },
                    ),
                  ],
                ),
              );
            }),
          ],
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
          _buildSectionHeader(
            'Documents d\'identité', 
            'Nous avons besoin de vérifier votre identité'
          ),
          
          // ID Card
          Card(
            elevation: 2,
            color: isDarkMode ? AppColors.darkInputBackground : Colors.white,
            margin: const EdgeInsets.only(bottom: 16),
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
  Widget _buildExperienceButton(String label, String value) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _yearsController.text == value;
    
    return InkWell(
      onTap: () {
        setState(() {
          _yearsController.text = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected 
            ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
            : (isDarkMode ? AppColors.darkInputBackground : Colors.grey.shade200),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
              ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
              : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected 
              ? Colors.white 
              : (isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
          ),
        ),
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
          _buildSectionHeader(
            'Localisation', 
            'Définissez votre zone de travail'
          ),
          
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
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      center: _selectedLocation ?? const LatLng(36.8065, 10.1815), // Default to Tunis
                      zoom: 13.0,
                      onTap: (tapPosition, point) => _updateLocation(point),
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
                              builder: (context) => Icon(
                                Icons.location_on,
                                color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                                size: 40.0,
                              ),
                            ),
                          ],
                        ),
                    ],
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
          _buildSectionHeader(
            'Photos de projets', 
            'Ajoutez des photos de vos projets ou de votre logo (minimum 2 photos)'
          ),
          
          // Grid of photos
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.0,
            ),
            itemCount: projectPhotoFiles.length + 1, // +1 for the add button
            itemBuilder: (context, index) {
              if (index == projectPhotoFiles.length) {
                // Add button
                return InkWell(
                  onTap: _pickProjectPhoto,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.add_photo_alternate,
                        size: 40,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                );
              } else {
                // Photo preview
                return Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: FileImage(projectPhotoFiles[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: InkWell(
                        onTap: () => _removeProjectPhoto(index),
                        child: Container(
                          padding: const EdgeInsets.all(4),
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
                );
              }
            },
          ),
          
          // Warning if not enough photos
          if (projectPhotoFiles.length < 2)
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.amber.shade900.withOpacity(0.3) : Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade300),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.amber.shade800,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Veuillez ajouter au moins 2 photos',
                      style: GoogleFonts.poppins(
                        color: Colors.amber.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 24),
          
          // Tips for good photos
          Card(
            elevation: 2,
            color: isDarkMode ? AppColors.darkInputBackground : Colors.white,
            margin: const EdgeInsets.only(bottom: 16),
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
          _buildSectionHeader(
            'Horaires de travail', 
            'Définissez vos heures de disponibilité'
          ),
          
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
            Container(
              padding: const EdgeInsets.all(16),
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
                      'Veuillez sélectionner au moins un jour de travail',
                      style: GoogleFonts.poppins(
                        color: Colors.red.shade400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

    @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Inscription Prestataire',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  // Progress indicator
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: SmoothPageIndicator(
                      controller: _pageController,
                      count: 6, // Update from 5 to 6 to include project photos page
                      effect: WormEffect(
                        dotHeight: 10,
                        dotWidth: 10,
                        activeDotColor: AppColors.primaryGreen,
                        dotColor: Colors.grey.shade300,
                      ),
                    ),
                  ),
                  
                  // Page view
                  Expanded(
                    child: PageView(
                      controller: _pageController,
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
                color: isDarkMode ? AppColors.darkBackground : Colors.white,
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
                    
                  _isLoading
                      ? const CircularProgressIndicator()
                      : CustomButton(
                          text: _currentPage == 4 ? 'Soumettre' : 'Suivant',
                          onPressed: () {
                            if (_validateCurrentPage()) {
                              if (_currentPage < 4) {
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
}