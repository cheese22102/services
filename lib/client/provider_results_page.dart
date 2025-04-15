import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../client/provider_finder_service.dart';


class ProviderResultsPage extends StatefulWidget {
  final String serviceId;
  final String serviceName;
  final String description;
  final LatLng location;
  final String address;
  final List<String> imageUrls;
  final DateTime preferredDateTime;
  final bool isImmediate;
  final String clientId;
  final String clientName;

  const ProviderResultsPage({
    super.key,
    required this.serviceId,
    required this.serviceName,
    required this.description,
    required this.location,
    required this.address,
    required this.imageUrls,
    required this.preferredDateTime,
    required this.isImmediate,
    required this.clientId,
    required this.clientName,
  });

  @override
  State<ProviderResultsPage> createState() => _ProviderResultsPageState();
}

// Add at the top with other imports

class _ProviderResultsPageState extends State<ProviderResultsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _matchedProviders = [];
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _findBestProviders();
  }

  // In the _findBestProviders method, add debugging to see what's happening
  Future<void> _findBestProviders() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
      
      debugPrint('Finding providers for service ID: ${widget.serviceId}');
      
      final providers = await ProviderFinderService.findBestProvidersForRequest(
        serviceId: widget.serviceId,
        clientLocation: widget.location,
        preferredDateTime: widget.preferredDateTime,
        isImmediate: widget.isImmediate,
      );
  
      debugPrint('Found ${providers.length} top providers');
      
      if (providers.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Aucun prestataire trouvé pour le service: ${widget.serviceName}';
        });
        return;
      }

      // Create service request with top providers
      final requestData = {
        'clientId': widget.clientId,
        'clientName': widget.clientName,
        'service': widget.serviceName,
        'serviceId': widget.serviceId,
        'description': widget.description,
        'location': GeoPoint(widget.location.latitude, widget.location.longitude),
        'address': widget.address,
        'images': widget.imageUrls,
        'preferredDate': Timestamp.fromDate(widget.preferredDateTime),
        'isImmediate': widget.isImmediate,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'potentialProviders': providers.map((p) => p['id']).toList(),
      };

      final requestRef = await FirebaseFirestore.instance
          .collection('serviceRequests')
          .add(requestData);
      
      await requestRef.update({'id': requestRef.id});

      setState(() {
        _matchedProviders = providers;
        _isLoading = false;
      });

    } catch (e) {
      debugPrint('Error finding providers: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur: $e';
      });
    }
  }

  // Remove the old _getDayName and _parseTimeString methods
  // Keep only the UI building methods below...

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Résultats de recherche'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 64,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          style: const TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Retour'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildResultsView(),
    );
  }

  Widget _buildResultsView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          child: Column(
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'Demande envoyée avec succès !',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Votre demande pour ${widget.serviceName} a été enregistrée',
                style: const TextStyle(
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        
        Expanded(
          child: _matchedProviders.isEmpty
              ? const Center(child: Text('Aucun prestataire trouvé'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _matchedProviders.length,
                  itemBuilder: (context, index) {
                    final provider = _matchedProviders[index];
                    final profilePicture = provider['profileImage'] as String?;
                    final providerName = provider['name'] as String;
                    final hourlyRate = provider['hourlyRate'] as double;
                    final distance = provider['distance'] as double;
                    final isAvailable = provider['isAvailable'] as bool;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundImage: profilePicture?.isNotEmpty == true
                                      ? NetworkImage(profilePicture!)
                                      : null,
                                  child: profilePicture?.isEmpty != false
                                      ? const Icon(Icons.person)
                                      : null,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        providerName,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.star, color: Colors.amber, size: 16),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${provider['rating'].toStringAsFixed(1)} (${provider['completedJobs']} services)',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Distance display
                            Row(
                              children: [
                                Icon(Icons.location_on, size: 16),
                                Text('À ${distance.toStringAsFixed(1)} km'),
                                SizedBox(width: 16),
                                Icon(
                                  isAvailable ? Icons.check_circle : Icons.cancel,
                                  color: isAvailable ? Colors.green : Colors.red,
                                ),
                                Text(isAvailable ? 'Disponible' : 'Non disponible'),
                              ],
                            ),
                            
                            // Pricing display
                            if (hourlyRate > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    Icon(Icons.euro, size: 16),
                                    Text('À partir de ${hourlyRate.toStringAsFixed(0)}€/h'),
                                  ],
                                ),
                              ),
                            
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                final providerId = provider['id'] as String;
                                
                                FirebaseFirestore.instance
                                  .collection('providers')
                                  .doc(providerId)
                                  .get().then((providerDoc) {
                                    if (!providerDoc.exists) return;
                                    
                                    final providerData = providerDoc.data() ?? {};
                                    
                                    FirebaseFirestore.instance
                                      .collection('users')
                                      .doc(providerId)
                                      .get().then((userDoc) {
                                        if (!userDoc.exists) return;
                                        
                                        final userData = userDoc.data() ?? {};
                                        
                                        context.push(
                                          '/client/provider/$providerId',
                                          extra: {
                                            'providerData': providerData,
                                            'userData': userData,
                                            'serviceName': widget.serviceName,
                                          },
                                        );
                                      });
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Theme.of(context).primaryColor,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(color: Theme.of(context).primaryColor),
                                    ),
                                  ),
                                  child: const Text('Voir le profil'),
                            )],
                                        ),
                                    ));
                                  },
                                ),
        ),
                
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    context.go('/client/requests');
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Voir mes demandes'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}