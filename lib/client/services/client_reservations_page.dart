import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../front/app_colors.dart';
import '../../front/custom_app_bar.dart';

class ClientReservationsPage extends StatefulWidget {
  const ClientReservationsPage({super.key});

  @override
  State<ClientReservationsPage> createState() => _ClientReservationsPageState();
}

class _ClientReservationsPageState extends State<ClientReservationsPage> with SingleTickerProviderStateMixin {
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
        .where('userId', isEqualTo: _currentUserId);
    
    if (status != null) {
      return query
          .where('status', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots();
    } else {
      return query
          .orderBy('createdAt', descending: true)
          .limit(20)
          .snapshots();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Mes réservations',
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
            Tab(text: 'Annulées'),
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
  
  Widget _buildStatusBadge(String status, bool isDarkMode, {dynamic providerCompletionStatus = false}) {
    Color badgeColor;
    String statusText;
    
    // Fix the type error by ensuring providerCompletionStatus is treated as a boolean
    bool isProviderCompleted = false;
    if (providerCompletionStatus is bool) {
      isProviderCompleted = providerCompletionStatus;
    } else if (providerCompletionStatus is String) {
      isProviderCompleted = providerCompletionStatus == 'true';
    }
    
    if (status == 'approved' && isProviderCompleted) {
      badgeColor = Colors.purple;
      statusText = 'À confirmer';
    } else {
      switch (status) {
        case 'approved':
          badgeColor = Colors.green;
          statusText = 'Acceptée';
          break;
        case 'cancelled':
          badgeColor = Colors.red;
          statusText = 'Annulée';
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
              'Erreur de chargement',
              style: GoogleFonts.poppins(
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
          );
        }

        final reservations = snapshot.data?.docs ?? [];

        if (reservations.isEmpty) {
          return Center(
            child: Text(
              'Aucune réservation trouvée',
              style: GoogleFonts.poppins(
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reservations.length,
          itemBuilder: (context, index) {
            final reservation = reservations[index].data() as Map<String, dynamic>;
            final reservationId = reservations[index].id;
            final providerPhotoURL = reservation['providerPhotoURL'] as String?;
            
            // Add GestureDetector to make the entire card clickable
            return GestureDetector(
              onTap: () {
                // Navigate to reservation details page
                context.go('/clientHome/reservation-details/$reservationId');
              },
              child: Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: isDarkMode ? Colors.grey.shade800 : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              reservation['serviceName'] ?? 'Service',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildStatusBadge(
                            reservation['status'] ?? 'pending',
                            isDarkMode,
                            providerCompletionStatus: reservation['providerCompletionStatus'],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Provider info with image
                      Row(
                        children: [
                          // Provider image
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200,
                              image: providerPhotoURL != null
                                  ? DecorationImage(
                                      image: NetworkImage(providerPhotoURL),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: providerPhotoURL == null
                                ? Icon(
                                    Icons.person,
                                    color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
                                    size: 30,
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          // Provider name and service date
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Prestataire: ${reservation['providerName'] ?? 'Non spécifié'}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isDarkMode ? Colors.white : Colors.black87,
                                  ),
                                ),
                                if (reservation['scheduledDate'] != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Date: ${_formatDate(reservation['scheduledDate'])}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      color: isDarkMode ? Colors.white70 : Colors.black54,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              // Navigate to reservation details page
                              context.go('/clientHome/reservation-details/$reservationId');
                            },
                            child: Text(
                              'Voir plus',
                              style: GoogleFonts.poppins(
                                color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                                fontWeight: FontWeight.w500,
                              ),
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
  }
  
  // Helper method to format dates
  String _formatDate(dynamic date) {
    if (date == null) return 'Non spécifiée';
    
    try {
      if (date is Timestamp) {
        final dateTime = date.toDate();
        return DateFormat('dd/MM/yyyy à HH:mm').format(dateTime);
      } else if (date is String) {
        final dateTime = DateTime.parse(date);
        return DateFormat('dd/MM/yyyy à HH:mm').format(dateTime);
      }
    } catch (e) {
      // Handle parsing errors
    }
    
    return 'Non spécifiée';
  }
  
}
