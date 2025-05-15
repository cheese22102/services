import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'prestataire_sidebar.dart';
import 'provider_notifications_page.dart';
import '../front/app_colors.dart';
import '../front/custom_button.dart';

class PrestataireHomePage extends StatefulWidget {
  const PrestataireHomePage({super.key});

  @override
  State<PrestataireHomePage> createState() => _PrestataireHomePageState();
}

class _PrestataireHomePageState extends State<PrestataireHomePage> {
  late Stream<DocumentSnapshot> _providerRequestStream;

  @override
  void initState() {
    super.initState();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    _providerRequestStream = FirebaseFirestore.instance
        .collection('providers')
        .doc(userId)
        .snapshots();
    _saveFCMToken();
    
    // Debug: Check if the provider request document exists
    if (userId != null) {
      FirebaseFirestore.instance
          .collection('providers')
          .doc(userId)
          .get()
          .then((doc) {
      });
    }
  }

  Future<void> _saveFCMToken() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .update({'fcmToken': token});
      }
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  Widget _buildProviderStatus() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return StreamBuilder<DocumentSnapshot>(
      stream: _providerRequestStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
            ),
          );
        }

        final data = snapshot.data?.data() as Map<String, dynamic>?;
        
        // No application submitted yet
        if (data == null) {
          return _buildNoApplicationView(isDarkMode);
        }

        final status = data['status'] as String?;
        final rejectionReason = data['rejectionReason'] as String?;
        
        switch (status) {
          case 'pending':
            return _buildPendingApplicationView(isDarkMode);
          case 'rejected':
            return _buildRejectedApplicationView(isDarkMode, rejectionReason);
          case 'approved':
            return _buildApprovedApplicationView(isDarkMode);
          default:
            return _buildNoApplicationView(isDarkMode);
        }
      },
    );
  }

  Widget _buildNoApplicationView(bool isDarkMode) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDarkMode ? Colors.grey.shade800 : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_add,
              size: 64,
              color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
            ),
            const SizedBox(height: 24),
            Text(
              'Devenez prestataire de services',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Complétez votre profil prestataire pour commencer à offrir vos services sur notre plateforme.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Compléter mon profil prestataire',
              onPressed: () => context.go('/prestataireHome/registration'),
              backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
              textColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingApplicationView(bool isDarkMode) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDarkMode ? Colors.grey.shade800 : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode 
                  ? Colors.amber.shade900.withOpacity(0.3) 
                  : Colors.amber.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.hourglass_top,
                size: 60,
                color: Colors.amber.shade600,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Demande en cours d\'examen',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Votre demande est en cours d\'examen par notre équipe. Vous recevrez une notification dès qu\'une décision sera prise.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              backgroundColor: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(
                isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectedApplicationView(bool isDarkMode, String? rejectionReason) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDarkMode ? Colors.grey.shade800 : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode 
                  ? Colors.red.shade900.withOpacity(0.3) 
                  : Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                size: 60,
                color: Colors.red.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Demande refusée',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            if (rejectionReason != null && rejectionReason.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.red.shade900.withOpacity(0.2) : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Motif du refus:',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: isDarkMode ? Colors.red.shade300 : Colors.red.shade700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      rejectionReason,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: isDarkMode ? Colors.red.shade200 : Colors.red.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            CustomButton(
              text: 'Soumettre une nouvelle demande',
              onPressed: () => context.go('/prestataireHome/registration'),
              backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
              textColor: Colors.white,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovedApplicationView(bool isDarkMode) {
    // Get screen width to make buttons responsive
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDarkMode ? Colors.grey.shade800 : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDarkMode 
                  ? Colors.green.shade900.withOpacity(0.3) 
                  : Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline,
                size: 60,
                color: Colors.green.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Compte prestataire actif',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Félicitations ! Votre compte prestataire est maintenant actif. Vous pouvez commencer à recevoir des demandes de service.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 24),
            // Use Wrap for responsive button layout
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                SizedBox(
                  width: isSmallScreen ? double.infinity : (screenWidth - 80) / 2,
                  child: CustomButton(
                    text: 'Voir mon profil',
                    onPressed: () => _viewProviderProfile(),
                    backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                    textColor: Colors.white,
                  ),
                ),
                SizedBox(
                  width: isSmallScreen ? double.infinity : (screenWidth - 80) / 2,
                  child: CustomButton(
                    text: 'Voir les demandes',
                    onPressed: () => context.push('/prestataireHome/reservations'),
                    backgroundColor: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
                    textColor: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                  SizedBox(
                  width: isSmallScreen ? double.infinity : (screenWidth - 80) / 2,
                  child: CustomButton(
                    text: 'Voir les réclamations',
                    onPressed: () => context.push('/prestataireHome/reclamation'),
                    backgroundColor: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
                    textColor: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: 'Messages',
                onPressed: () => context.go('/prestataireHome/chat'),
                backgroundColor: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
                textColor: isDarkMode ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _viewProviderProfile() {
    // Navigate to provider profile view
    context.push('/prestataireHome/profile');
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          'Espace Prestataire',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: isDarkMode ? Colors.grey.shade900 : Colors.white,
        foregroundColor: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        actions: [
          // Notifications icon with badge
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: () {
                    context.push('/prestataireHome/notifications');
                  },
                ),
                StreamBuilder<int>(
                  stream: ProviderNotificationsPage.getUnreadNotificationsCount(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data == 0) {
                      return const SizedBox.shrink();
                    }
                    
                    return Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${snapshot.data}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      drawer: const PrestataireSidebar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bienvenue dans votre espace prestataire',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Gérez vos services et suivez vos demandes',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 24),
            
            // Provider status section
            _buildProviderStatus(),
          ],
        ),
      ),
    );
  }
}