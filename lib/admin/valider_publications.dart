import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../notifications_service.dart';
import 'package:go_router/go_router.dart'; // Add this import

class PostsValidationPage extends StatefulWidget {
  const PostsValidationPage({super.key});

  @override
  State<PostsValidationPage> createState() => _PostsValidationPageState();
}

class _PostsValidationPageState extends State<PostsValidationPage> {
  final _rejectionReasonController = TextEditingController();

  @override
  void dispose() {
    _rejectionReasonController.dispose();
    super.dispose();
  }

  void _showRejectionDialog(String postId) {
    _rejectionReasonController.clear(); 
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Raison du refus'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Veuillez indiquer la raison du refus de cette publication',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _rejectionReasonController,
              decoration: const InputDecoration(
                labelText: 'Raison',
                border: OutlineInputBorder(),
                hintText: 'Expliquez pourquoi la publication est refusée',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _rejectionReasonController.clear();
            },
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_rejectionReasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Veuillez indiquer une raison'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context);
              _rejectPost(postId, _rejectionReasonController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Refuser'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Validation des Posts'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'), // Update navigation to use GoRouter
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('marketplace')
            .where('isValidated', isEqualTo: false)
            .where('isRejected', isEqualTo: false) // Add this line to filter out rejected posts
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Une erreur est survenue'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final posts = snapshot.data?.docs ?? [];

          if (posts.isEmpty) {
            return const Center(
              child: Text('Aucun post en attente de validation'),
            );
          }

          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final data = post.data() as Map<String, dynamic>;
              final images = List<String>.from(data['images'] ?? []);

              return Card(
                margin: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (images.isNotEmpty)
                      SizedBox(
                        height: 200,
                        child: PageView.builder(
                          itemCount: images.length,
                          itemBuilder: (context, imageIndex) {
                            return Image.network(
                              images[imageIndex],
                              fit: BoxFit.cover,
                            );
                          },
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data['title'] ?? '',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(data['description'] ?? ''),
                          const SizedBox(height: 8),
                          Text(
                            '${data['price']} DT',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ButtonBar(
                      children: [
                        TextButton(
                          onPressed: () => _showRejectionDialog(post.id),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('Rejeter'),
                        ),
                        ElevatedButton(
                          onPressed: () => _validatePost(post.id),
                          child: const Text('Valider'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _validatePost(String postId) async {
    try {
      final postDoc = await FirebaseFirestore.instance
          .collection('marketplace')
          .doc(postId)
          .get();
      
      final postData = postDoc.data();
      if (postData == null) return;

      // Update post status
      await FirebaseFirestore.instance
          .collection('marketplace')
          .doc(postId)
          .update({'isValidated': true});

      // Send notification using NotificationsService
      await NotificationsService.sendMarketplaceNotification(
        userId: postData['userId'],
        title: 'Publication Approuvée',
        body: 'Votre publication "${postData['title']}" a été approuvée et est maintenant visible',
        postId: postId,
        action: 'validated',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Publication approuvée avec succès'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Une erreur est survenue lors de la validation'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

    Future<void> _rejectPost(String postId, String rejectionReason) async {
    try {
      final postDoc = await FirebaseFirestore.instance
          .collection('marketplace')
          .doc(postId)
          .get();
      
      final postData = postDoc.data();
      if (postData == null) return;

      // Update post with rejection information instead of deleting it
      await FirebaseFirestore.instance
          .collection('marketplace')
          .doc(postId)
          .update({
            'isValidated': false,
            'isRejected': true,
            'rejectionReason': rejectionReason,
            'rejectedAt': FieldValue.serverTimestamp(),
          });

      // Send notification with rejection reason
      await NotificationsService.sendMarketplaceNotification(
        userId: postData['userId'],
        title: 'Publication Refusée',
        body: 'Votre publication "${postData['title']}" n\'a pas été approuvée.\n\nRaison: $rejectionReason',
        postId: postId,
        action: 'rejected',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Publication refusée'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Une erreur est survenue lors du refus'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }
}