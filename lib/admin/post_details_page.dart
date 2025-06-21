import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../notifications_service.dart'; // Assuming this service can send marketplace notifications
import 'package:intl/intl.dart'; // For date formatting
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts
import '../front/app_colors.dart'; // Import AppColors

class PostDetailsPage extends StatefulWidget {
  final String postId;

  const PostDetailsPage({
    super.key,
    required this.postId,
  });

  @override
  State<PostDetailsPage> createState() => _PostDetailsPageState();
}

class _PostDetailsPageState extends State<PostDetailsPage> {
  final TextEditingController _rejectionReasonController = TextEditingController();
  bool _isLoading = true;
  Map<String, dynamic>? _postData;
  Map<String, dynamic>? _posterData; // To store user data of the post creator
  String? _categoryName; // To store the category name
  String? _errorMessage;

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
  void initState() {
    super.initState();
    _loadPostData();
  }

  @override
  void dispose() {
    _rejectionReasonController.dispose();
    super.dispose();
  }

  Future<void> _loadPostData() async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('marketplace')
          .doc(widget.postId)
          .get();

      if (!docSnapshot.exists) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Publication non trouvée';
        });
        return;
      }

      final postData = docSnapshot.data()!;

      // Fetch user data from users collection (poster of the post)
      final userId = postData['userId'] as String;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        _posterData = userDoc.data()!;
      }

      // Fetch category name
      final categoryId = postData['category'] as String?;
      String? fetchedCategoryName;
      if (categoryId != null && categoryId.isNotEmpty) {
        final categoryDoc = await FirebaseFirestore.instance
            .collection('services') // Assuming categories are stored in 'services' collection
            .doc(categoryId)
            .get();
        if (categoryDoc.exists) {
          fetchedCategoryName = categoryDoc.data()?['name'] as String?;
        }
      }

      setState(() {
        _postData = postData;
        _posterData = _posterData; // Keep existing poster data
        _categoryName = fetchedCategoryName; // Set the fetched category name
        _isLoading = false;
        // Pre-fill rejection reason if already rejected
        if (_postData!['isRejected'] == true && _postData!['rejectionReason'] != null) {
          _rejectionReasonController.text = _postData!['rejectionReason'];
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors du chargement des données: $e';
      });
    }
  }

  Widget _buildUserInfoSection(Map<String, dynamic>? userData, bool isDarkMode) {
    if (userData == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          'Informations de l\'utilisateur non disponibles',
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
        ),
      );
    }

    final photoURL = userData['avatarUrl'] as String?; // Changed from photoURL to avatarUrl
    final firstName = userData['firstname'] as String? ?? 'Non spécifié';
    final lastName = userData['lastname'] as String? ?? 'Non spécifié';
    final email = userData['email'] as String? ?? 'Non spécifié';
    final phone = userData['phone'] as String? ?? 'Non spécifié';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: isDarkMode ? AppColors.darkCardBackground : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (photoURL != null && photoURL.isNotEmpty)
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
                        color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
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
                      color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                      border: Border.all(
                        color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.person,
                      size: 40,
                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey,
                    ),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$firstName $lastName',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildInfoItem(Icons.email, email, isDarkMode),
                      _buildInfoItem(Icons.phone, phone, isDarkMode),
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

  Widget _buildInfoItem(IconData icon, String text, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: isDarkMode ? Colors.grey.shade400 : Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
    );
  }

  Widget _buildPostImagesSection(Map<String, dynamic> data, bool isDarkMode) {
    final images = List<String>.from(data['images'] ?? []);

    if (images.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          'Aucune image fournie pour cette publication',
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: images.length,
            itemBuilder: (context, index) {
              final imageUrl = images[index];
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: GestureDetector(
                  onTap: () => _showFullScreenImage(context, imageUrl),
                  child: Container(
                    width: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: isDarkMode ? Colors.grey.shade700 : Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Center(
                            child: Text(
                              'Erreur de chargement',
                              style: GoogleFonts.poppins(
                                color: isDarkMode ? Colors.red.shade300 : Colors.red.shade700,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(String postId, Map<String, dynamic> data, bool isDarkMode) {
    final isValidated = data['isValidated'] as bool? ?? false;
    final isRejected = data['isRejected'] as bool? ?? false;
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;

    if (isValidated || isRejected) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isValidated
              ? (isDarkMode ? Colors.green.shade900.withOpacity(0.3) : Colors.green.shade50)
              : (isDarkMode ? Colors.red.shade900.withOpacity(0.3) : Colors.red.shade50),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isValidated
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
                  isValidated ? Icons.check_circle : Icons.cancel,
                  color: isValidated
                      ? (isDarkMode ? Colors.green.shade300 : Colors.green.shade700)
                      : (isDarkMode ? Colors.red.shade300 : Colors.red.shade700),
                ),
                const SizedBox(width: 12),
                Text(
                  isValidated ? 'Publication approuvée' : 'Publication rejetée',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isValidated
                        ? (isDarkMode ? Colors.green.shade300 : Colors.green.shade700)
                        : (isDarkMode ? Colors.red.shade300 : Colors.red.shade700),
                  ),
                ),
              ],
            ),
            if (isRejected && data['rejectionReason'] != null) ...[
              const SizedBox(height: 12),
              Text(
                'Motif: ${data['rejectionReason']}',
                style: GoogleFonts.poppins(
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
        StatefulBuilder( // Use StatefulBuilder to manage dialog state
          builder: (context, setState) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Veuillez indiquer la raison du rejet de cette publication:',
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
                    filled: true,
                    fillColor: isDarkMode ? AppColors.darkInputBackground : AppColors.lightInputBackground,
                  ),
                  style: GoogleFonts.poppins(
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  maxLines: 3,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
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
                  _rejectPost(postId, finalReason);
                },
                icon: const Icon(Icons.cancel),
                label: Text(
                  'Rejeter',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
                onPressed: () => _showApprovalConfirmationDialog(postId), // Call confirmation dialog
                icon: const Icon(Icons.check_circle),
                label: Text(
                  'Approuver',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
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

  void _showApprovalConfirmationDialog(String postId) {
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
            'Confirmer l\'approbation',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          content: Text(
            'Voulez-vous vraiment approuver cette publication ?',
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
                _approvePost(postId);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Approuver',
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

  Future<void> _approvePost(String postId) async {
    try {
      final postDoc = await FirebaseFirestore.instance
          .collection('marketplace')
          .doc(postId)
          .get();

      final postData = postDoc.data();
      if (postData == null) return;

      await FirebaseFirestore.instance
          .collection('marketplace')
          .doc(postId)
          .update({
        'isValidated': true,
        'isRejected': false, // Ensure it's not marked as rejected
        'validationDate': FieldValue.serverTimestamp(),
        'adminComment': _rejectionReasonController.text.trim(), // Store any comment
      });

      // Send notification to the post creator
      final userId = postData['userId'];
      if (userId != null) {
        await NotificationsService.sendMarketplaceNotification(
          userId: userId,
          title: 'Publication Approuvée',
          body: 'Votre publication "${postData['title'] ?? 'N/A'}" a été approuvée et est maintenant visible.',
          postId: postId,
          action: 'validated',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Publication approuvée avec succès')),
        );
        context.go('/admin/posts'); // Navigate back to posts list
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de l\'approbation: $e')),
      );
    }
  }

  Future<void> _rejectPost(String postId, String rejectionReason) async {
    if (rejectionReason.isEmpty) { // Use the passed rejectionReason
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez fournir un motif de rejet')),
      );
      return;
    }

    try {
      final postDoc = await FirebaseFirestore.instance
          .collection('marketplace')
          .doc(postId)
          .get();

      final postData = postDoc.data();
      if (postData == null) return;

      await FirebaseFirestore.instance
          .collection('marketplace')
          .doc(postId)
          .update({
        'isValidated': false,
        'isRejected': true,
        'rejectionReason': rejectionReason, // Use the passed rejectionReason
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      // Send notification to the post creator
      final userId = postData['userId'];
      if (userId != null) {
        await NotificationsService.sendMarketplaceNotification(
          userId: userId,
          title: 'Publication Refusée',
          body: 'Votre publication "${postData['title'] ?? 'N/A'}" a été rejetée. Raison: $rejectionReason', // Use the passed rejectionReason
          postId: postId,
          action: 'rejected',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Publication rejetée avec succès')),
        );
        context.go('/admin/posts'); // Navigate back to posts list
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du rejet: $e')),
      );
    }
  }

  void _showFullScreenImage(BuildContext context, String imageUrl) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;

    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              'Visualisation de l\'image',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            backgroundColor: isDarkMode ? AppColors.darkBackground : Colors.white,
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
                      color: primaryColor,
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
                        style: GoogleFonts.poppins(
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

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Détails de la publication',
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
          onPressed: () => context.go('/admin/posts'),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: primaryColor,
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Text(
                    _errorMessage!,
                    style: GoogleFonts.poppins(
                      color: Colors.red[700],
                      fontSize: 16,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Informations sur la publication', isDarkMode),
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: isDarkMode ? AppColors.darkCardBackground : Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _postData!['title'] ?? 'Titre non spécifié',
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Prix: ${_postData!['price']?.toStringAsFixed(2) ?? 'N/A'} DT',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: isDarkMode ? AppColors.primaryGreen : Colors.green.shade700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _postData!['description'] ?? 'Description non spécifiée',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  color: isDarkMode ? Colors.white70 : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Catégorie: ${_categoryName ?? 'Non spécifiée'}',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Date de publication: ${DateFormat('dd/MM/yyyy à HH:mm').format((_postData!['createdAt'] as Timestamp).toDate())}',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 32),
                      _buildSectionTitle('Images de la publication', isDarkMode),
                      Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: isDarkMode ? AppColors.darkCardBackground : Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildPostImagesSection(_postData!, isDarkMode),
                        ),
                      ),
                      const Divider(height: 32),
                      _buildSectionTitle('Informations sur l\'auteur', isDarkMode),
                      _buildUserInfoSection(_posterData, isDarkMode),
                      const Divider(height: 32),
                      _buildSectionTitle('Action', isDarkMode),
                      _buildActionButtons(widget.postId, _postData!, isDarkMode),
                    ],
                  ),
                ),
    );
  }
}
