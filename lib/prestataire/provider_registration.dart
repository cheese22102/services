import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

// Modèle du Prestataire
class Provider {
  final String userId;
  final List<String> services;
  final List<Experience> experiences;
  final List<String> certifications;
  final List<String> certificationFiles;
  final String workingArea;
  final Map<String, double> rateRange;
  final String bio;
  final String idCardUrl;
  final String professionalPhone;
  final String professionalEmail;
  final String professionalAddress;
  final bool isVerified;
  final Timestamp submissionDate;

  Provider({
    required this.userId,
    required this.services,
    required this.experiences,
    required this.certifications,
    required this.certificationFiles,
    required this.workingArea,
    required this.rateRange,
    required this.bio,
    required this.idCardUrl,
    required this.professionalPhone,
    required this.professionalEmail,
    required this.professionalAddress,
    this.isVerified = false,
    required this.submissionDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'services': services,
      'experiences': experiences.map((e) => e.toMap()).toList(),
      'certifications': certifications,
      'certificationFiles': certificationFiles,
      'workingArea': workingArea,
      'rateRange': rateRange,
      'bio': bio,
      'idCardUrl': idCardUrl,
      'professionalPhone': professionalPhone,
      'professionalEmail': professionalEmail,
      'professionalAddress': professionalAddress,
      'isVerified': isVerified,
      'submissionDate': submissionDate,
    };
  }
}

class Experience {
  final String service;
  final int years;
  final String description;

  Experience({
    required this.service,
    required this.years,
    required this.description,
  });

  Map<String, dynamic> toMap() {
    return {
      'service': service,
      'years': years,
      'description': description,
    };
  }
}

class ProviderRegistrationForm extends StatefulWidget {
  const ProviderRegistrationForm({super.key});

  @override
  State<ProviderRegistrationForm> createState() => _ProviderRegistrationFormState();
}

class _ProviderRegistrationFormState extends State<ProviderRegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();
  
  // Controllers
  // Remove the address controller
  final _bioController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _workingAreaController = TextEditingController();
  final _minRateController = TextEditingController();
  final _maxRateController = TextEditingController();
  final _certificationController = TextEditingController();

  // Form data
  List<String> selectedServices = [];
  List<Experience> experiences = [];
  List<String> certifications = [];
  List<File> certificationFiles = [];
  File? idCardFile;
  
  bool _isLoading = false;
  List<String> availableServices = [];
  
  // Track form steps - update to have more steps
  int _currentStep = 1; // Step 1: Services, Step 2: ID & Certifications, Step 3: Professional Info, Step 4: Location, Step 5: Working Hours
  final String cloudName = "dfk7mskxv";
  final String uploadPreset = "plateforme_service";
  
  // Add these missing variables for map functionality
  LatLng? _selectedLocation;
  String _locationAddress = '';
  final MapController _mapController = MapController();
  bool _isLoadingLocation = false;
  
  // Add these variables for working hours
  final Map<String, Map<String, String>> _workingHours = {
    'monday': {'start': '08:00', 'end': '18:00'},
    'tuesday': {'start': '08:00', 'end': '18:00'},
    'wednesday': {'start': '08:00', 'end': '18:00'},
    'thursday': {'start': '08:00', 'end': '18:00'},
    'friday': {'start': '08:00', 'end': '18:00'},
    'saturday': {'start': '08:00', 'end': '18:00'},
    'sunday': {'start': '00:00', 'end': '00:00'},
  };
  
  final Map<String, bool> _workingDays = {
    'monday': true,
    'tuesday': true,
    'wednesday': true,
    'thursday': true,
    'friday': true,
    'saturday': true,
    'sunday': false,
  };
  
  // French day names for display
  final Map<String, String> _dayNames = {
    'monday': 'Lundi',
    'tuesday': 'Mardi',
    'wednesday': 'Mercredi',
    'thursday': 'Jeudi',
    'friday': 'Vendredi',
    'saturday': 'Samedi',
    'sunday': 'Dimanche',
  };

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    final snapshot = await FirebaseFirestore.instance.collection('services').get();
    setState(() {
      availableServices = snapshot.docs.map((doc) => doc['name'] as String).toList();
    });
  }

  Future<String?> _uploadFileToCloudinary(File file) async {
    final url = "https://api.cloudinary.com/v1_1/$cloudName/image/upload";
    try {
      var request = http.MultipartRequest('POST', Uri.parse(url));
      request.fields['upload_preset'] = uploadPreset;
      request.files.add(await http.MultipartFile.fromPath('file', file.path));
      
      var response = await request.send();
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var jsonData = json.decode(responseData);
        return jsonData['secure_url'];
      }
    } catch (e) {
      print('Erreur upload: $e');
    }
    return null;
  }

  // Add these methods for location handling
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
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude, 
        position.longitude
      );
      
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        setState(() {
          _locationAddress = '${place.street ?? ''}, ${place.locality ?? ''}, ${place.country ?? ''}'.replaceAll(RegExp(r', ,'), ',').replaceAll(RegExp(r'^, |, $'), '');
          _workingAreaController.text = _locationAddress;
        });
      }
    } catch (e) {
      print('Error getting address: $e');
    } finally {
      setState(() => _isLoadingLocation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getStepTitle()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: _buildCurrentStep(),
        ),
      ),
    );
  }
  
  String _getStepTitle() {
    switch (_currentStep) {
      case 1:
        return 'Services proposés';
      case 2:
        return 'Documents & Certifications';
      case 3:
        return 'Informations professionnelles';
      case 4:
        return 'Localisation';
      case 5:
        return 'Horaires de travail';
      default:
        return 'Inscription Prestataire';
    }
  }
  
  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 1:
        return _buildServicesForm();
      case 2:
        return _buildDocumentsForm();
      case 3:
        return _buildProfessionalInfoForm();
      case 4:
        return _buildLocationForm();
      case 5:
        return _buildWorkingHoursForm();
      default:
        return _buildServicesForm();
    }
  }
  
  Widget _buildServicesForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Step 1: Services selection
        const Text('Sélectionnez vos services (1-3)', 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 8),
        const Text('Choisissez les services que vous proposez à vos clients',
          style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 16),
        
        Wrap(
          spacing: 8,
          children: availableServices.map((service) {
            final isSelected = selectedServices.contains(service);
            return FilterChip(
              label: Text(service),
              selected: isSelected,
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
            );
          }).toList(),
        ),
        
        const SizedBox(height: 24),
        
        ElevatedButton(
          onPressed: () {
            if (selectedServices.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Sélectionnez au moins un service')),
              );
              return;
            }
            setState(() {
              _currentStep = 2;
            });
          },
          child: const Text('Continuer'),
        ),
      ],
    );
  }
  
  // Step 2: ID Card and Certifications
  Widget _buildDocumentsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Pièce d'identité
        const Text('Pièce d\'identité', 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 8),
        const Text('Téléchargez une copie de votre pièce d\'identité',
          style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 8),
        
        Card(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                if (idCardFile != null)
                  Image.file(idCardFile!, height: 200),
                ElevatedButton.icon(
                  onPressed: _pickIdCard,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Télécharger la pièce d\'identité'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Certifications
        const Text('Certifications', 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 8),
        const Text('Ajoutez vos certifications professionnelles (optionnel)',
          style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 8),
        
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: certifications.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: Text(certifications[index]),
              trailing: IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () {
                  setState(() {
                    certifications.removeAt(index);
                    certificationFiles.removeAt(index);
                  });
                },
              ),
            );
          },
        ),
        TextFormField(
          controller: _certificationController,
          decoration: const InputDecoration(
            labelText: 'Nom de la certification',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _addCertification,
          icon: const Icon(Icons.add),
          label: const Text('Ajouter une certification'),
        ),
        
        const SizedBox(height: 24),
        
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _currentStep = 1;
                  });
                },
                child: const Text('Retour'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  if (idCardFile == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Veuillez télécharger votre pièce d\'identité')),
                    );
                    return;
                  }
                  setState(() {
                    _currentStep = 3;
                  });
                },
                child: const Text('Continuer'),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  // Step 3: Professional Information
  Widget _buildProfessionalInfoForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Informations professionnelles', 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 8),
        const Text('Partagez vos informations de contact professionnelles',
          style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 16),

        TextFormField(
          controller: _bioController,
          decoration: const InputDecoration(
            labelText: 'Description professionnelle',
            border: OutlineInputBorder(),
            hintText: 'Décrivez votre expérience et vos compétences',
          ),
          maxLines: 3,
          validator: (value) => value?.isEmpty ?? true ? 'Champ requis' : null,
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'Téléphone professionnel',
            border: OutlineInputBorder(),
            hintText: 'Ex: 12345678',
            prefixText: '+216 ',
          ),
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Champ requis';
            }
            // Validate Tunisian phone number (8 digits)
            if (!RegExp(r'^[0-9]{8}$').hasMatch(value)) {
              return 'Numéro invalide (8 chiffres requis)';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        TextFormField(
          controller: _emailController,
          decoration: const InputDecoration(
            labelText: 'Email professionnel',
            border: OutlineInputBorder(),
            hintText: 'Ex: nom@exemple.com',
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Champ requis';
            }
            // Validate email format
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return 'Format d\'email invalide';
            }
            return null;
          },
        ),
        
        const SizedBox(height: 24),
        
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _currentStep = 2;
                  });
                },
                child: const Text('Retour'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    setState(() {
                      _currentStep = 4;
                    });
                  }
                },
                child: const Text('Continuer'),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  // Step 4: Location
  Widget _buildLocationForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Localisation exacte', 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 8),
        const Text('Sélectionnez votre position sur la carte',
          style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 16),
        
        // Map widget
        Container(
          height: 300,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              FlutterMap(
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
                          builder: (context) => const Icon(
                            Icons.location_on,
                            color: Colors.red,
                            size: 40.0,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              Positioned(
                top: 10,
                right: 10,
                child: FloatingActionButton(
                  mini: true,
                  onPressed: _getCurrentLocation,
                  child: const Icon(Icons.my_location),
                ),
              ),
              if (_isLoadingLocation)
                const Center(
                  child: CircularProgressIndicator(),
                ),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        if (_locationAddress.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Adresse: $_locationAddress',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
          ),

        // Zone de travail et tarifs
        const SizedBox(height: 16),
        TextFormField(
          controller: _workingAreaController,
          decoration: const InputDecoration(
            labelText: 'Zone géographique d\'intervention',
            border: OutlineInputBorder(),
            hintText: 'Ex: Tunis, La Marsa, Sousse...',
          ),
          validator: (value) => value?.isEmpty ?? true ? 'Champ requis' : null,
        ),
        const SizedBox(height: 16),

        const Text('Tarifs horaires (DT/h)', 
          style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _minRateController,
                decoration: const InputDecoration(
                  labelText: 'Minimum',
                  border: OutlineInputBorder(),
                  suffixText: 'DT/h',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Requis';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Nombre invalide';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _maxRateController,
                decoration: const InputDecoration(
                  labelText: 'Maximum',
                  border: OutlineInputBorder(),
                  suffixText: 'DT/h',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Requis';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Nombre invalide';
                  }
                  final min = double.tryParse(_minRateController.text) ?? 0;
                  final max = double.tryParse(value) ?? 0;
                  if (max < min) {
                    return 'Doit être ≥ min';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _currentStep = 3;
                  });
                },
                child: const Text('Retour'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  if (!_formKey.currentState!.validate()) {
                    return;
                  }
                  
                  if (_selectedLocation == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Veuillez sélectionner votre localisation sur la carte')),
                    );
                    return;
                  }
                  
                  setState(() {
                    _currentStep = 5;
                  });
                },
                child: const Text('Continuer'),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  // Step 5: Working Hours - Improved UI
  Widget _buildWorkingHoursForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Horaires de travail', 
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 8),
        const Text('Définissez vos heures de disponibilité (maximum 12h par jour)',
          style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 16),
        
        // Working days selection with improved UI
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Jours de travail', 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                      title: Text(_dayNames[day]!),
                      value: isWorkingDay,
                      onChanged: (value) {
                        setState(() {
                          _workingDays[day] = value ?? false;
                          if (!(value ?? false)) {
                            // Reset hours if day is turned off
                            _workingHours[day] = {'start': '00:00', 'end': '00:00'};
                          } else {
                            // Set default hours if day is turned on
                            _workingHours[day] = {'start': '08:00', 'end': '18:00'};
                          }
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Working hours selection with improved UI
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Heures de travail', 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                
                // Only show time selection for working days
                ...(_workingDays.entries
                  .where((entry) => entry.value) // Only working days
                  .map((entry) {
                    final day = entry.key;
                    return Column(
                      children: [
                        ListTile(
                          title: Text(_dayNames[day]!, 
                            style: const TextStyle(fontWeight: FontWeight.bold)),
                          contentPadding: EdgeInsets.zero,
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectTime(context, day, 'start'),
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Début',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  child: Text(_workingHours[day]!['start']!),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectTime(context, day, 'end'),
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Fin',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  child: Text(_workingHours[day]!['end']!),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                      ],
                    );
                  }).toList()
                ),
                
                if (!_workingDays.values.any((isWorking) => isWorking))
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text(
                      'Veuillez sélectionner au moins un jour de travail',
                      style: TextStyle(color: Colors.red, fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _currentStep = 4;
                  });
                },
                child: const Text('Retour'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: _isLoading ? null : () {
                  if (!_workingDays.values.any((isWorking) => isWorking)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sélectionnez au moins un jour de travail')),
                    );
                    return;
                  }
                  _submitForm();
                },
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Soumettre la demande'),
              ),
            ),
          ],
        ),
      ],
    );
  }
  

  Future<void> _pickIdCard() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        idCardFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _addCertification() async {
    if (_certificationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer le nom de la certification')),
      );
      return;
    }

    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        certifications.add(_certificationController.text);
        certificationFiles.add(File(pickedFile.path));
        _certificationController.clear();
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (selectedServices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez au moins un service')),
      );
      return;
    }
    
    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner votre localisation sur la carte')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = FirebaseAuth.instance.currentUser!.uid;
      if (userId == null) throw Exception('Non authentifié');

      // Upload ID Card
      final idCardUrl = idCardFile != null 
          ? await _uploadFileToCloudinary(idCardFile!)
          : null;
      if (idCardUrl == null) throw Exception("Échec upload pièce d'identité");

      // Upload Certifications
      List<String> certificationUrls = [];
      for (var file in certificationFiles) {
        final url = await _uploadFileToCloudinary(file);
        if (url != null) certificationUrls.add(url);
      }

      // Create request data with location
      final requestData = {
        'userId': userId,
        'services': selectedServices,
        'experiences': experiences.map((e) => e.toMap()).toList(),
        'certifications': certifications,
        'certificationFiles': certificationUrls,
        'workingArea': _workingAreaController.text,
        'rateRange': {
          'min': double.parse(_minRateController.text),
          'max': double.parse(_maxRateController.text),
        },
        'bio': _bioController.text,
        'idCardUrl': idCardUrl,
        'professionalPhone': _phoneController.text,
        'professionalEmail': _emailController.text,
        'status': 'pending',
        'submissionDate': FieldValue.serverTimestamp(),
        // Add location data
        'exactLocation': {
          'latitude': _selectedLocation!.latitude,
          'longitude': _selectedLocation!.longitude,
          'address': _locationAddress,
        },
        'currentLocation': GeoPoint(_selectedLocation!.latitude, _selectedLocation!.longitude),
        // Add new fields for matching service
        'averageResponseTime': 30, // Default 30 minutes
        'completionRate': 1.0,    // Start with perfect rate
        'totalServices': 0,
        'completedServices': 0,
        'lastStatsUpdate': FieldValue.serverTimestamp(),
        'isAvailable': true,      // Provider availability status
        // Add working hours data
        'workingHours': _workingHours,
        'workingDays': _workingDays,
      };

      // Create request in Firestore
      await FirebaseFirestore.instance
          .collection('provider_requests')
          .doc(userId)
          .set(requestData);

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

  // Add this method for time selection
  Future<void> _selectTime(BuildContext context, String day, String type) async {
    final TimeOfDay initialTime = _parseTimeString(_workingHours[day]![type]!);
    
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
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
          final endTime = _parseTimeString(_workingHours[day]!['end']!);
          if (pickedTime.hour > endTime.hour || 
              (pickedTime.hour == endTime.hour && pickedTime.minute >= endTime.minute)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('L\'heure de début doit être avant l\'heure de fin')),
            );
            return;
          }
          
          // Check if total hours would exceed 12
          if (_calculateHoursDifference(pickedTime, endTime) > 12) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Maximum 12 heures de travail par jour')),
            );
            return;
          }
        } 
        // If setting end time, ensure it's after start time
        else if (type == 'end') {
          final startTime = _parseTimeString(_workingHours[day]!['start']!);
          if (pickedTime.hour < startTime.hour || 
              (pickedTime.hour == startTime.hour && pickedTime.minute <= startTime.minute)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('L\'heure de fin doit être après l\'heure de début')),
            );
            return;
          }
          
          // Check if total hours would exceed 12
          if (_calculateHoursDifference(startTime, pickedTime) > 12) {
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
  
  TimeOfDay _parseTimeString(String timeString) {
    final parts = timeString.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }
  
  double _calculateHoursDifference(TimeOfDay start, TimeOfDay end) {
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    return (endMinutes - startMinutes) / 60;
  }
}
