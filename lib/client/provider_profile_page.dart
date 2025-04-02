import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../chat/conversation_service_page.dart';

class ProviderProfilePage extends StatefulWidget {
  final String providerId;
  final Map<String, dynamic> providerData;
  final Map<String, dynamic> userData;
  final String serviceName;

  const ProviderProfilePage({
    super.key,
    required this.providerId,
    required this.providerData,
    required this.userData,
    required this.serviceName,
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
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.userData['firstname'] as String;
    final lastName = widget.userData['lastname'] as String;
    final avatarUrl = widget.userData['avatarUrl'] as String?;
    final bio = widget.providerData['bio'] as String?;
    final phoneNumber = widget.userData['phoneNumber'] as String?;
    final minRate = widget.providerData['rateRange']['min'];
    final maxRate = widget.providerData['rateRange']['max'];
    final workingArea = widget.providerData['workingArea'] as String?;
    final experience = widget.providerData['experience'] as String?;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profil du prestataire'),
        actions: [
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
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.chat),
                                  label: const Text('Message'),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => ConversationServicePage(
                                          otherUserId: widget.providerId,
                                          otherUserName: '$firstName $lastName',
                                        ),
                                      ),
                                    );
                                  },
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
                          
                          if (experience != null && experience.isNotEmpty)
                            Row(
                              children: [
                                const Icon(Icons.work, color: Colors.blue),
                                const SizedBox(width: 8),
                                Text(
                                  'Expérience: $experience',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          
                          if (experience != null && experience.isNotEmpty)
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
      bottomNavigationBar: Padding(
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

  void _showReviewDialog() {
    double rating = 3.0;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Ajouter un avis'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Note:'),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < rating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                      ),
                      onPressed: () {
                        setState(() {
                          rating = index + 1.0;
                        });
                      },
                    );
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: commentController,
                  decoration: const InputDecoration(
                    labelText: 'Commentaire (optionnel)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (currentUserId == null) return;
                  
                  try {
                    await FirebaseFirestore.instance
                        .collection('provider_reviews')
                        .add({
                      'providerId': widget.providerId,
                      'userId': currentUserId,
                      'rating': rating,
                      'comment': commentController.text.trim(),
                      'timestamp': FieldValue.serverTimestamp(),
                      'serviceName': widget.serviceName,
                    });
                    
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Avis ajouté avec succès')),
                      );
                      _loadReviews(); // Reload reviews
                    }
                  } catch (e) {
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erreur: $e')),
                      );
                    }
                  }
                },
                child: const Text('Soumettre'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showRequestServiceDialog() {
    final descriptionController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = TimeOfDay.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Demander un service'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Veuillez décrire votre besoin:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      hintText: 'Décrivez le service dont vous avez besoin...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Date souhaitée:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 90)),
                          );
                          if (date != null) {
                            setState(() {
                              selectedDate = date;
                            });
                          }
                        },
                        child: const Text('Choisir une date'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Heure souhaitée:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${selectedTime.hour}:${selectedTime.minute.toString().padLeft(2, '0')}',
                        ),
                      ),
                      TextButton(
                        onPressed: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: selectedTime,
                          );
                          if (time != null) {
                            setState(() {
                              selectedTime = time;
                            });
                          }
                        },
                        child: const Text('Choisir une heure'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (currentUserId == null) return;
                  if (descriptionController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Veuillez décrire votre besoin')),
                    );
                    return;
                  }
                  
                  try {
                    // Create service request
                    final requestRef = await FirebaseFirestore.instance
                        .collection('service_requests')
                        .add({
                      'clientId': currentUserId,
                      'providerId': widget.providerId,
                      'serviceName': widget.serviceName,
                      'description': descriptionController.text.trim(),
                      'requestDate': Timestamp.fromDate(DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        selectedTime.hour,
                        selectedTime.minute,
                      )),
                      'status': 'pending',
                      'createdAt': FieldValue.serverTimestamp(),
                    });
                    
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Demande envoyée avec succès')),
                      );
                      
                      // Optionally navigate to requests page
                      // Navigator.pushNamed(context, '/clientHome/my-requests');
                    }
                  } catch (e) {
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Erreur: $e')),
                      );
                    }
                  }
                },
                child: const Text('Envoyer la demande'),
              ),
            ],
          );
        },
      ),
    );
  }}