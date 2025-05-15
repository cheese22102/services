import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../front/app_colors.dart';
import '../front/custom_app_bar.dart';
import '../front/custom_button.dart';
import '../models/reclamation_model.dart';
import '../utils/image_gallery_utils.dart';

class ProviderReclamationDetailsPage extends StatefulWidget {
  final String reclamationId;
  
  const ProviderReclamationDetailsPage({
    super.key,
    required this.reclamationId,
  });

  @override
  State<ProviderReclamationDetailsPage> createState() => _ProviderReclamationDetailsPageState();
}

class _ProviderReclamationDetailsPageState extends State<ProviderReclamationDetailsPage> {
  bool _isLoading = true;
  ReclamationModel? _reclamation;
  Map<String, dynamic>? _submitterData;
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
      
      // Get submitter data
      final submitterDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(reclamation.submitterId)
          .get();
      
      final submitterData = submitterDoc.data();
      
      // Get reservation data
      final reservationDoc = await FirebaseFirestore.instance
          .collection('reservations')
          .doc(reclamation.reservationId)
          .get();
      
      final reservationData = reservationDoc.data();
      
      if (mounted) {
        setState(() {
          _reclamation = reclamation;
          _submitterData = submitterData;
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
  
  Future<void> _updateReclamationStatus(String status) async {
    if (_reclamation == null) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Update reclamation status
      await FirebaseFirestore.instance
          .collection('reclamations')
          .doc(widget.reclamationId)
          .update({'status': status});
      
      // Create notification for submitter
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_reclamation!.submitterId)
          .collection('notifications')
          .add({
        'title': status == 'resolved' 
            ? 'Réclamation résolue' 
            : 'Réclamation rejetée',
        'body': status == 'resolved'
            ? 'Votre réclamation a été résolue'
            : 'Votre réclamation a été rejetée',
        'type': 'reclamation_update',
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        'data': {
          'reclamationId': widget.reclamationId,
          'status': status,
        },
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'resolved'
                  ? 'Réclamation marquée comme résolue'
                  : 'Réclamation rejetée',
            ),
            backgroundColor: status == 'resolved' ? Colors.green : Colors.red,
          ),
        );
        
        setState(() {
          _reclamation = _reclamation!.copyWith(status: status);
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
  
  Widget _buildSubmitterSection(bool isDarkMode) {
    if (_reclamation == null || _submitterData == null) return const SizedBox();
    
    final submitterName = '${_submitterData!['firstname'] ?? ''} ${_submitterData!['lastname'] ?? ''}'.trim();
    
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
            'Soumis par',
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
                backgroundImage: _submitterData!['photoURL'] != null
                    ? NetworkImage(_submitterData!['photoURL'])
                    : null,
                child: _submitterData!['photoURL'] == null
                    ? const Icon(Icons.person)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      submitterName,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    Text(
                      _submitterData!['email'] ?? '',
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
    
    final dateFormat = DateFormat('dd/MM/yyyy à HH:mm');
    final formattedDate = reservationDate != null ? dateFormat.format(reservationDate) : 'Date non spécifiée';
    
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
            'Détails de la réservation',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 20,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
              const SizedBox(width: 8),
              Text(
                formattedDate,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                Icons.home_repair_service,
                size: 20,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
              const SizedBox(width: 8),
              Text(
                serviceName,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          CustomButton(
            text: 'Voir les détails de la réservation',
            onPressed: () {
              context.push('/prestataireHome/reservation-details/${_reclamation!.reservationId}');
            },
            backgroundColor: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
            textColor: Colors.white,
          ),
        ],
      ),
    );
  }
  
  Widget _buildEvidenceSection(bool isDarkMode) {
    if (_reclamation == null || _reclamation!.imageUrls.isEmpty) {
      return const SizedBox();
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
            'Preuves',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _reclamation!.imageUrls.length,
              itemBuilder: (context, index) {
                final imageUrl = _reclamation!.imageUrls[index];
                return GestureDetector(
                  onTap: () {
                    // Open image in full screen
                    ImageGalleryUtils.openImageGallery(
                      context,
                      _reclamation!.imageUrls,
                      initialIndex: index,
                    );
                  },
                  child: Container(
                    width: 120,
                    height: 120,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: NetworkImage(imageUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              },
            ),
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with title and status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _reclamation?.title ?? 'Réclamation',
                          style: GoogleFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      _buildStatusBadge(isDarkMode),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Date
                  if (_reclamation != null)
                    Text(
                      'Soumise le ${DateFormat('dd/MM/yyyy à HH:mm').format(_reclamation!.createdAt.toDate())}',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Description
                  Text(
                    'Description',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _reclamation?.description ?? '',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Submitter info
                  _buildSubmitterSection(isDarkMode),
                  
                  const SizedBox(height: 24),
                  
                  // Reservation info
                  _buildReservationSection(isDarkMode),
                  
                  const SizedBox(height: 24),
                  
                  // Evidence images
                  _buildEvidenceSection(isDarkMode),
                  
                  const SizedBox(height: 32),
                  
                  // Action buttons
                  if (_reclamation?.status == 'pending')
                    Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: 'Rejeter',
                            onPressed: () => _updateReclamationStatus('rejected'),
                            backgroundColor: Colors.red,
                            textColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: CustomButton(
                            text: 'Résoudre',
                            onPressed: () => _updateReclamationStatus('resolved'),
                            backgroundColor: Colors.green,
                            textColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
    );
  }
}