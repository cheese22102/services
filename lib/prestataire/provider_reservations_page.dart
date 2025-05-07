import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../front/app_colors.dart';
import '../front/custom_app_bar.dart';

class ProviderReservationsPage extends StatefulWidget {
  const ProviderReservationsPage({super.key});

  @override
  State<ProviderReservationsPage> createState() => _ProviderReservationsPageState();
}

class _ProviderReservationsPageState extends State<ProviderReservationsPage> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String? _currentUserId;
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _tabController = TabController(length: 4, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Stream<QuerySnapshot> _getReservationsStream(String? status) {
    final query = FirebaseFirestore.instance
        .collection('reservations')
        .where('providerId', isEqualTo: _currentUserId);
    
    if (status != null) {
      return query
          .where('status', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          // Add limit to prevent loading too many documents at once
          .limit(20)
          .snapshots();
    } else {
      return query
          .orderBy('createdAt', descending: true)
          // Add limit to prevent loading too many documents at once
          .limit(20)
          .snapshots();
    }
  }
  
  // Then add pagination controls in your UI
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Demandes de réservations',
        showBackButton: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
          labelColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
          unselectedLabelColor: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
          labelStyle: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'Toutes'),
            Tab(text: 'En attente'),
            Tab(text: 'Acceptées'),
            Tab(text: 'Terminées'),
          ],
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                // All reservations
                _buildReservationsList(null, isDarkMode),
                // Pending reservations
                _buildReservationsList('pending', isDarkMode),
                // Approved reservations
                _buildReservationsList('approved', isDarkMode),
                // Completed reservations
                _buildReservationsList('completed', isDarkMode),
              ],
            ),
    );
  }
  
  Widget _buildStatusBadge(String status, bool isDarkMode, {bool providerCompletionStatus = false}) {
    Color badgeColor;
    String statusText;
    
    if (status == 'approved' && providerCompletionStatus == true) {
      badgeColor = Colors.purple;
      statusText = 'En attente de\nconfirmation';
    } else {
      switch (status) {
        case 'approved':
          badgeColor = Colors.green;
          statusText = 'Acceptée';
          break;
        case 'rejected':
          badgeColor = Colors.red;
          statusText = 'Refusée';
          break;
        case 'completed':
          badgeColor = Colors.blue;
          statusText = 'Terminée';
          break;
        case 'pending':
        default:
          badgeColor = Colors.orange;
          statusText = 'En attente';
          break;
      }
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor, width: 1),
      ),
      child: Text(
        statusText,
        textAlign: TextAlign.center,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: badgeColor,
          height: 1.2,
        ),
      ),
    );
  }
  
  Widget _buildReservationsList(String? status, bool isDarkMode) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getReservationsStream(status),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
            ),
          );
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Erreur: ${snapshot.error}',
              style: GoogleFonts.poppins(
                color: isDarkMode ? Colors.white : Colors.black,
              ),
            ),
          );
        }
        
        final reservations = snapshot.data?.docs ?? [];
        
        if (reservations.isEmpty) {
          return _buildEmptyState(status, isDarkMode);
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reservations.length,
          itemBuilder: (context, index) {
            final reservation = reservations[index].data() as Map<String, dynamic>;
            final userId = reservation['userId'] as String;
            final reservationId = reservation['reservationId'] as String;
            final serviceName = reservation['serviceName'] as String? ?? 'Service non spécifié';
            final timestamp = reservation['createdAt'] as Timestamp?;
            final date = timestamp?.toDate() ?? DateTime.now();
            final formattedDate = '${date.day}/${date.month}/${date.year}';
            final reservationStatus = reservation['status'] as String? ?? 'pending';
            final providerCompletionStatus = reservation['providerCompletionStatus'] == 'completed';
            
            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return const Card(
                    margin: EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  );
                }
                
                final userData = userSnapshot.data?.data() as Map<String, dynamic>? ?? {};
                final userName = '${userData['firstname'] ?? ''} ${userData['lastname'] ?? ''}'.trim();
                final userPhone = userData['phone'] as String? ?? 'Non spécifié';
                final userPhoto = userData['photoURL'] as String? ?? '';
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  color: isDarkMode ? AppColors.darkInputBackground : Colors.white,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      context.push('/prestataireHome/reservation-details/$reservationId');
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // User photo
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                                    width: 2,
                                  ),
                                  image: userPhoto.isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(userPhoto),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: userPhoto.isEmpty
                                    ? Icon(
                                        Icons.person,
                                        size: 30,
                                        color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              
                              // User info
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName.isEmpty ? 'Utilisateur inconnu' : userName,
                                      style: GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: isDarkMode ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.phone,
                                          size: 16,
                                          color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          userPhone,
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              
                              // Status indicator
                              _buildStatusBadge(reservationStatus, isDarkMode, providerCompletionStatus: providerCompletionStatus),
                            ],
                          ),
                          const SizedBox(height: 16),
                          
                          // Service info
                          Row(
                            children: [
                              Icon(
                                Icons.handyman,
                                size: 16,
                                color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  serviceName,
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isDarkMode ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          
                          // Date
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                formattedDate,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
  
  Widget _buildEmptyState(String? status, bool isDarkMode) {
    String message;
    String description;
    IconData icon = Icons.calendar_today_outlined;
    
    switch (status) {
      case 'pending':
        message = 'Aucune demande en attente';
        description = 'Vous n\'avez pas de demandes d\'intervention en attente';
        icon = Icons.pending_actions;
        break;
      case 'approved':
        message = 'Aucune demande acceptée';
        description = 'Vous n\'avez pas encore accepté de demandes d\'intervention';
        icon = Icons.check_circle_outline;
        break;
      case 'completed':
        message = 'Aucune intervention terminée';
        description = 'Vous n\'avez pas encore d\'interventions terminées';
        icon = Icons.task_alt;
        break;
      default:
        message = 'Aucune demande';
        description = 'Vous n\'avez pas encore reçu de demandes d\'intervention';
        icon = Icons.calendar_today_outlined;
        break;
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              description,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}