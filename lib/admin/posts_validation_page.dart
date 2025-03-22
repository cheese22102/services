import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../chat/notifications_service.dart';

class PostsValidationPage extends StatefulWidget {
  const PostsValidationPage({super.key});

  @override
  State<PostsValidationPage> createState() => _PostsValidationPageState();
}

class _PostsValidationPageState extends State<PostsValidationPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Validation des Posts'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('marketplace')
            .where('isValidated', isEqualTo: false)
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
                          onPressed: () => _rejectPost(post.id),
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
      print('Erreur lors de la validation: $e');
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

  Future<void> _rejectPost(String postId) async {
    try {
      final postDoc = await FirebaseFirestore.instance
          .collection('marketplace')
          .doc(postId)
          .get();
      
      final postData = postDoc.data();
      if (postData == null) return;

      // Send notification before deleting the post
      await NotificationsService.sendMarketplaceNotification(
        userId: postData['userId'],
        title: 'Publication Refusée',
        body: 'Votre publication "${postData['title']}" n\'a pas été approuvée. Veuillez vérifier les critères de publication.',
        postId: postId,
        action: 'rejected',
      );

      // Delete the post
      await FirebaseFirestore.instance
          .collection('marketplace')
          .doc(postId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Publication refusée et supprimée'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Erreur lors du refus: $e');
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