import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class ProviderProfilePage extends StatefulWidget {
  final String providerId;
  final Map<String, dynamic> providerData;
  final Map<String, dynamic> userData;
  final String serviceName;
  final bool isOwnProfile;

  const ProviderProfilePage({
    super.key,
    required this.providerId,
    required this.providerData,
    required this.userData,
    required this.serviceName,
    this.isOwnProfile = false, // Default to false
  });

  @override
  State<ProviderProfilePage> createState() => _ProviderProfilePageState();
}

class _ProviderProfilePageState extends State<ProviderProfilePage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _reviews = [];
  double _averageRating = 0.0;
  bool _isFavorite = false;
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _loadReviews();
    _checkIfFavorite();
  }

  Future<void> _loadReviews() async {
    try {
      // Load reviews
      final reviewsSnapshot = await FirebaseFirestore.instance
          .collection('provider_reviews')
          .where('providerId', isEqualTo: widget.providerId)
          .orderBy('timestamp', descending: true)
          .get();

      final reviews = await Future.wait(
        reviewsSnapshot.docs.map((doc) async {
          final data = doc.data();
          final userId = data['userId'] as String;
          
          // Get user info
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
          
          final userData = userDoc.data() ?? {};
          final userName = '${userData['firstname'] ?? ''} ${userData['lastname'] ?? ''}';
          final userAvatar = userData['avatarUrl'];
          
          return {
            'id': doc.id,
            'rating': data['rating'] ?? 0.0,
            'comment': data['comment'] ?? '',
            'timestamp': data['timestamp'] ?? Timestamp.now(),
            'userName': userName,
            'userAvatar': userAvatar,
          };
        }),
      );

      // Calculate average rating
      double totalRating = 0;
      for (var review in reviews) {
        totalRating += review['rating'] as double;
      }
      
      setState(() {
        _reviews = reviews;
        _averageRating = reviews.isEmpty ? 0 : totalRating / reviews.length;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _checkIfFavorite() async {
    if (currentUserId == null) return;
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('favorite_providers')
          .doc(widget.providerId)
          .get();
      
      setState(() {
        _isFavorite = doc.exists;
      });
    } catch (e) {
      // Ignore error
    }
  }

  Future<void> _toggleFavorite() async {
    if (currentUserId == null) return;
    
    setState(() {
      _isFavorite = !_isFavorite;
    });
    
    try {
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('favorite_providers')
          .doc(widget.providerId);
      
      if (_isFavorite) {
        await ref.set({
          'providerId': widget.providerId,
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else {
        await ref.delete();
      }
    } catch (e) {
      // Revert state on error
      setState(() {
        _isFavorite = !_isFavorite;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    // Make sure the phone number is properly formatted
    final String formattedNumber = phoneNumber.replaceAll(RegExp(r'\s+'), '');
    final Uri phoneUri = Uri.parse('tel:$formattedNumber');
    
    try {
      if (!await launchUrl(phoneUri)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Impossible d\'appeler $formattedNumber')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  // Add the missing _showReviewDialog method
  // Update the _showReviewDialog method to use GoRouter
  void _showReviewDialog() {
    final _commentController = TextEditingController();
    double _rating = 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ajouter un avis'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Note'),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < _rating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                    ),
                    onPressed: () {
                      setState(() {
                        _rating = index + 1;
                      });
                    },
                  );
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _commentController,
                decoration: const InputDecoration(
                  labelText: 'Commentaire',
                  hintText: 'Partagez votre expérience...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(), // Replace Navigator.pop with context.pop
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_rating == 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Veuillez donner une note')),
                );
                return;
              }

              try {
                await FirebaseFirestore.instance
                    .collection('provider_reviews')
                    .add({
                  'providerId': widget.providerId,
                  'userId': currentUserId,
                  'rating': _rating,
                  'comment': _commentController.text,
                  'timestamp': FieldValue.serverTimestamp(),
                });

                if (mounted) {
                  context.pop(); // Replace Navigator.pop with context.pop
                  _loadReviews(); // Reload reviews
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Avis ajouté avec succès')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur: $e')),
                );
              }
            },
            child: const Text('Soumettre'),
          ),
        ],
      ),
    );
  }

  // Update the _showRequestServiceDialog method to use GoRouter
  void _showRequestServiceDialog() {
    final _descriptionController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Demander un service'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description du service',
                  hintText: 'Décrivez le service dont vous avez besoin...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(), // Replace Navigator.pop with context.pop
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_descriptionController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Veuillez décrire votre demande')),
                );
                return;
              }

              try {
                // Create a new service request
                final requestRef = await FirebaseFirestore.instance
                    .collection('service_requests')
                    .add({
                  'clientId': currentUserId,
                  'providerId': widget.providerId,
                  'serviceName': widget.serviceName,
                  'description': _descriptionController.text,
                  'status': 'pending', // pending, accepted, rejected, completed
                  'timestamp': FieldValue.serverTimestamp(),
                });
                
                // Create a conversation for this service
                final conversationRef = await FirebaseFirestore.instance
                    .collection('conversations')
                    .add({
                  'participants': [currentUserId, widget.providerId],
                  'serviceRequestId': requestRef.id,
                  'lastMessage': 'Nouvelle demande de service',
                  'lastMessageTimestamp': FieldValue.serverTimestamp(),
                  'createdAt': FieldValue.serverTimestamp(),
                });
                
                if (mounted) {
                  context.pop(); // Replace Navigator.pop with context.pop
                  
                  // Navigate to the conversation using GoRouter
                  context.push('/client/chat/conversation/${widget.providerId}', extra: {
                    'otherUserId': widget.providerId,
                    'otherUserName': '${widget.userData['firstname']} ${widget.userData['lastname']}',
                    'serviceName': widget.serviceName,
                  });
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Demande envoyée avec succès')),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Erreur: $e')),
                );
              }
            },
            child: const Text('Envoyer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.userData['firstname'] as String;
    final lastName = widget.userData['lastname'] as String;
    final avatarUrl = widget.userData['avatarUrl'] as String?;
    final bio = widget.providerData['bio'] as String?;
    final phoneNumber = widget.providerData['professionalPhone'] as String?;
    final email = widget.providerData['professionalEmail'] as String?;
    final minRate = widget.providerData['rateRange']['min'];
    final maxRate = widget.providerData['rateRange']['max'];
    final workingArea = widget.providerData['workingArea'] as String?;
    
    // Get experiences from provider data
    final experiences = widget.providerData['experiences'] as List<dynamic>?;
    
    // Get certifications from provider data
    final certifications = widget.providerData['certifications'] as List<dynamic>?;
    
    // Get working hours from provider data
    final workingHours = widget.providerData['workingHours'] as Map<String, dynamic>?;

    return Scaffold(
      appBar: AppBar(
        title: widget.isOwnProfile 
            ? const Text('Mon profil prestataire')
            : const Text('Profil du prestataire'),
        actions: [
          // Only show favorite button if not viewing own profile
          if (!widget.isOwnProfile)
            IconButton(
              icon: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _isFavorite ? Colors.red : null,
              ),
              onPressed: _toggleFavorite,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Provider header
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                child: avatarUrl == null ? Text(firstName[0], style: const TextStyle(fontSize: 30)) : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$firstName $lastName',
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.star,
                                          color: Colors.amber,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _averageRating.toStringAsFixed(1),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          ' (${_reviews.length} avis)',
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          
                          // Only show contact buttons if not viewing own profile
                          if (!widget.isOwnProfile) ...[
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: const Icon(Icons.chat),
                                    label: const Text('Contacter'),
                                    onPressed: _navigateToConversation,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (phoneNumber != null)
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.phone),
                                      label: const Text('Appeler'),
                                      onPressed: () => _makePhoneCall(phoneNumber),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Provider info
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Informations',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(),
                          if (bio != null && bio.isNotEmpty) ...[
                            const Text(
                              'À propos',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(bio),
                            const SizedBox(height: 16),
                          ],
                          
                          Row(
                            children: [
                              const Icon(Icons.attach_money, color: Colors.green),
                              const SizedBox(width: 8),
                              Text(
                                'Tarif: $minRate - $maxRate DT/h',
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 12),
                          
                          if (email != null && email.isNotEmpty)
                            Row(
                              children: [
                                const Icon(Icons.email, color: Colors.blue),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Email: $email',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                          
                          if (email != null && email.isNotEmpty)
                            const SizedBox(height: 12),
                          
                          if (workingArea != null && workingArea.isNotEmpty)
                            Row(
                              children: [
                                const Icon(Icons.location_on, color: Colors.red),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Zone de travail: $workingArea',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ],
                            ),
                            
                          const SizedBox(height: 12),
                          
                          Row(
                            children: [
                              const Icon(Icons.home_repair_service, color: Colors.purple),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Service: ${widget.serviceName}',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Experience section
                  if (experiences != null && experiences.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Expériences',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Divider(),
                            ...experiences.map((exp) {
                              final service = exp['service'] as String;
                              final years = exp['years'] as int;
                              final description = exp['description'] as String;
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.work, color: Colors.blue),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '$service - $years ${years > 1 ? 'ans' : 'an'} d\'expérience',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 32.0),
                                      child: Text(description),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),
                  ],
                  
                  // Certifications section
                  if (certifications != null && certifications.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Certifications',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Divider(),
                            ...certifications.map((cert) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.verified, color: Colors.green),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        cert.toString(),
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),
                  ],
                  
                  // Working hours section
                  if (workingHours != null) ...[
                    const SizedBox(height: 16),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Horaires de travail',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Divider(),
                            ...workingHours.entries.map((entry) {
                              final day = entry.key;
                              final hours = entry.value as Map<String, dynamic>;
                              final isWorking = hours['isWorking'] ?? true;
                              
                              if (!isWorking) {
                                return const SizedBox.shrink();
                              }
                              
                              String dayName;
                              switch (day) {
                                case 'monday': dayName = 'Lundi'; break;
                                case 'tuesday': dayName = 'Mardi'; break;
                                case 'wednesday': dayName = 'Mercredi'; break;
                                case 'thursday': dayName = 'Jeudi'; break;
                                case 'friday': dayName = 'Vendredi'; break;
                                case 'saturday': dayName = 'Samedi'; break;
                                case 'sunday': dayName = 'Dimanche'; break;
                                default: dayName = day;
                              }
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time, color: Colors.orange),
                                    const SizedBox(width: 8),
                                    Text(
                                      dayName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.left,
                                    ),
                                    const Spacer(),
                                    Text(
                                      '${hours['start']} - ${hours['end']}',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  // Reviews
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Avis (${_reviews.length})',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              // Only show "Add Review" button if not viewing own profile
                              if (!widget.isOwnProfile)
                                TextButton.icon(
                                  icon: const Icon(Icons.rate_review),
                                  label: const Text('Ajouter un avis'),
                                  onPressed: () {
                                    _showReviewDialog();
                                  },
                                ),
                            ],
                          ),
                          const Divider(),
                          _reviews.isEmpty
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: Text('Aucun avis pour le moment'),
                                  ),
                                )
                              : Column(
                                  children: _reviews.map((review) {
                                    final timestamp = review['timestamp'] as Timestamp;
                                    final date = timestamp.toDate();
                                    final formattedDate = '${date.day}/${date.month}/${date.year}';
                                    
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 16.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              CircleAvatar(
                                                radius: 20,
                                                backgroundImage: review['userAvatar'] != null
                                                    ? NetworkImage(review['userAvatar'])
                                                    : null,
                                                child: review['userAvatar'] == null
                                                    ? Text((review['userName'] as String).isNotEmpty
                                                        ? (review['userName'] as String)[0]
                                                        : '?')
                                                    : null,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      review['userName'] as String,
                                                      style: const TextStyle(
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                    Text(
                                                      formattedDate,
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Row(
                                                children: [
                                                  const Icon(
                                                    Icons.star,
                                                    color: Colors.amber,
                                                    size: 16,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    (review['rating'] as double).toStringAsFixed(1),
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          if (review['comment'] != null && (review['comment'] as String).isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            Text(review['comment'] as String),
                                          ],
                                          if (_reviews.indexOf(review) < _reviews.length - 1) 
                                            const Divider(height: 24),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: widget.isOwnProfile 
          ? Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('Modifier mon profil', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () {
                  // Navigate to profile edit page using GoRouter
                  context.push('/prestataireHome/editProfile', extra: {
                    'providerId': widget.providerId,
                    'providerData': widget.providerData,
                    'userData': widget.userData,
                  });
                },
              )
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: () {
                  _showRequestServiceDialog();
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Demander un service',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          );
        }
      

// Add this method to your _ProviderProfilePageState class
  Future<void> _navigateToConversation() async {
    if (currentUserId == null) return;
    
    try {
      // Check if a conversation already exists
      final conversationsQuery = await FirebaseFirestore.instance
          .collection('service_conversations')
          .where('participants', arrayContains: currentUserId)
          .get();
      
      String? existingConversationId;
      
      for (var doc in conversationsQuery.docs) {
        final participants = List<String>.from(doc['participants'] ?? []);
        if (participants.contains(widget.providerId)) {
          existingConversationId = doc.id;
          break;
        }
      }
      
      if (existingConversationId != null) {
        // Navigate to existing conversation
        if (mounted) {
          context.push('/clientHome/chat/service/$existingConversationId', extra: {
            'otherUserId': widget.providerId,
            'otherUserName': '${widget.userData['firstname']} ${widget.userData['lastname']}',
            'serviceName': widget.serviceName,
          });
        }
      } else {
        // Create a new conversation
        final conversationRef = await FirebaseFirestore.instance
            .collection('service_conversations')
            .add({
              'participants': [currentUserId, widget.providerId],
              'lastMessage': 'Nouvelle conversation',
              'lastMessageTimestamp': FieldValue.serverTimestamp(),
              'createdAt': FieldValue.serverTimestamp(),
              'serviceName': widget.serviceName,
            });
        
        if (mounted) {
          context.push('/clientHome/chat/service/${conversationRef.id}', extra: {
            'otherUserId': widget.providerId,
            'otherUserName': '${widget.userData['firstname']} ${widget.userData['lastname']}',
            'serviceName': widget.serviceName,
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }
}