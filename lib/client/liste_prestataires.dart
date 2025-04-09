import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../chat/conversation_service_page.dart';

class ServiceProvidersPage extends StatefulWidget {
  final String serviceName;

  const ServiceProvidersPage({
    super.key,
    required this.serviceName,
  });

  @override
  State<ServiceProvidersPage> createState() => _ServiceProvidersPageState();
}

class _ServiceProvidersPageState extends State<ServiceProvidersPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _sortBy = 'rating'; // Default sort by rating
  bool _isAscending = false;
  Position? _currentPosition;
  bool _isLoading = true;
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  double _calculateDistance(Map<String, dynamic> providerData) {
    if (_currentPosition == null || 
        providerData['exactLocation'] == null ||
        providerData['exactLocation']['latitude'] == null ||
        providerData['exactLocation']['longitude'] == null) {
      return double.infinity;
    }

    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      providerData['exactLocation']['latitude'],
      providerData['exactLocation']['longitude'],
    ) / 1000; // Convert to kilometers
  }

  Future<List<Map<String, dynamic>>> _getProviders(List<DocumentSnapshot> providers) async {
    List<Map<String, dynamic>> result = [];

    for (var provider in providers) {
      final providerData = provider.data() as Map<String, dynamic>;
      final providerId = providerData['userId'] as String? ?? provider.id;

      // Get user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(providerId)
          .get();
      
      if (!userDoc.exists) continue;
      
      final userData = userDoc.data() as Map<String, dynamic>;
      
      // Get reviews and calculate average rating
      final reviewsSnapshot = await FirebaseFirestore.instance
          .collection('provider_reviews')
          .where('providerId', isEqualTo: providerId)
          .get();
      
      double totalRating = 0;
      final reviews = reviewsSnapshot.docs;
      for (var review in reviews) {
        totalRating += (review.data()['rating'] as num?)?.toDouble() ?? 0.0;
      }
      
      final averageRating = reviews.isEmpty ? 0.0 : totalRating / reviews.length;
      final distance = _calculateDistance(providerData);
      
      result.add({
        'providerId': providerId,
        'providerData': providerData,
        'userData': userData,
        'rating': averageRating,
        'reviewCount': reviews.length,
        'distance': distance,
      });
    }
    
    return result;
  }

  List<Map<String, dynamic>> _sortProviders(List<Map<String, dynamic>> providers) {
    switch (_sortBy) {
      case 'rating':
        providers.sort((a, b) => _isAscending 
            ? (a['rating'] as double).compareTo(b['rating'] as double)
            : (b['rating'] as double).compareTo(a['rating'] as double));
        break;
      case 'distance':
        providers.sort((a, b) => _isAscending 
            ? (b['distance'] as double).compareTo(a['distance'] as double)
            : (a['distance'] as double).compareTo(b['distance'] as double));
        break;
      case 'reviews':
        providers.sort((a, b) => _isAscending 
            ? (a['reviewCount'] as int).compareTo(b['reviewCount'] as int)
            : (b['reviewCount'] as int).compareTo(a['reviewCount'] as int));
        break;
      case 'price':
        providers.sort((a, b) {
          final aMin = (a['providerData']['rateRange']['min'] as num?)?.toDouble() ?? 0.0;
          final bMin = (b['providerData']['rateRange']['min'] as num?)?.toDouble() ?? 0.0;
          return _isAscending ? aMin.compareTo(bMin) : bMin.compareTo(aMin);
        });
        break;
    }
    return providers;
  }

  List<Map<String, dynamic>> _filterProviders(List<Map<String, dynamic>> providers) {
    if (_searchQuery.isEmpty) return providers;
    
    final query = _searchQuery.toLowerCase();
    return providers.where((provider) {
      final userData = provider['userData'] as Map<String, dynamic>;
      final providerData = provider['providerData'] as Map<String, dynamic>;
      
      final name = '${userData['firstname'] ?? ''} ${userData['lastname'] ?? ''}'.toLowerCase();
      final bio = (providerData['bio'] as String? ?? '').toLowerCase();
      final area = (providerData['workingArea'] as String? ?? '').toLowerCase();
      
      return name.contains(query) || bio.contains(query) || area.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Prestataires - ${widget.serviceName}'),
      ),
      body: Column(
        children: [
          // Search and filter bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher un prestataire...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
                
                const SizedBox(height: 12),
                
                // Sorting options
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildSortChip('Note', 'rating'),
                      _buildSortChip('Distance', 'distance'),
                      _buildSortChip('Avis', 'reviews'),
                      _buildSortChip('Prix', 'price'),
                      const SizedBox(width: 8),
                      // Order toggle
                      ActionChip(
                        avatar: Icon(
                          _isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 18,
                        ),
                        label: Text(_isAscending ? 'Croissant' : 'Décroissant'),
                        onPressed: () {
                          setState(() {
                            _isAscending = !_isAscending;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Provider list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('provider_requests')
                  .where('status', isEqualTo: 'approved')
                  .where('services', arrayContains: widget.serviceName)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Une erreur est survenue'));
                }

                if (snapshot.connectionState == ConnectionState.waiting || _isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final providers = snapshot.data?.docs ?? [];

                if (providers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.person_off, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun prestataire disponible pour ${widget.serviceName}',
                          style: const TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: _getProviders(providers),
                  builder: (context, providersSnapshot) {
                    if (!providersSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final allProviders = providersSnapshot.data!;
                    final filteredProviders = _filterProviders(allProviders);
                    final sortedProviders = _sortProviders(filteredProviders);

                    if (sortedProviders.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.search_off, size: 64, color: Colors.grey),
                            const SizedBox(height: 16),
                            const Text(
                              'Aucun résultat pour cette recherche',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: sortedProviders.length,
                      itemBuilder: (context, index) {
                        final provider = sortedProviders[index];
                        final providerData = provider['providerData'] as Map<String, dynamic>;
                        final userData = provider['userData'] as Map<String, dynamic>;
                        final providerId = provider['providerId'] as String;
                        final rating = provider['rating'] as double;
                        final reviewCount = provider['reviewCount'] as int;
                        final distance = provider['distance'] as double;

                        return _buildProviderCard(
                          context,
                          providerId,
                          providerData,
                          userData,
                          rating,
                          reviewCount,
                          distance,
                        );
                      },
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

  Widget _buildSortChip(String label, String value) {
    final isSelected = _sortBy == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() {
              _sortBy = value;
            });
          }
        },
        backgroundColor: Colors.white,
        selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
      ),
    );
  }

  Widget _buildProviderCard(
    BuildContext context,
    String providerId,
    Map<String, dynamic> providerData,
    Map<String, dynamic> userData,
    double rating,
    int reviewCount,
    double distance,
  ) {
    // Create a function to navigate to provider profile to avoid duplication
    void navigateToProviderProfile() {
      // Use the correct route format and ensure all required data is passed
      context.push('/clientHome/provider/$providerId', extra: {
        'providerData': providerData,
        'userData': userData,
        'serviceName': widget.serviceName,
      });
    }

    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: navigateToProviderProfile, // Use the function here
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: userData['avatarUrl'] != null
                        ? NetworkImage(userData['avatarUrl'])
                        : null,
                    child: userData['avatarUrl'] == null
                        ? Text(
                            (userData['firstname'] ?? '?')[0].toUpperCase(),
                            style: const TextStyle(fontSize: 24),
                          )
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${userData['firstname']} ${userData['lastname']}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber, size: 16),
                            Text(
                              ' ${rating.toStringAsFixed(1)}',
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              ' ($reviewCount avis)',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (distance != double.infinity) ...[
                              Icon(Icons.location_on, color: Colors.red, size: 16),
                              Text(
                                ' ${distance.toStringAsFixed(1)} km',
                                style: TextStyle(
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          'Zone: ${providerData['workingArea']}',
                          style: TextStyle(
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          'Tarif: ${providerData['rateRange']['min']} - ${providerData['rateRange']['max']} DT/h',
                          style: TextStyle(
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (providerData['bio'] != null && providerData['bio'].toString().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Bio:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                Text(
                  providerData['bio'],
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey[700],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.person),
                    label: const Text('Voir profil'),
                    onPressed: navigateToProviderProfile, // Use the same function here
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.chat),
                    label: const Text('Contacter'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ConversationServicePage(
                            otherUserId: providerId,
                            otherUserName: '${userData['firstname']} ${userData['lastname']}', // Add the name
                            serviceName: widget.serviceName,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}