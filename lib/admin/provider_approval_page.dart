import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../notifications_service.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts
import '../front/app_colors.dart'; // Import AppColors
import '../front/loading_overlay.dart'; // Import LoadingOverlay

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

  // Modified method to display user information with consistent styling
  Widget _buildUserInfoSection(Map<String, dynamic> data, bool isDarkMode) {
    final userData = data['userData'] as Map<String, dynamic>?;
    
    if (userData == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          'Informations utilisateur non disponibles',
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
        ),
      );
    }
    
    final avatarURL = userData['avatarURL'] as String?;
    final firstName = userData['firstname'] as String? ?? 'Non spécifié';
    final lastName = userData['lastname'] as String? ?? 'Non spécifié';
    final email = userData['email'] as String? ?? 'Non spécifié';
    final phone = userData['phone'] as String? ?? 'Non spécifié';
    final gender = userData['gender'] as String? ?? 'Non spécifié';
    final age = userData['age']?.toString() ?? 'Non spécifié';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2, // Consistent elevation
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: isDarkMode ? AppColors.darkCardBackground : Colors.white, // Consistent card background
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User photo
                if (avatarURL != null && avatarURL.isNotEmpty)
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      image: DecorationImage(
                        image: NetworkImage(avatarURL),
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
                
                // User details
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
                      _buildUserInfoItem(Icons.email, email, isDarkMode),
                      _buildUserInfoItem(Icons.phone, phone, isDarkMode),
                      _buildUserInfoItem(Icons.person, 'Genre: $gender', isDarkMode),
                      _buildUserInfoItem(Icons.cake, 'Âge: $age ans', isDarkMode),
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

  // Modified _buildUserInfoItem to accept isDarkMode
  Widget _buildUserInfoItem(IconData icon, String text, bool isDarkMode) {
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

  // Update the project photos section to use the correct field name
  Widget _buildProjectPhotosSection(Map<String, dynamic> data, bool isDarkMode) {
    final projectPhotos = List<String>.from(data['projectPhotos'] ?? []);
    
    if (projectPhotos.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          'Aucune photo de projet fournie',
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
        ),
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
                border: Border.all(color: isDarkMode ? Colors.grey.shade700 : Colors.grey),
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
        title: Text(
          'Détails du prestataire',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        backgroundColor: isDarkMode ? AppColors.darkBackground : Colors.white,
        elevation: 4, // Consistent elevation
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin/providers'),
        ),
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
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
                      // User info section
                      _buildSectionTitle('Informations personnelles', isDarkMode),
                      _buildUserInfoSection(_providerData!, isDarkMode), // Pass isDarkMode
                      
                      const Divider(height: 32),
                      
                      // Services section
                      _buildSectionTitle('Services proposés', isDarkMode),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: isDarkMode ? AppColors.darkCardBackground : Colors.white,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildServicesList(_providerData!, isDarkMode), // Pass isDarkMode
                        ),
                      ),
                      
                      const Divider(height: 32),
                      
                      // Documents section
                      _buildSectionTitle('Pièce d\'identité', isDarkMode),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: isDarkMode ? AppColors.darkCardBackground : Colors.white,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildIdCard(_providerData!, isDarkMode), // Pass isDarkMode
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      _buildSectionTitle('Selfie avec pièce d\'identité', isDarkMode),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: isDarkMode ? AppColors.darkCardBackground : Colors.white,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildSelfieWithId(_providerData!, isDarkMode), // Pass isDarkMode
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      _buildSectionTitle('Patente', isDarkMode),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: isDarkMode ? AppColors.darkCardBackground : Colors.white,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildPatente(_providerData!, isDarkMode), // Pass isDarkMode
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      _buildSectionTitle('Certifications', isDarkMode),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: isDarkMode ? AppColors.darkCardBackground : Colors.white,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildCertifications(_providerData!, isDarkMode), // Pass isDarkMode
                        ),
                      ),
                      
                      const Divider(height: 32),
                      
                      // Project Photos section
                      _buildSectionTitle('Photos de projets', isDarkMode),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: isDarkMode ? AppColors.darkCardBackground : Colors.white,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildProjectPhotosSection(_providerData!, isDarkMode), // Pass isDarkMode
                        ),
                      ),
                      
                      const Divider(height: 32),
                      
                      // Professional info section
                      _buildSectionTitle('Informations professionnelles', isDarkMode),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: isDarkMode ? AppColors.darkCardBackground : Colors.white,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildProfessionalInfo(_providerData!, isDarkMode), // Pass isDarkMode
                        ),
                      ),
                      
                      const Divider(height: 32),
                      
                      // Location section
                      _buildSectionTitle('Localisation', isDarkMode),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: isDarkMode ? AppColors.darkCardBackground : Colors.white,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildLocationInfo(_providerData!, isDarkMode), // Pass isDarkMode
                        ),
                      ),
                      
                      const Divider(height: 32),
                      
                      // Working hours section
                      _buildSectionTitle('Horaires de travail', isDarkMode),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: isDarkMode ? AppColors.darkCardBackground : Colors.white,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildWorkingHours(_providerData!, isDarkMode), // Pass isDarkMode
                        ),
                      ),
                      
                      const Divider(height: 32),
                      
                      // Action section
                      _buildSectionTitle('Action', isDarkMode),
                      _buildActionButtons(widget.providerId, _providerData!, isDarkMode),
                    ],
                  ),
                ),
    );
  }

  // Add methods to display selfie with ID and patente
  Widget _buildSelfieWithId(Map<String, dynamic> data, bool isDarkMode) {
    final selfieWithIdUrl = data['selfieWithIdUrl'] as String?;
    
    if (selfieWithIdUrl == null || selfieWithIdUrl.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          'Aucun selfie avec pièce d\'identité fourni',
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: isDarkMode ? Colors.grey.shade700 : Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Image.network(
            selfieWithIdUrl,
            fit: BoxFit.contain,
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
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => _showFullScreenImage(context, selfieWithIdUrl),
          icon: Icon(Icons.fullscreen, color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen),
          label: Text(
            'Voir en plein écran',
            style: GoogleFonts.poppins(
              color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPatente(Map<String, dynamic> data, bool isDarkMode) {
    final patenteUrl = data['patenteUrl'] as String?;
    
    if (patenteUrl == null || patenteUrl.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          'Aucune patente fournie (optionnel)',
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: isDarkMode ? Colors.grey.shade700 : Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Image.network(
            patenteUrl,
            fit: BoxFit.contain,
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
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => _showFullScreenImage(context, patenteUrl),
          icon: Icon(Icons.fullscreen, color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen),
          label: Text(
            'Voir en plein écran',
            style: GoogleFonts.poppins(
              color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
            ),
          ),
        ),
      ],
    );
  }

  // Update the professional info method to include more details
  Widget _buildProfessionalInfo(Map<String, dynamic> data, bool isDarkMode) {
    final experiences = List<Map<String, dynamic>>.from(data['experiences'] ?? []);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoItem('Bio', data['bio'] ?? 'Non spécifiée', isDarkMode),
        
        const SizedBox(height: 16),
        Text(
          'Expériences',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        
        if (experiences.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'Aucune expérience spécifiée',
              style: GoogleFonts.poppins(
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: experiences.length,
            itemBuilder: (context, index) {
              final exp = experiences[index];
              final service = exp['service'] as String? ?? 'Non spécifié';
              final int yearsInt = exp['years'] as int? ?? 0;
              final String yearsDisplay = yearsInt == 5 ? '5+' : yearsInt.toString();

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                elevation: 1, // Slightly less elevation for nested cards
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100, // Lighter background for nested cards
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$yearsDisplay ans d\'expérience', // Display the string range directly
                        style: GoogleFonts.poppins(
                          color: isDarkMode ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
    ],
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
  
  Widget _buildServicesList(Map<String, dynamic> data, bool isDarkMode) {
    final services = List<String>.from(data['services'] ?? []);
    
    if (services.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          'Aucun service proposé',
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8, // Add runSpacing for better layout
      children: services.map((service) {
        return Chip(
          label: Text(
            service,
            style: GoogleFonts.poppins(
              color: isDarkMode ? Colors.white : AppColors.primaryDarkGreen, // Adjust chip text color
            ),
          ),
          backgroundColor: isDarkMode ? AppColors.primaryGreen.withOpacity(0.3) : Colors.blue.shade100, // Adjust chip background
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: isDarkMode ? AppColors.primaryGreen : Colors.blue.shade200), // Add border
          ),
        );
      }).toList(),
    );
  }
  
  Widget _buildIdCard(Map<String, dynamic> data, bool isDarkMode) {
    final idCardUrl = data['idCardUrl'] as String?;
    
    if (idCardUrl == null || idCardUrl.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          'Aucune pièce d\'identité fournie',
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: isDarkMode ? Colors.grey.shade700 : Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Image.network(
            idCardUrl,
            fit: BoxFit.contain,
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
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => _showFullScreenImage(context, idCardUrl),
          icon: Icon(Icons.fullscreen, color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen),
          label: Text(
            'Voir en plein écran',
            style: GoogleFonts.poppins(
              color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildCertifications(Map<String, dynamic> data, bool isDarkMode) {
    final certifications = List<String>.from(data['certifications'] ?? []);
    final certificationFiles = List<String>.from(data['certificationFiles'] ?? []);
    
    if (certifications.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          'Aucune certification fournie',
          style: GoogleFonts.poppins(
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
        ),
      );
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
            elevation: 1, // Slightly less elevation for nested cards
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100, // Lighter background for nested cards
            child: ListTile(
              title: Text(
                certName,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              subtitle: Text(
                'Aucun fichier associé',
                style: GoogleFonts.poppins(
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
          );
        }
        
        return Card(
          elevation: 1, // Slightly less elevation for nested cards
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100, // Lighter background for nested cards
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  certName,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: isDarkMode ? Colors.grey.shade700 : Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Image.network(
                    certUrl,
                    fit: BoxFit.contain,
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
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => _showFullScreenImage(context, certUrl),
                  icon: Icon(Icons.fullscreen, color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen),
                  label: Text(
                    'Voir en plein écran',
                    style: GoogleFonts.poppins(
                      color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  
  Widget _buildInfoItem(String label, String value, bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.poppins(
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLocationInfo(Map<String, dynamic> data, bool isDarkMode) {
    final exactLocation = data['exactLocation'] as Map<String, dynamic>?;
    final address = exactLocation?['address'] as String? ?? 'Adresse non spécifiée';
    final latitude = exactLocation?['latitude'] as double? ?? 0.0;
    final longitude = exactLocation?['longitude'] as double? ?? 0.0;
    final workingArea = data['workingArea'] as String? ?? 'Non spécifiée';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInfoItem('Adresse', address, isDarkMode),
        _buildInfoItem('Zone d\'intervention', workingArea, isDarkMode),
        const SizedBox(height: 8),
        
        // Map widget
        if (latitude != 0.0 && longitude != 0.0)
          Container(
            height: 300,
            decoration: BoxDecoration(
              border: Border.all(color: isDarkMode ? Colors.grey.shade700 : Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: GoogleMap(
                mapType: MapType.normal,
                initialCameraPosition: CameraPosition(
                  target: LatLng(latitude, longitude),
                  zoom: 15.0,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('provider_location'),
                    position: LatLng(latitude, longitude),
                    infoWindow: const InfoWindow(title: 'Provider Location'),
                    icon: BitmapDescriptor.defaultMarkerWithHue(
                      isDarkMode ? BitmapDescriptor.hueGreen : BitmapDescriptor.hueRed,
                    ),
                  ),
                },
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                onMapCreated: (GoogleMapController controller) {
                  // No need to store controller if not interacting with map after creation
                },
              ),
            ),
          ),
      ],
    );
  }
  
  Widget _buildWorkingHours(Map<String, dynamic> data, bool isDarkMode) {
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
            title: Text(
              dayName,
              style: GoogleFonts.poppins(
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            subtitle: Text(
              'Jour non travaillé',
              style: GoogleFonts.poppins(
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
            leading: Icon(Icons.cancel, color: isDarkMode ? Colors.red.shade300 : Colors.red),
          );
        }
        
        final hours = workingHours[day];
        final startTime = hours?['start'] ?? '00:00';
        final endTime = hours?['end'] ?? '00:00';
        
        return ListTile(
          title: Text(
            dayName,
            style: GoogleFonts.poppins(
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          subtitle: Text(
            '$startTime - $endTime',
            style: GoogleFonts.poppins(
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
          ),
          leading: Icon(Icons.check_circle, color: isDarkMode ? Colors.green.shade300 : Colors.green),
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
                  style: GoogleFonts.poppins( // Use GoogleFonts
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
                style: GoogleFonts.poppins( // Use GoogleFonts
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
          elevation: 2, // Consistent elevation
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: isDarkMode ? AppColors.darkCardBackground : Colors.white, // Consistent card background
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Liste de vérification',
                  style: GoogleFonts.poppins( // Use GoogleFonts
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                ...(_checkList.map((item) => CheckboxListTile(
                      title: Text(
                        item.title,
                        style: GoogleFonts.poppins( // Use GoogleFonts
                          fontWeight: FontWeight.w500,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                      subtitle: Text(
                        item.description,
                        style: GoogleFonts.poppins( // Use GoogleFonts
                          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                        ),
                      ),
                      value: item.isVerified,
                      activeColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen, // Consistent active color
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
          style: GoogleFonts.poppins( // Use GoogleFonts
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            labelText: 'Motif de rejet (obligatoire en cas de rejet)',
            labelStyle: GoogleFonts.poppins( // Use GoogleFonts
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
                color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen, // Consistent focused border color
                width: 2,
              ),
            ),
            filled: true,
            fillColor: isDarkMode ? AppColors.darkInputBackground : AppColors.lightInputBackground, // Consistent fill color
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
                onPressed: () => _approveProvider(providerId),
                icon: const Icon(Icons.check_circle),
                label: Text(
                  'Approuver',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen, // Consistent approve button color
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
    
    LoadingOverlay.show(context); // Show loading overlay
    try {
      // Update the status to approved
      await FirebaseFirestore.instance
          .collection('providers')
          .doc(providerId)
          .update({
        'status': 'approved',
        'approvalDate': FieldValue.serverTimestamp(),
        'adminComment': _commentController.text,
        // Initialize only overall rating in the main document
        'rating': 0.0,
        'reviewCount': 0,
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
  
      LoadingOverlay.hide(); // Hide loading overlay BEFORE navigation

      // Show success message and navigate back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prestataire approuvé avec succès')),
        );
        context.go('/admin/providers'); // Update navigation to use GoRouter
      }
    } catch (e) {
      LoadingOverlay.hide(); // Hide loading overlay on error as well
      if (mounted) { // Ensure widget is still mounted before showing SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
    // finally block for LoadingOverlay.hide() is removed as it's handled in try/catch
  }
  
  // Function to reject a provider
  Future<void> _rejectProvider(String providerId) async {
    if (_commentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez fournir un motif de rejet')),
      );
      return;
    }
  
    LoadingOverlay.show(context); // Show loading overlay
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
  
      LoadingOverlay.hide(); // Hide loading overlay BEFORE navigation

      // Show success message and navigate back
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Prestataire rejeté avec succès')),
        );
        context.go('/admin/providers'); // Update navigation to use GoRouter
      }
    } catch (e) {
      LoadingOverlay.hide(); // Hide loading overlay on error as well
      if (mounted) { // Ensure widget is still mounted before showing SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
    // finally block for LoadingOverlay.hide() is removed as it's handled in try/catch
  }
  
  void _showFullScreenImage(BuildContext context, String imageUrl) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: Text( // Use Text widget for title
              'Visualisation du document',
              style: GoogleFonts.poppins( // Use GoogleFonts
                fontWeight: FontWeight.w600,
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
            backgroundColor: isDarkMode ? AppColors.darkBackground : Colors.white, // Consistent background
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
                      color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen, // Consistent color
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
                        style: GoogleFonts.poppins( // Use GoogleFonts
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
