import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../notifications_service.dart';
import 'package:go_router/go_router.dart'; // Add this import
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts
import '../front/app_colors.dart'; // Import AppColors

class PostsValidationPage extends StatefulWidget {
  const PostsValidationPage({super.key});

  @override
  State<PostsValidationPage> createState() => _PostsValidationPageState();
}

class _PostsValidationPageState extends State<PostsValidationPage> {
  final _rejectionReasonController = TextEditingController();
  final List<String> _predefinedReasons = [
    'Problème(s) avec l\'image(s)',
    'Prix irréaliste',
    'Description insuffisante',
    'Contenu inapproprié',
    'Informations manquantes',
    'Catégorie incorrecte',
  ];
  List<String> _selectedReasons = [];

  @override
  void dispose() {
    _rejectionReasonController.dispose();
    super.dispose();
  }

  void _showRejectionDialog(String postId) {
    _rejectionReasonController.clear();
    _selectedReasons = []; // Clear previous selections

    showDialog(
      context: context,
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;

        return StatefulBuilder( // Use StatefulBuilder to manage dialog state
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: isDarkMode ? AppColors.darkCardBackground : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Raison du refus',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Veuillez indiquer la raison du refus de cette publication:',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._predefinedReasons.map((reason) {
                      return CheckboxListTile(
                        title: Text(
                          reason,
                          style: GoogleFonts.poppins(
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        value: _selectedReasons.contains(reason),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              _selectedReasons.add(reason);
                            } else {
                              _selectedReasons.remove(reason);
                            }
                          });
                        },
                        activeColor: primaryColor,
                        checkColor: Colors.white,
                      );
                    }).toList(),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _rejectionReasonController,
                      style: GoogleFonts.poppins(
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Autre raison (optionnel)',
                        labelStyle: GoogleFonts.poppins(
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
                            color: primaryColor,
                            width: 2,
                          ),
                        ),
                        hintText: 'Ajoutez une raison personnalisée',
                        hintStyle: GoogleFonts.poppins(
                          color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
                        ),
                        filled: true,
                        fillColor: isDarkMode ? AppColors.darkInputBackground : AppColors.lightInputBackground,
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _rejectionReasonController.clear();
                    _selectedReasons = [];
                  },
                  child: Text(
                    'Annuler',
                    style: GoogleFonts.poppins(
                      color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final customReason = _rejectionReasonController.text.trim();
                    if (_selectedReasons.isEmpty && customReason.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Veuillez sélectionner ou indiquer au moins une raison'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    String finalReason = _selectedReasons.join(', ');
                    if (customReason.isNotEmpty) {
                      if (finalReason.isNotEmpty) {
                        finalReason += ', ';
                      }
                      finalReason += customReason;
                    }

                    Navigator.pop(context);
                    _rejectPost(postId, finalReason);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Refuser',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showValidationConfirmationDialog(String postId) {
    showDialog(
      context: context,
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;
        return AlertDialog(
          backgroundColor: isDarkMode ? AppColors.darkCardBackground : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Confirmer la validation',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          content: Text(
            'Voulez-vous vraiment valider cette publication ?',
            style: GoogleFonts.poppins(
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Annuler',
                style: GoogleFonts.poppins(
                  color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _validatePost(postId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Valider',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Validation des Posts',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        backgroundColor: isDarkMode ? AppColors.darkBackground : Colors.white,
        elevation: 4,
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'), // Update navigation to use GoRouter
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('marketplace')
            .where('isValidated', isEqualTo: false)
            .where('isRejected', isEqualTo: false) // Exclude rejected posts
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Une erreur est survenue',
                style: GoogleFonts.poppins(
                  color: Colors.red[700],
                  fontSize: 16,
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: primaryColor,
              ),
            );
          }

          final posts = snapshot.data?.docs ?? [];

          if (posts.isEmpty) {
            return Center(
              child: Text(
                'Aucun post en attente de validation',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
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
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: isDarkMode ? AppColors.darkCardBackground : Colors.white,
                child: InkWell( // Use InkWell for tap effect
                  onTap: () {
                    context.push('/admin/posts/${post.id}'); // Navigate to post details page
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (images.isNotEmpty)
                        SizedBox(
                          height: 200,
                          child: PageView.builder(
                            itemCount: images.length,
                            itemBuilder: (context, imageIndex) {
                              return ClipRRect(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                                child: Image.network(
                                  images[imageIndex],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        color: primaryColor,
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return Center(
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        size: 50,
                                        color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                                      ),
                                    );
                                  },
                                ),
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
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              data['description'] ?? '',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                color: isDarkMode ? Colors.white70 : Colors.black87,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${data['price']?.toStringAsFixed(2) ?? 'N/A'} DT',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: isDarkMode ? AppColors.primaryGreen : Colors.green.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => _showRejectionDialog(post.id),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red.shade600,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Rejeter',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _showValidationConfirmationDialog(post.id), // Call confirmation dialog
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Valider',
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
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
