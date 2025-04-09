import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../notifications_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// Move VerificationItem class outside
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

// Change to StatefulWidget
class ProviderApprovalPage extends StatefulWidget {
  const ProviderApprovalPage({super.key});

  @override
  State<ProviderApprovalPage> createState() => _ProviderApprovalPageState();
}

class _ProviderApprovalPageState extends State<ProviderApprovalPage> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _commentController = TextEditingController();
  String _searchQuery = '';
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
      title: 'Tarifs',
      description: 'Vérifier la cohérence des tarifs proposés',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Validation des Prestataires'),
      ),
      body: Column(
        children: [
          // Add search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Rechercher par nom ou prénom...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          // List of requests
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('provider_requests')
                  .where('status', isEqualTo: 'pending')  // Only show pending requests
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Une erreur est survenue'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Aucune demande en attente'));
                }

                final requests = snapshot.data!.docs;
                
                // Filter by search query if needed
                final filteredRequests = _searchQuery.isEmpty
                    ? requests
                    : requests.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        // Add more fields to search as needed
                        return data['professionalEmail'].toString().toLowerCase().contains(_searchQuery) ||
                               data['professionalPhone'].toString().toLowerCase().contains(_searchQuery);
                      }).toList();

                return ListView.builder(
                  itemCount: filteredRequests.length,
                  itemBuilder: (context, index) {
                    final requestData = filteredRequests[index].data() as Map<String, dynamic>;
                    final requestId = filteredRequests[index].id;
                    
                    return Card(
                      margin: const EdgeInsets.all(8.0),
                      child: ListTile(
                        title: Text('Demande de ${requestData['professionalEmail'] ?? 'Inconnu'}'),
                        subtitle: Text('Téléphone: ${requestData['professionalPhone'] ?? 'Non spécifié'}'),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () {
                          _showRequestDetails(context, requestId, requestData);
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showRequestDetails(BuildContext context, String requestId, Map<String, dynamic> requestData) {
    // Reset checklist
    for (var item in _checkList) {
      item.isVerified = false;
    }
    
    _commentController.clear();
    
    // Create a StatefulBuilder dialog to manage state within the dialog
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Détails de la demande'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Fermer'),
              ),
            ],
          ),
          body: StatefulBuilder(
            builder: (context, setDialogState) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Services section
                    _buildSectionTitle('Services proposés'),
                    _buildServicesList(requestData),
                    
                    const Divider(height: 32),
                    
                    // Documents section
                    _buildSectionTitle('Pièce d\'identité'),
                    _buildIdCard(requestData),
                    
                    const SizedBox(height: 16),
                    _buildSectionTitle('Certifications'),
                    _buildCertifications(requestData),
                    
                    const Divider(height: 32),
                    
                    // Professional info section
                    _buildSectionTitle('Informations professionnelles'),
                    _buildProfessionalInfo(requestData),
                    
                    const Divider(height: 32),
                    
                    // Location section
                    _buildSectionTitle('Localisation'),
                    _buildLocationInfo(requestData),
                    
                    const Divider(height: 32),
                    
                    // Working hours section
                    _buildSectionTitle('Horaires de travail'),
                    _buildWorkingHours(requestData),
                    
                    const Divider(height: 32),
                    
                    // Verification checklist
                    _buildSectionTitle('Liste de vérification'),
                    ...(_checkList.map((item) => CheckboxListTile(
                      title: Text(item.title),
                      subtitle: Text(item.description),
                      value: item.isVerified,
                      onChanged: (value) {
                        // Use setDialogState instead of setState
                        setDialogState(() {
                          item.isVerified = value ?? false;
                        });
                      },
                    ))),
                    
                    const SizedBox(height: 16),
                    
                    // Admin comment
                    TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        labelText: 'Commentaire (optionnel)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Action buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _rejectRequest(requestId),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Rejeter'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _approveRequest(requestId, requestData),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Approuver'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }
          ),
        ),
      ),
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
  
  Widget _buildProfessionalInfo(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoItem('Bio', data['bio'] ?? 'Non spécifiée'),
        _buildInfoItem('Email', data['professionalEmail'] ?? 'Non spécifié'),
        _buildInfoItem('Téléphone', data['professionalPhone'] ?? 'Non spécifié'),
        _buildInfoItem('Tarif minimum', '${data['rateRange']?['min'] ?? 'N/A'} DT/h'),
        _buildInfoItem('Tarif maximum', '${data['rateRange']?['max'] ?? 'N/A'} DT/h'),
      ],
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
  
  
  Future<void> _approveRequest(String requestId, Map<String, dynamic> requestData) async {
    // Check if all items are verified
    if (!_checkList.every((item) => item.isVerified)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez vérifier tous les éléments de la liste')),
      );
      return;
    }
    
    try {
      // Update request status
      await FirebaseFirestore.instance
          .collection('provider_requests')
          .doc(requestId)
          .update({
        'status': 'approved',
        'approvalDate': FieldValue.serverTimestamp(),
        'adminComment': _commentController.text,
      });
      
      // Create provider document
      await FirebaseFirestore.instance
          .collection('providers')
          .doc(requestId)
          .set({
        ...requestData,
        'isVerified': true,
        'status': 'active',
        'approvalDate': FieldValue.serverTimestamp(),
      });
      
      // Send notification to user - Fix: Use static method through class
      await NotificationsService.sendNotification(
        userId: requestId,
        title: 'Demande approuvée',
        body: 'Votre demande de prestataire a été approuvée. Vous pouvez maintenant proposer vos services.',
        data: {'type': 'provider_approval'},
      );
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demande approuvée avec succès')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }
  
  Future<void> _rejectRequest(String requestId) async {
    if (_commentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez fournir un commentaire expliquant le rejet')),
      );
      return;
    }
    
    try {
      // Update request status
      await FirebaseFirestore.instance
          .collection('provider_requests')
          .doc(requestId)
          .update({
        'status': 'rejected',
        'rejectionDate': FieldValue.serverTimestamp(),
        'adminComment': _commentController.text,
      });
      
      // Send notification to user 
      await NotificationsService.sendNotification(
        userId: requestId,
        title: 'Demande rejetée',
        body: 'Votre demande de prestataire a été rejetée. Consultez les commentaires pour plus d\'informations.',
        data: {'type': 'provider_rejection'},
      );
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demande rejetée')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }
  
  void _showFullScreenImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Visualisation'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ),
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
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error, color: Colors.red, size: 48),
                        SizedBox(height: 16),
                        Text('Impossible de charger l\'image'),
                      ],
                    ),
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