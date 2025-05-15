import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/reclamation_model.dart';

class ReclamationDetailsPage extends StatefulWidget {
  final String reclamationId;
  
  const ReclamationDetailsPage({
    super.key,
    required this.reclamationId,
  });

  @override
  State<ReclamationDetailsPage> createState() => _ReclamationDetailsPageState();
}

class _ReclamationDetailsPageState extends State<ReclamationDetailsPage> {
  bool _isLoading = true;
  ReclamationModel? _reclamation;
  Map<String, dynamic>? _submitterData;
  Map<String, dynamic>? _targetData;
  Map<String, dynamic>? _reservationData;
  
  final _responseController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadReclamationData();
  }
  
  @override
  void dispose() {
    _responseController.dispose();
    super.dispose();
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
          _submitterData = submitterData;
          _targetData = targetData;
          _reservationData = reservationData;
          _isLoading = false;
          
          // Pre-fill response if there's an existing one
          if (reclamation.adminResponse != null) {
            _responseController.text = reclamation.adminResponse!;
          }
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
  
  Future<void> _resolveReclamation(String status) async {
    if (_reclamation == null) return;
    
    // Validate response for resolved status
    if (status == 'resolved' && _responseController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez fournir une réponse avant de résoudre la réclamation')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Update reclamation status
      await FirebaseFirestore.instance
          .collection('reclamations')
          .doc(widget.reclamationId)
          .update({
        'status': status,
        'adminResponse': _responseController.text.trim(),
        'resolvedAt': FieldValue.serverTimestamp(),
      });
      
      // Create notification for submitter
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_reclamation!.submitterId)
          .collection('notifications')
          .add({
        'title': status == 'resolved' ? 'Réclamation résolue' : 'Réclamation rejetée',
        'body': status == 'resolved' 
            ? 'Votre réclamation a été résolue. Consultez la réponse de l\'administrateur.' 
            : 'Votre réclamation a été rejetée. Consultez la réponse de l\'administrateur.',
        'type': 'reclamation_update',
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        'data': {
          'reclamationId': widget.reclamationId,
          'status': status,
        },
      });
      
      // Create notification for target
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_reclamation!.targetId)
          .collection('notifications')
          .add({
        'title': 'Réclamation traitée',
        'body': 'Une réclamation vous concernant a été traitée par l\'administrateur.',
        'type': 'reclamation_update',
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
        'data': {
          'reclamationId': widget.reclamationId,
          'status': status,
        },
      });
      
      // Update reclamation to mark that both parties have been notified
      await FirebaseFirestore.instance
          .collection('reclamations')
          .doc(widget.reclamationId)
          .update({
        'isNotified': true,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'resolved' 
                  ? 'Réclamation résolue avec succès' 
                  : 'Réclamation rejetée avec succès',
            ),
            backgroundColor: status == 'resolved' ? Colors.green : Colors.red,
          ),
        );
        context.pop();
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
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détails de la réclamation'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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
                      
                      // Parties involved
                      _buildPartiesSection(isDarkMode),
                      
                      const SizedBox(height: 24),
                      
                      // Reservation details
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
                      Text(
                        'Réponse de l\'administrateur',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      if (_reclamation!.status == 'pending') ...[
                        TextField(
                          controller: _responseController,
                          maxLines: 5,
                          decoration: InputDecoration(
                            hintText: 'Entrez votre réponse ici...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _resolveReclamation('rejected'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'Rejeter',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(width: 16),
                            
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _resolveReclamation('resolved'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'Résoudre',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _reclamation!.status == 'resolved' ? Colors.green : Colors.red,
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
  
  Widget _buildStatusBadge(bool isDarkMode) {
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
          color: statusColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
  
  Widget _buildPartiesSection(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Parties concernées',
          style: GoogleFonts.poppins(
            fontSize: 18,
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
          child: Column(
            children: [
              // Submitter
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.blue,
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Plaignant',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        
                        Text(
                          '${_submitterData?['firstname'] ?? ''} ${_submitterData?['lastname'] ?? ''}',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Target
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.orange,
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Défendeur',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: isDarkMode ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        
                        Text(
                          '${_targetData?['firstname'] ?? ''} ${_targetData?['lastname'] ?? ''}',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildReservationSection(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Détails de la réservation',
          style: GoogleFonts.poppins(
            fontSize: 18,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Service',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
              
              Text(
                _reservationData?['serviceName'] ?? 'Service non spécifié',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              
              const SizedBox(height: 12),
              
              Text(
                'Date de réservation',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
              
              Text(
                _reservationData?['createdAt'] != null
                    ? DateFormat('dd/MM/yyyy à HH:mm').format((_reservationData!['createdAt'] as Timestamp).toDate())
                    : 'Date non spécifiée',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
              
              const SizedBox(height: 12),
              
              Text(
                'Statut de la réservation',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: isDarkMode ? Colors.white70 : Colors.black54,
                ),
              ),
              
              Text(
                _getReservationStatusText(_reservationData?['status']),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  String _getReservationStatusText(String? status) {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'approved':
        return 'Acceptée';
      case 'rejected':
        return 'Refusée';
      case 'completed':
        return 'Terminée';
      case 'cancelled':
        return 'Annulée';
      default:
        return 'Statut inconnu';
    }
  }
}