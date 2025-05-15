import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../front/app_colors.dart';
import '../../front/custom_app_bar.dart';
import '../../models/reclamation_model.dart';

class ClientReclamationDetailsPage extends StatefulWidget {
  final String reclamationId;
  
  const ClientReclamationDetailsPage({
    super.key,
    required this.reclamationId,
  });

  @override
  State<ClientReclamationDetailsPage> createState() => _ClientReclamationDetailsPageState();
}

class _ClientReclamationDetailsPageState extends State<ClientReclamationDetailsPage> {
  bool _isLoading = true;
  ReclamationModel? _reclamation;
  Map<String, dynamic>? _targetData;
  Map<String, dynamic>? _reservationData;
  
  @override
  void initState() {
    super.initState();
    _loadReclamationData();
  }
  
  Future<void> _loadReclamationData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get reclamation data
      final reclamationDoc = await FirebaseFirestore.instance
          .collection('reclamations')
          .doc(widget.reclamationId)
          .get();
      
      if (!reclamationDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Réclamation introuvable')),
          );
          context.pop();
        }
        return;
      }
      
      final reclamationData = reclamationDoc.data()!;
      final reclamation = ReclamationModel.fromMap(reclamationData, widget.reclamationId);
      
      // Get target data
      final targetDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(reclamation.targetId)
          .get();
      
      final targetData = targetDoc.data();
      
      // Get reservation data
      final reservationDoc = await FirebaseFirestore.instance
          .collection('reservations')
          .doc(reclamation.reservationId)
          .get();
      
      final reservationData = reservationDoc.data();
      
      if (mounted) {
        setState(() {
          _reclamation = reclamation;
          _targetData = targetData;
          _reservationData = reservationData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Widget _buildStatusBadge(bool isDarkMode) {
    if (_reclamation == null) return const SizedBox();
    
    Color statusColor;
    String statusText;
    
    switch (_reclamation!.status) {
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
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor),
      ),
      child: Text(
        statusText,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: statusColor,
        ),
      ),
    );
  }
  
  Widget _buildTargetSection(bool isDarkMode) {
    if (_reclamation == null || _targetData == null) return const SizedBox();
    
    final targetName = '${_targetData!['firstname'] ?? ''} ${_targetData!['lastname'] ?? ''}'.trim();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Concernant',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: _targetData!['photoURL'] != null
                    ? NetworkImage(_targetData!['photoURL'])
                    : null,
                child: _targetData!['photoURL'] == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      targetName,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      _targetData!['email'] ?? '',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildReservationSection(bool isDarkMode) {
    if (_reclamation == null || _reservationData == null) return const SizedBox();
    
    final serviceName = _reservationData!['serviceName'] ?? 'Service non spécifié';
    final reservationDate = _reservationData!['reservationDate'] != null
        ? (_reservationData!['reservationDate'] as Timestamp).toDate()
        : null;
    
    String formattedDate = 'Date non spécifiée';
    if (reservationDate != null) {
      formattedDate = DateFormat('dd/MM/yyyy à HH:mm').format(reservationDate);
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Réservation',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.handyman, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serviceName,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      formattedDate,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Détails de la réclamation',
        showBackButton: true,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
              ),
            )
          : _reclamation == null
              ? const Center(child: Text('Réclamation introuvable'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status badge
                      _buildStatusBadge(isDarkMode),
                      
                      const SizedBox(height: 16),
                      
                      // Reclamation title
                      Text(
                        _reclamation!.title,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // Date
                      Text(
                        'Soumise le ${DateFormat('dd/MM/yyyy à HH:mm').format(_reclamation!.createdAt.toDate())}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: isDarkMode ? Colors.white70 : Colors.black54,
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Target section
                      _buildTargetSection(isDarkMode),
                      
                      const SizedBox(height: 24),
                      
                      // Reservation section
                      _buildReservationSection(isDarkMode),
                      
                      const SizedBox(height: 24),
                      
                      // Description
                      Text(
                        'Description',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      Container(
                        padding: const EdgeInsets.all(16),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _reclamation!.description,
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Images
                      if (_reclamation!.imageUrls.isNotEmpty) ...[
                        Text(
                          'Images',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        SizedBox(
                          height: 200,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _reclamation!.imageUrls.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: GestureDetector(
                                  onTap: () {
                                    // Show full screen image
                                    showDialog(
                                      context: context,
                                      builder: (context) => Dialog(
                                        child: Image.network(
                                          _reclamation!.imageUrls[index],
                                          fit: BoxFit.contain,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    width: 200,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      image: DecorationImage(
                                        image: NetworkImage(_reclamation!.imageUrls[index]),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                      ],
                      
                      // Admin response
                      if (_reclamation!.status == 'resolved' || _reclamation!.status == 'rejected') ...[
                        Text(
                          'Réponse de l\'administrateur',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        
                        const SizedBox(height: 8),
                        
                        Container(
                          padding: const EdgeInsets.all(16),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _reclamation!.status == 'resolved' ? Colors.green : Colors.red,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _reclamation!.adminResponse ?? 'Aucune réponse fournie',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: isDarkMode ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}