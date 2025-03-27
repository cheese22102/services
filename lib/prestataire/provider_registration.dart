import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:go_router/go_router.dart';

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
  final _bioController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
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

  final String cloudName = "dfk7mskxv";
  final String uploadPreset = "plateforme_service";

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inscription Prestataire'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Services selection
              const Text('Services proposés (1-3)', 
                style: TextStyle(fontWeight: FontWeight.bold)),
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
              const SizedBox(height: 16),

              // Pièce d'identité
              const Text('Pièce d\'identité', 
                style: TextStyle(fontWeight: FontWeight.bold)),
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
              const SizedBox(height: 16),

              // Certifications
              const Text('Certifications', 
                style: TextStyle(fontWeight: FontWeight.bold)),
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
                ),
              ),
              ElevatedButton.icon(
                onPressed: _addCertification,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter une certification'),
              ),
              const SizedBox(height: 16),

              // Informations professionnelles
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(
                  labelText: 'Description professionnelle',
                  border: OutlineInputBorder(),
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
                ),
                keyboardType: TextInputType.phone,
                validator: (value) => value?.isEmpty ?? true ? 'Champ requis' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email professionnel',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => value?.isEmpty ?? true ? 'Champ requis' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Adresse professionnelle',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Champ requis' : null,
              ),
              const SizedBox(height: 16),

              // Zone de travail et tarifs
              TextFormField(
                controller: _workingAreaController,
                decoration: const InputDecoration(
                  labelText: 'Zone géographique d\'intervention',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value?.isEmpty ?? true ? 'Champ requis' : null,
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minRateController,
                      decoration: const InputDecoration(
                        labelText: 'Tarif minimum (DT/h)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => value?.isEmpty ?? true ? 'Requis' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _maxRateController,
                      decoration: const InputDecoration(
                        labelText: 'Tarif maximum (DT/h)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) => value?.isEmpty ?? true ? 'Requis' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Soumettre la demande'),
              ),
            ],
          ),
        ),
      ),
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
        const SnackBar(content: Text('Veuillez sélectionner au moins un service')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
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

      // Create request data matching Firestore rules requirements
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
        'professionalAddress': _addressController.text,
        'isVerified': false,
        'status': 'pending',
        'submissionDate': Timestamp.now(),
      };

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
        context.go('/prestataireHome'); // Replace Navigator.pop with GoRouter
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

  @override
  void dispose() {
    _bioController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _workingAreaController.dispose();
    _minRateController.dispose();
    _maxRateController.dispose();
    _certificationController.dispose();
    super.dispose();
  }
}
