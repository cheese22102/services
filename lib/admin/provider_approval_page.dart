import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../notifications_service.dart';
import 'package:go_router/go_router.dart'; // Add this import

// VerificationItem class
class VerificationItem {
  final String title;
  final String description;
  bool isVerified;

  VerificationItem({
    required this.title,
    required this.description,
    this.isVerified = false,
  });
}

class ProviderApprovalDetailsPage extends StatefulWidget {
  final String providerId;
  
  const ProviderApprovalDetailsPage({
    super.key,
    required this.providerId,
  });

  @override
  State<ProviderApprovalDetailsPage> createState() => _ProviderApprovalDetailsPageState();
}

class _ProviderApprovalDetailsPageState extends State<ProviderApprovalDetailsPage> {
  final TextEditingController _commentController = TextEditingController();
  bool _isLoading = true;
  Map<String, dynamic>? _providerData;
  String? _errorMessage;
  
  final List<VerificationItem> _checkList = [
    VerificationItem(
      title: 'Identité',
      description: 'Vérifier la validité de la pièce d\'identité',
    ),
    VerificationItem(
      title: 'Coordonnées professionnelles',
      description: 'Vérifier la validité des coordonnées',
    ),
    VerificationItem(
      title: 'Certifications',
      description: 'Vérifier l\'authenticité des certifications',
    ),
    VerificationItem(
      title: 'Zone de travail',
      description: 'Vérifier la cohérence de la zone d\'intervention',
    ),
    VerificationItem(
      title: 'Photos de projets',
      description: 'Vérifier la qualité et la pertinence des photos de projets',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadProviderData();
  }

  // Update the _loadProviderData method to fetch user information
  Future<void> _loadProviderData() async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('providers')
          .doc(widget.providerId)
          .get();
      
      if (!docSnapshot.exists) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Prestataire non trouvé';
        });
        return;
      }
      
      final providerData = docSnapshot.data()!;
      
      // Fetch user data from users collection
      final userId = providerData['userId'] as String;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        // Merge user data with provider data
        final userData = userDoc.data()!;
        providerData['userData'] = userData;
      }
      
      setState(() {
        _providerData = providerData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors du chargement des données: $e';
      });
    }
  }

  // Add a new method to display user information
  Widget _buildUserInfoSection(Map<String, dynamic> data) {
    final userData = data['userData'] as Map<String, dynamic>?;
    
    if (userData == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text('Informations utilisateur non disponibles'),
      );
    }
    
    final photoURL = userData['photoURL'] as String?;
    final firstName = userData['firstname'] as String? ?? 'Non spécifié';
    final lastName = userData['lastname'] as String? ?? 'Non spécifié';
    final email = userData['email'] as String? ?? 'Non spécifié';
    final phone = userData['phone'] as String? ?? 'Non spécifié';
    final gender = userData['gender'] as String? ?? 'Non spécifié';
    final age = userData['age']?.toString() ?? 'Non spécifié';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User photo
                if (photoURL != null)
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: NetworkImage(photoURL),
                        fit: BoxFit.cover,
                      ),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                  )
                else
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade200,
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 40,
                      color: Colors.grey,
                    ),
                  ),
                const SizedBox(width: 16),
                
                // User details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$firstName $lastName',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildUserInfoItem(Icons.email, email),
                      _buildUserInfoItem(Icons.phone, phone),
                      _buildUserInfoItem(Icons.person, 'Genre: $gender'),
                      _buildUserInfoItem(Icons.cake, 'Âge: $age ans'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // Update the project photos section to use the correct field name
  Widget _buildProjectPhotosSection(Map<String, dynamic> data) {
    final projectPhotos = List<String>.from(data['projectPhotos'] ?? []);
    
    if (projectPhotos.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text('Aucune photo de projet fournie'),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.0,
          ),
          itemCount: projectPhotos.length,
          itemBuilder: (context, index) {
            final photoUrl = projectPhotos[index];
            return Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(child: CircularProgressIndicator());
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(child: Text('Erreur de chargement'));
                      },
                    ),
                  ),
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: IconButton(
                      icon: const Icon(
                        Icons.fullscreen,
                        color: Colors.white,
                        shadows: [Shadow(blurRadius: 3.0, color: Colors.black)],
                      ),
                      onPressed: () => _showFullScreenImage(context, photoUrl),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // Update the build method to include the user info section
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails du prestataire'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin/providers'), // Update navigation to use GoRouter
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // User info section
                      _buildSectionTitle('Informations personnelles'),
                      _buildUserInfoSection(_providerData!),
                      
                      const Divider(height: 32),
                      
                      // Services section
                      _buildSectionTitle('Services proposés'),
                      _buildServicesList(_providerData!),
                      
                      const Divider(height: 32),
                      
                      // Documents section
                      _buildSectionTitle('Pièce d\'identité'),
                      _buildIdCard(_providerData!),
                      
                      const SizedBox(height: 16),
                      _buildSectionTitle('Selfie avec pièce d\'identité'),
                      _buildSelfieWithId(_providerData!),
                      
                      const SizedBox(height: 16),
                      _buildSectionTitle('Patente'),
                      _buildPatente(_providerData!),
                      
                      const SizedBox(height: 16),
                      _buildSectionTitle('Certifications'),
                      _buildCertifications(_providerData!),
                      
                      const Divider(height: 32),
                      
                      // Project Photos section
                      _buildSectionTitle('Photos de projets'),
                      _buildProjectPhotosSection(_providerData!),
                      
                      const Divider(height: 32),
                      
                      // Professional info section
                      _buildSectionTitle('Informations professionnelles'),
                      _buildProfessionalInfo(_providerData!),
                      
                      const Divider(height: 32),
                      
                      // Location section
                      _buildSectionTitle('Localisation'),
                      _buildLocationInfo(_providerData!),
                      
                      const Divider(height: 32),
                      
                      // Working hours section
                      _buildSectionTitle('Horaires de travail'),
                      _buildWorkingHours(_providerData!),
                      
                      const Divider(height: 32),
                      
                      // Action section
                      _buildSectionTitle('Action'),
                      _buildActionButtons(widget.providerId, _providerData!, isDarkMode),
                    ],
                  ),
                ),
    );
  }

  // Add methods to display selfie with ID and patente
  Widget _buildSelfieWithId(Map<String, dynamic> data) {
    final selfieWithIdUrl = data['selfieWithIdUrl'] as String?;
    
    if (selfieWithIdUrl == null || selfieWithIdUrl.isEmpty) {
      return const Text('Aucun selfie avec pièce d\'identité fourni');
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Image.network(
            selfieWithIdUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
            errorBuilder: (context, error, stackTrace) {
              return const Center(child: Text('Erreur de chargement'));
            },
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => _showFullScreenImage(context, selfieWithIdUrl),
          icon: const Icon(Icons.fullscreen),
          label: const Text('Voir en plein écran'),
        ),
      ],
    );
  }

  Widget _buildPatente(Map<String, dynamic> data) {
    final patenteUrl = data['patenteUrl'] as String?;
    
    if (patenteUrl == null || patenteUrl.isEmpty) {
      return const Text('Aucune patente fournie (optionnel)');
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Image.network(
            patenteUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
            errorBuilder: (context, error, stackTrace) {
              return const Center(child: Text('Erreur de chargement'));
            },
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => _showFullScreenImage(context, patenteUrl),
          icon: const Icon(Icons.fullscreen),
          label: const Text('Voir en plein écran'),
        ),
      ],
    );
  }

  // Update the professional info method to include more details
  Widget _buildProfessionalInfo(Map<String, dynamic> data) {
    final experiences = List<Map<String, dynamic>>.from(data['experiences'] ?? []);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoItem('Bio', data['bio'] ?? 'Non spécifiée'),
        
        const SizedBox(height: 16),
        const Text(
          'Expériences',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        
        if (experiences.isEmpty)
          const Text('Aucune expérience spécifiée')
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: experiences.length,
            itemBuilder: (context, index) {
              final exp = experiences[index];
              final service = exp['service'] as String? ?? 'Non spécifié';
              final years = exp['years']?.toString() ?? 'Non spécifié';
              final description = exp['description'] as String? ?? 'Non spécifiée';
              
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('$years ans d\'expérience'),
                      const SizedBox(height: 4),
                      Text(description),
                    ],
                  ),
                ),
              );
            },
          ),
    ],
  );
  }
  
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  Widget _buildServicesList(Map<String, dynamic> data) {
    final services = List<String>.from(data['services'] ?? []);
    
    return Wrap(
      spacing: 8,
      children: services.map((service) {
        return Chip(
          label: Text(service),
          backgroundColor: Colors.blue.shade100,
        );
      }).toList(),
    );
  }
  
  Widget _buildIdCard(Map<String, dynamic> data) {
    final idCardUrl = data['idCardUrl'] as String?;
    
    if (idCardUrl == null || idCardUrl.isEmpty) {
      return const Text('Aucune pièce d\'identité fournie');
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Image.network(
            idCardUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
            errorBuilder: (context, error, stackTrace) {
              return const Center(child: Text('Erreur de chargement'));
            },
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => _showFullScreenImage(context, idCardUrl),
          icon: const Icon(Icons.fullscreen),
          label: const Text('Voir en plein écran'),
        ),
      ],
    );
  }
  
  Widget _buildCertifications(Map<String, dynamic> data) {
    final certifications = List<String>.from(data['certifications'] ?? []);
    final certificationFiles = List<String>.from(data['certificationFiles'] ?? []);
    
    if (certifications.isEmpty) {
      return const Text('Aucune certification fournie');
    }
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: certifications.length,
      itemBuilder: (context, index) {
        final certName = certifications[index];
        final certUrl = index < certificationFiles.length ? certificationFiles[index] : null;
        
        if (certUrl == null) {
          return Card(
            child: ListTile(
              title: Text(certName),
              subtitle: const Text('Aucun fichier associé'),
            ),
          );
        }
        
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  certName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.network(
                    certUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(child: Text('Erreur de chargement'));
                    },
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _showFullScreenImage(context, certUrl),
                  icon: const Icon(Icons.fullscreen),
                  label: const Text('Voir en plein écran'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  
  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLocationInfo(Map<String, dynamic> data) {
    final exactLocation = data['exactLocation'] as Map<String, dynamic>?;
    final address = exactLocation?['address'] as String? ?? 'Adresse non spécifiée';
    final latitude = exactLocation?['latitude'] as double? ?? 0.0;
    final longitude = exactLocation?['longitude'] as double? ?? 0.0;
    final workingArea = data['workingArea'] as String? ?? 'Non spécifiée';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoItem('Adresse', address),
        _buildInfoItem('Zone d\'intervention', workingArea),
        const SizedBox(height: 8),
        
        // Map widget
        if (latitude != 0.0 && longitude != 0.0)
          Container(
            height: 300,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: FlutterMap(
              options: MapOptions(
                center: LatLng(latitude, longitude),
                zoom: 15.0,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      width: 40.0,
                      height: 40.0,
                      point: LatLng(latitude, longitude),
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
          ),
      ],
    );
  }
  
  Widget _buildWorkingHours(Map<String, dynamic> data) {
    final workingDays = Map<String, bool>.from(data['workingDays'] ?? {});
    final workingHours = Map<String, Map<String, dynamic>>.from(data['workingHours'] ?? {});
    
    // French day names for display
    final dayNames = {
      'monday': 'Lundi',
      'tuesday': 'Mardi',
      'wednesday': 'Mercredi',
      'thursday': 'Jeudi',
      'friday': 'Vendredi',
      'saturday': 'Samedi',
      'sunday': 'Dimanche',
    };
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: workingDays.entries.map((entry) {
        final day = entry.key;
        final isWorkingDay = entry.value;
        final dayName = dayNames[day] ?? day;
        
        if (!isWorkingDay) {
          return ListTile(
            title: Text(dayName),
            subtitle: const Text('Jour non travaillé'),
            leading: const Icon(Icons.cancel, color: Colors.red),
          );
        }
        
        final hours = workingHours[day];
        final startTime = hours?['start'] ?? '00:00';
        final endTime = hours?['end'] ?? '00:00';
        
        return ListTile(
          title: Text(dayName),
          subtitle: Text('$startTime - $endTime'),
          leading: const Icon(Icons.check_circle, color: Colors.green),
        );
      }).toList(),
    );
  }
  
  // Action buttons for provider approval/rejection
  Widget _buildActionButtons(String providerId, Map<String, dynamic> data, bool isDarkMode) {
    final status = data['status'] as String? ?? 'pending';
    
    if (status != 'pending') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: status == 'approved'
              ? (isDarkMode ? Colors.green.shade900.withOpacity(0.3) : Colors.green.shade50)
              : (isDarkMode ? Colors.red.shade900.withOpacity(0.3) : Colors.red.shade50),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: status == 'approved'
                ? (isDarkMode ? Colors.green.shade700 : Colors.green.shade200)
                : (isDarkMode ? Colors.red.shade700 : Colors.red.shade200),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  status == 'approved' ? Icons.check_circle : Icons.cancel,
                  color: status == 'approved'
                      ? (isDarkMode ? Colors.green.shade300 : Colors.green.shade700)
                      : (isDarkMode ? Colors.red.shade300 : Colors.red.shade700),
                ),
                const SizedBox(width: 12),
                Text(
                  status == 'approved' ? 'Demande approuvée' : 'Demande rejetée',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: status == 'approved'
                        ? (isDarkMode ? Colors.green.shade300 : Colors.green.shade700)
                        : (isDarkMode ? Colors.red.shade300 : Colors.red.shade700),
                  ),
                ),
              ],
            ),
            if (status == 'rejected' && data['rejectionReason'] != null) ...[
              const SizedBox(height: 12),
              Text(
                'Motif: ${data['rejectionReason']}',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: isDarkMode ? Colors.red.shade200 : Colors.red.shade800,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Verification checklist
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Liste de vérification',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                ...(_checkList.map((item) => CheckboxListTile(
                      title: Text(
                        item.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        item.description,
                        style: TextStyle(
                          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                        ),
                      ),
                      value: item.isVerified,
                      activeColor: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700,
                      checkColor: Colors.white,
                      onChanged: (value) {
                        setState(() {
                          item.isVerified = value ?? false;
                        });
                      },
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ))),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Rejection reason field
        TextField(
          controller: _commentController,
          decoration: InputDecoration(
            labelText: 'Motif de rejet (obligatoire en cas de rejet)',
            labelStyle: TextStyle(
              color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade50,
          ),
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 24),

        // Action buttons
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _rejectProvider(providerId),
                icon: const Icon(Icons.cancel),
                label: const Text('Rejeter'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDarkMode ? Colors.red.shade800 : Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _approveProvider(providerId),
                icon: const Icon(Icons.check_circle),
                label: const Text('Approuver'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDarkMode ? Colors.green.shade800 : Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Function to approve a provider
  Future<void> _approveProvider(String providerId) async {
    // Check if all items are verified
    if (!_checkList.every((item) => item.isVerified)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez vérifier tous les éléments de la liste')),
      );
      return;
    }
    
    try {
      // Update the status to approved
      await FirebaseFirestore.instance
          .collection('providers')
          .doc(providerId)
          .update({
        'status': 'approved',
        'approvalDate': FieldValue.serverTimestamp(),
        'adminComment': _commentController.text,
        // Initialize rating fields
        'ratings': {
          'quality': {
            'total': 0,      // Sum of all quality ratings
            'count': 0,      // Number of quality ratings
            'average': 0.0,  // Average quality rating
          },
          'timeliness': {
            'total': 0,
            'count': 0,
            'average': 0.0,
          },
          'price': {
            'total': 0,
            'count': 0,
            'average': 0.0,
          },
          'overall': 0.0,    // Overall average of the three rating categories
          'reviewCount': 0,  // Total number of reviews
        },
      });
  
      // Send notification to the provider
      final userId = _providerData?['userId'];
      if (userId != null) {
        await NotificationsService.sendNotification(
          userId: userId,
          title: 'Demande approuvée',
          body: 'Votre demande pour devenir prestataire a été approuvée!',
          data: {'status': 'approved'},
        );
      }
  
      // Show success message and navigate back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prestataire approuvé avec succès')),
        );
        context.go('/admin/providers'); // Update navigation to use GoRouter
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }
  
  // Function to reject a provider
  Future<void> _rejectProvider(String providerId) async {
    if (_commentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez fournir un motif de rejet')),
      );
      return;
    }
  
    try {
      // Update the status to rejected and add rejection reason
      await FirebaseFirestore.instance
          .collection('providers')
          .doc(providerId)
          .update({
        'status': 'rejected',
        'rejectionDate': FieldValue.serverTimestamp(),
        'rejectionReason': _commentController.text,
      });
  
      // Send notification to the provider
      final userId = _providerData?['userId'];
      if (userId != null) {
        await NotificationsService.sendNotification(
          userId: userId,
          title: 'Demande rejetée',
          body: 'Votre demande pour devenir prestataire a été rejetée.',
          data: {
            'status': 'rejected',
            'reason': _commentController.text,
          },
        );
      }
  
      // Show success message and navigate back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prestataire rejeté avec succès')),
        );
        context.go('/admin/providers'); // Update navigation to use GoRouter
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }
  
  void _showFullScreenImage(BuildContext context, String imageUrl) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Visualisation du document'),
            backgroundColor: isDarkMode ? Colors.black : Colors.white,
            foregroundColor: isDarkMode ? Colors.white : Colors.black87,
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          backgroundColor: isDarkMode ? Colors.black : Colors.white,
          body: Center(
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: Image.network(
                imageUrl,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              (loadingProgress.expectedTotalBytes ?? 1)
                          : null,
                      color: isDarkMode ? Colors.blue.shade300 : Colors.blue.shade700,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.broken_image_outlined,
                        size: 64,
                        color: isDarkMode ? Colors.red.shade300 : Colors.red.shade700,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Impossible de charger l\'image',
                        style: TextStyle(
                          fontSize: 18,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}