import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../front/app_colors.dart';
import '../front/app_spacing.dart';
import '../front/app_typography.dart';
import '../front/custom_button.dart';
import '../front/custom_bottom_navbar_provider.dart';
import 'provider_reservations_page.dart';
import '../chat/provider_list_conversations.dart';
import '../chat/liste_conversations.dart';
import 'provider_profile_page.dart';
import 'custom_provider_app_bar.dart';
import 'dart:async';

class PrestataireHomePage extends StatefulWidget {
  const PrestataireHomePage({super.key});

  @override
  State<PrestataireHomePage> createState() => _PrestataireHomePageState();
}

class _PrestataireHomePageState extends State<PrestataireHomePage> {
  late Stream<DocumentSnapshot> _providerStatusStream;
  int _selectedIndex = 0;
  String _firstName = '';
  String? _currentUserId;
  bool _hasUnreadMessages = false; // New state for unread messages
  StreamSubscription<int>? _unreadMessagesSubscription; // Subscription for unread messages

  List<Map<String, dynamic>> _recentReservations = [];
  bool _isLoadingRecentReservations = true;

  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (_currentUserId != null) {
      _providerStatusStream = FirebaseFirestore.instance
          .collection('providers')
          .doc(_currentUserId)
          .snapshots();
      _fetchProviderDetails(); 
      _saveFCMToken();
      _providerStatusStream.listen((snapshot) {
        final data = snapshot.data() as Map<String, dynamic>?;
        final status = data?['status'] as String?;
        if (status == 'approved') {
          _fetchRecentReservations();
        }
      });
      // Listen to unread messages count
      _unreadMessagesSubscription = ChatListScreen.getTotalUnreadCount().listen((count) {
        if (mounted) {
          setState(() {
            _hasUnreadMessages = count > 0;
          });
        }
      });
    } else {
      _providerStatusStream = const Stream.empty();
    }
  }

  @override
  void dispose() {
    _unreadMessagesSubscription?.cancel(); // Cancel subscription
    super.dispose();
  }

  void _onItemSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _fetchProviderDetails() async {
    if (_currentUserId == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUserId).get();
      if (userDoc.exists && mounted) {
        setState(() {
          _firstName = userDoc.data()?['firstname'] ?? 'Prestataire';
        });
      }
    } catch (e) {
      debugPrint("Error fetching provider's first name: $e");
      if (mounted) setState(() => _firstName = 'Prestataire');
    }
  }

  Future<void> _fetchRecentReservations() async {
    if (_currentUserId == null) return;
    setState(() => _isLoadingRecentReservations = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('reservations')
          .where('providerId', isEqualTo: _currentUserId)
          .orderBy('createdAt', descending: true)
          .limit(3)
          .get();

      List<Map<String, dynamic>> reservations = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final userId = data['userId'] as String?;
        String clientName = 'Client Inconnu';
        String? clientAvatarUrl; // Added to fetch avatar
        if (userId != null) {
          final clientDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
          if (clientDoc.exists) {
            final clientData = clientDoc.data();
            clientName = '${clientData?['firstname'] ?? ''} ${clientData?['lastname'] ?? ''}'.trim();
            clientName = clientName.isEmpty ? 'Client Inconnu' : clientName;
            clientAvatarUrl = clientData?['avatarUrl'] as String?; // Fetch avatar URL
          }
        }
        reservations.add({
          ...data,
          'id': doc.id,
          'fetchedClientName': clientName,
          'fetchedClientAvatarUrl': clientAvatarUrl, // Add avatar URL to reservation map
        });
      }
      if (mounted) {
        setState(() {
          _recentReservations = reservations;
          _isLoadingRecentReservations = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching recent reservations: $e");
      if (mounted) setState(() => _isLoadingRecentReservations = false);
    }
  }

  Future<void> _saveFCMToken() async {
    try {
      if (_currentUserId == null) return;
      final messaging = FirebaseMessaging.instance;
      final token = await messaging.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(_currentUserId)
            .update({'fcmToken': token});
      }
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  Widget _buildGreetingCard(BuildContext context, bool isDarkMode) {
    final greeting = _firstName.isNotEmpty ? 'Bienvenue $_firstName !' : 'Bienvenue !';
    final prestatairePrimaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;
    final prestataireSecondaryColor = isDarkMode 
        ? AppColors.primaryGreen.withOpacity(0.7) 
        : AppColors.primaryDarkGreen.withOpacity(0.7);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      margin: const EdgeInsets.only(bottom: AppSpacing.lg, left: AppSpacing.md, right: AppSpacing.md, top: AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [prestatairePrimaryColor, prestataireSecondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: [ BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 4)) ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(greeting, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: AppSpacing.xs),
          Text('Gérez votre activité et services facilement.', style: GoogleFonts.poppins(fontSize: 15, color: Colors.white.withOpacity(0.9))),
        ],
      ),
    );
  }

  Widget _buildQuickAccessCard(BuildContext context, bool isDarkMode) {
    final cardColor = isDarkMode ? AppColors.darkCardBackground : Colors.white; // Consistent with profile page cards
    final iconColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;
    final textColor = isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      color: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Accès Rapide', style: AppTypography.h3(context).copyWith(color: textColor, fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickAccessButton(context, Icons.calendar_today_outlined, 'Réservations', () => _onItemSelected(1), iconColor, textColor),
                _buildQuickAccessButton(context, Icons.flag_outlined, 'Réclamations', () => context.push('/prestataireHome/reclamation'), iconColor, textColor),
                _buildQuickAccessButton(context, Icons.chat_bubble_outline, 'Messages', () => _onItemSelected(2), iconColor, textColor),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessButton(BuildContext context, IconData icon, String label, VoidCallback onPressed, Color iconColor, Color textColor) {
    return Expanded(
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: AppSpacing.iconLg + AppSpacing.xs, color: iconColor), // Slightly larger icon
              const SizedBox(height: AppSpacing.sm), // Increased spacing
              Text(label, style: AppTypography.labelMedium(context).copyWith(color: textColor, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildRecentReservationsSection(BuildContext context, bool isDarkMode) {
    final textColor = isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary;
    final primaryThemeColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Dernières Réservations', style: AppTypography.h3(context).copyWith(color: textColor, fontWeight: FontWeight.w600)),
              TextButton(
                onPressed: () => _onItemSelected(1),
                child: Text('Voir tout', style: TextStyle(color: primaryThemeColor, fontWeight: FontWeight.w500)),
              )
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (_isLoadingRecentReservations)
            const Center(child: CircularProgressIndicator())
          else if (_recentReservations.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text('Aucune réservation récente.', style: AppTypography.bodyMedium(context).copyWith(color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _recentReservations.length,
              itemBuilder: (context, index) {
                return _buildSmallReservationListItem(context, _recentReservations[index], isDarkMode);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSmallReservationListItem(BuildContext context, Map<String, dynamic> reservation, bool isDarkMode) {
    final serviceName = reservation['serviceName'] ?? 'Service Inconnu';
    final clientName = reservation['fetchedClientName'] ?? 'Client Inconnu';
    final clientAvatarUrl = reservation['fetchedClientAvatarUrl'] as String?;
    // final scheduledDate = reservation['scheduledDate'] as Timestamp?; // Old field
    final reservationTimestamp = reservation['reservationDateTime'] as Timestamp?; // Correct field from DB example
    final status = reservation['status'] ?? 'pending';
    final reservationId = reservation['id'] as String;
    final primaryThemeColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;

    String formattedDate = 'Date non spécifiée';
    if (reservationTimestamp != null) { // Use the correct timestamp variable
      formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(reservationTimestamp.toDate());
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: AppSpacing.md), // Increased bottom margin
      color: isDarkMode ? AppColors.darkCardBackground : Colors.white, // Consistent card color
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusLg)), // Consistent radius
      child: InkWell( // Make the whole card tappable
        onTap: () => context.push('/prestataireHome/reservation-details/$reservationId'),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                radius: AppSpacing.lg + AppSpacing.xs, // Consistent avatar size
                backgroundColor: primaryThemeColor.withOpacity(0.1),
                backgroundImage: clientAvatarUrl != null && clientAvatarUrl.isNotEmpty ? NetworkImage(clientAvatarUrl) : null,
                child: clientAvatarUrl == null || clientAvatarUrl.isEmpty 
                    ? Icon(Icons.person_outline, color: primaryThemeColor, size: AppSpacing.lg) 
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(serviceName, style: AppTypography.bodyLarge(context).copyWith(fontWeight: FontWeight.w600, color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                    const SizedBox(height: AppSpacing.xxs),
                    Text('Client: $clientName', style: AppTypography.bodySmall(context).copyWith(color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                    const SizedBox(height: AppSpacing.xxs),
                    Text('Date: $formattedDate', style: AppTypography.bodySmall(context).copyWith(color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _buildStatusBadge(context, status, isDarkMode, providerCompletionStatus: reservation['providerCompletionStatus']),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, String status, bool isDarkMode, {dynamic providerCompletionStatus}) {
    Color badgeColor;
    String statusText;
    bool isProviderMarkedCompleted = false;
    if (providerCompletionStatus is String) isProviderMarkedCompleted = providerCompletionStatus == 'completed';
    else if (providerCompletionStatus is bool) isProviderMarkedCompleted = providerCompletionStatus;

    if (status == 'waiting_confirmation' || (status == 'approved' && isProviderMarkedCompleted)) {
      badgeColor = Colors.purple; statusText = 'À confirmer';
    } else {
      switch (status) {
        case 'approved': badgeColor = Colors.green; statusText = 'Acceptée'; break;
        case 'cancelled': badgeColor = Colors.red; statusText = 'Annulée'; break;
        case 'rejected': badgeColor = Colors.red; statusText = 'Refusée'; break;
        case 'completed': badgeColor = Colors.blue; statusText = 'Terminée'; break;
        case 'pending': default: badgeColor = Colors.orange; statusText = 'En attente'; break;
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + AppSpacing.xxs, vertical: AppSpacing.xs + AppSpacing.xxs / 2),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Text(statusText, textAlign: TextAlign.center, style: AppTypography.labelSmall(context).copyWith(color: badgeColor, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildProviderStatusView(bool isDarkMode, String? status, String? rejectionReason, Map<String, dynamic>? providerData) {
    if (status == null && providerData == null) {
      return _buildNoApplicationView(isDarkMode);
    }
    switch (status) {
      case 'pending': return _buildPendingApplicationView(isDarkMode);
      case 'rejected': return _buildRejectedApplicationView(isDarkMode, rejectionReason, providerData);
      default: return _buildNoApplicationView(isDarkMode);
    }
  }

  Widget _buildNoApplicationView(bool isDarkMode) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDarkMode ? AppColors.darkCardBackground : Colors.white,
      margin: const EdgeInsets.all(AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_add_outlined, size: 64, color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen),
            const SizedBox(height: 24),
            Text('Devenez prestataire de services', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
            const SizedBox(height: 12),
            Text('Complétez votre profil prestataire pour commencer à offrir vos services sur notre plateforme.', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 16, color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
            const SizedBox(height: 24),
            CustomButton(text: 'Compléter mon profil prestataire', onPressed: () => context.go('/prestataireHome/registration'), backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen, textColor: Colors.white),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingApplicationView(bool isDarkMode) {
     return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDarkMode ? AppColors.darkCardBackground : Colors.white,
      margin: const EdgeInsets.all(AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: isDarkMode ? AppColors.warningOrange.withOpacity(0.3) : AppColors.warningOrange.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.hourglass_top_rounded, size: 60, color: AppColors.warningOrange)),
            const SizedBox(height: 24),
            Text('Demande en cours d\'examen', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
            const SizedBox(height: 12),
            Text('Votre demande est en cours d\'examen par notre équipe. Vous recevrez une notification dès qu\'une décision sera prise.', textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 16, color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
            const SizedBox(height: 16),
            LinearProgressIndicator(backgroundColor: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200, valueColor: AlwaysStoppedAnimation<Color>(isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)),
          ],
        ),
      ),
    );
  }

  Widget _buildRejectedApplicationView(bool isDarkMode, String? rejectionReason, Map<String, dynamic>? providerData) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: isDarkMode ? AppColors.darkCardBackground : Colors.white,
      margin: const EdgeInsets.all(AppSpacing.md),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: isDarkMode ? AppColors.errorRed.withOpacity(0.3) : AppColors.errorRed.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.error_outline_rounded, size: 60, color: AppColors.errorRed)),
            const SizedBox(height: 24),
            Text('Demande refusée', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
            const SizedBox(height: 12),
            if (rejectionReason != null && rejectionReason.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: isDarkMode ? AppColors.errorRed.withOpacity(0.2) : AppColors.errorRed.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: isDarkMode ? AppColors.errorDarkRed : AppColors.errorLightRed)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Motif du refus:', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16, color: isDarkMode ? AppColors.errorLightRed : AppColors.errorDarkRed)),
                    const SizedBox(height: 8),
                    Text(rejectionReason, style: GoogleFonts.poppins(fontSize: 14, color: isDarkMode ? AppColors.errorLightRed.withOpacity(0.8) : AppColors.errorDarkRed.withOpacity(0.8))),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            CustomButton(text: 'Soumettre une nouvelle demande', onPressed: () => context.go('/prestataireHome/registration', extra: providerData), backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen, textColor: Colors.white),
          ],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final scaffoldBackgroundColor = isDarkMode ? AppColors.darkBackground : AppColors.lightBackground;

    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      appBar: CustomProviderAppBar(
        selectedIndex: _selectedIndex,
        isDarkMode: isDarkMode,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _providerStatusStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen));
          }
          if (!snapshot.hasData || !snapshot.data!.exists && _currentUserId != null) {
            return SingleChildScrollView(child: _buildNoApplicationView(isDarkMode));
          }
          if (_currentUserId == null) { 
             return SingleChildScrollView(child: _buildNoApplicationView(isDarkMode));
          }

          final data = snapshot.data?.data() as Map<String, dynamic>?;
          final status = data?['status'] as String?;
          final rejectionReason = data?['rejectionReason'] as String?;

          if (status == 'approved') {
            return IndexedStack(
              index: _selectedIndex,
              children: [
                SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildGreetingCard(context, isDarkMode),
                      _buildQuickAccessCard(context, isDarkMode),
                      _buildRecentReservationsSection(context, isDarkMode),
                    ],
                  ),
                ),
                const ProviderReservationsPage(),
                const ProviderChatListScreen(),
                const ProviderProfilePage(),
              ],
            );
          } else {
            return SingleChildScrollView(
              child: _buildProviderStatusView(isDarkMode, status, rejectionReason, data),
            );
          }
        },
      ),
      bottomNavigationBar: StreamBuilder<DocumentSnapshot>(
        stream: _providerStatusStream,
        builder: (context, snapshot) {
          final data = snapshot.data?.data() as Map<String, dynamic>?;
          final status = data?['status'] as String?;
          if (status == 'approved') {
            return CustomBottomNavBarProvider(
              currentIndex: _selectedIndex,
              onItemSelected: _onItemSelected,
              isDarkMode: isDarkMode,
              hasUnreadMessages: _hasUnreadMessages, // Pass the flag here
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
