import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../front/app_colors.dart';
import '../front/custom_app_bar.dart';
import '../models/reclamation_model.dart';

class ProviderReclamationsPage extends StatefulWidget {
  const ProviderReclamationsPage({super.key});

  @override
  State<ProviderReclamationsPage> createState() => _ProviderReclamationsPageState();
}

class _ProviderReclamationsPageState extends State<ProviderReclamationsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final bool _isLoading = false;
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Stream<QuerySnapshot> _getReclamationsStream(String? status) {
    if (currentUserId == null) {
      return const Stream.empty();
    }
    
    final query = FirebaseFirestore.instance
        .collection('reclamations')
        .where('targetId', isEqualTo: currentUserId);
    
    if (status != null) {
      return query
          .where('status', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .snapshots();
    } else {
      return query
          .orderBy('createdAt', descending: true)
          .snapshots();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Réclamations',
        showBackButton: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
          labelColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
          unselectedLabelColor: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
          tabs: const [
            Tab(text: 'Toutes'),
            Tab(text: 'En attente'),
            Tab(text: 'Traitées'),
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
                // All reclamations
                _buildReclamationsList(null, isDarkMode),
                // Pending reclamations
                _buildReclamationsList('pending', isDarkMode),
                // Resolved reclamations
                _buildReclamationsList('resolved', isDarkMode),
              ],
            ),
    );
  }
  
  Widget _buildReclamationsList(String? status, bool isDarkMode) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getReclamationsStream(status),
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
                color: isDarkMode ? Colors.white70 : Colors.black87,
              ),
            ),
          );
        }
        
        final reclamations = snapshot.data?.docs ?? [];
        
        if (reclamations.isEmpty) {
          return Center(
            child: Text(
              'Aucune réclamation ${status == 'pending' ? 'en attente' : status == 'resolved' ? 'traitée' : ''}',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: reclamations.length,
          itemBuilder: (context, index) {
            final doc = reclamations[index];
            final data = doc.data() as Map<String, dynamic>;
            final reclamation = ReclamationModel.fromMap(data, doc.id);
            
            return _buildReclamationCard(reclamation, isDarkMode);
          },
        );
      },
    );
  }
  
  Widget _buildReclamationCard(ReclamationModel reclamation, bool isDarkMode) {
    // Format the date
    final dateFormat = DateFormat('dd/MM/yyyy à HH:mm');
    final createdAtDate = reclamation.createdAt.toDate();
    final formattedDate = dateFormat.format(createdAtDate);
    
    // Status color and text
    Color statusColor;
    String statusText;
    
    switch (reclamation.status) {
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'En attente';
        break;
      case 'resolved':
        statusColor = Colors.green;
        statusText = 'Résolue';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'Rejetée';
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'Inconnu';
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          context.push('/prestataireHome/reclamation/details/${reclamation.id}');
        },
        borderRadius: BorderRadius.circular(12),
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
                      reclamation.title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      statusText,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Soumise le $formattedDate',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                reclamation.description.length > 100
                    ? '${reclamation.description.substring(0, 100)}...'
                    : reclamation.description,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              if (reclamation.imageUrls.isNotEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.image,
                      size: 16,
                      color: isDarkMode ? Colors.white70 : Colors.black54,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${reclamation.imageUrls.length} image${reclamation.imageUrls.length > 1 ? 's' : ''}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}