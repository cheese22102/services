import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/reclamation_model.dart';
import '../front/app_colors.dart'; // Import AppColors

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
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Détails de la réclamation',
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
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: primaryColor,
              ),
            )
          : _reclamation == null
              ? Center(
                  child: Text(
                    'Réclamation introuvable',
                    style: GoogleFonts.poppins(
                      color: Colors.red[700],
                      fontSize: 16,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Card for Reclamation Summary
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: isDarkMode ? AppColors.darkCardBackground : Colors.white,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSummaryInfoRow(
                                'Titre de la réclamation',
                                _reclamation!.title,
                                isDarkMode,
                                isTitle: true, // Special styling for title
                              ),
                              const SizedBox(height: 12),
                              _buildSummaryInfoRow(
                                'Date de soumission',
                                DateFormat('dd/MM/yyyy à HH:mm').format(_reclamation!.createdAt.toDate()),
                                isDarkMode,
                              ),
                              const SizedBox(height: 12),
                              _buildSummaryInfoRow(
                                'Statut',
                                _getReclamationStatusText(_reclamation!.status),
                                isDarkMode,
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Card for Parties involved
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: isDarkMode ? AppColors.darkCardBackground : Colors.white,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildPartiesSection(isDarkMode),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Card for Reservation details
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: isDarkMode ? AppColors.darkCardBackground : Colors.white,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: _buildReservationSection(isDarkMode),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Card for Description
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: isDarkMode ? AppColors.darkCardBackground : Colors.white,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
              Text(
                'Description',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _reclamation!.description,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
                      
      const SizedBox(height: 16),
                      
      // Card for Images
      if (_reclamation!.imageUrls.isNotEmpty) ...[
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          color: isDarkMode ? AppColors.darkCardBackground : Colors.white,
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Images',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _reclamation!.imageUrls.length,
                    itemBuilder: (context, index) {
                      final imageUrl = _reclamation!.imageUrls[index];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => _showFullScreenImage(context, imageUrl),
                          child: Container(
                            width: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
                              ),
                              image: DecorationImage(
                                image: NetworkImage(imageUrl),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
                      
      // Card for Admin response/actions
      Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: isDarkMode ? AppColors.darkCardBackground : Colors.white,
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Réponse de l\'administrateur',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              if (_reclamation!.status == 'pending') ...[
                TextField(
                  controller: _responseController,
                  maxLines: 5,
                  style: GoogleFonts.poppins(
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Entrez votre réponse ici...',
                    hintStyle: GoogleFonts.poppins(
                      color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
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
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _resolveReclamation('rejected'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Rejeter',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _resolveReclamation('resolved'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Résoudre',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
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
                    color: isDarkMode ? AppColors.darkInputBackground : AppColors.lightInputBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _reclamation!.status == 'resolved' ? primaryColor : Colors.red.shade600,
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
      ),
    ],
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
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        
        const SizedBox(height: 8),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? AppColors.darkCardBackground : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
            ),
          ),
          child: Column(
            children: [
              // Submitter
              _submitterData == null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Icon(Icons.person_off, color: Colors.red.shade400),
                          const SizedBox(width: 8),
                          Expanded( // Wrap Text in Expanded
                            child: Text(
                              'Informations du plaignant non disponibles',
                              style: GoogleFonts.poppins(
                                color: isDarkMode ? Colors.red.shade200 : Colors.red.shade700,
                                fontStyle: FontStyle.italic,
                              ),
                              overflow: TextOverflow.ellipsis, // Add overflow handling
                              maxLines: 2, // Allow two lines
                            ),
                          ),
                        ],
                      ),
                    )
                  : Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundImage: (_submitterData!['avatarUrl'] != null && _submitterData!['avatarUrl'].isNotEmpty)
                              ? NetworkImage(_submitterData!['avatarUrl'])
                              : null,
                          child: (_submitterData!['avatarUrl'] == null || _submitterData!['avatarUrl'].isEmpty)
                              ? Icon(
                                  Icons.person,
                                  color: isDarkMode ? Colors.white : Colors.blueGrey,
                                )
                              : null,
                          backgroundColor: (_submitterData!['avatarUrl'] == null || _submitterData!['avatarUrl'].isEmpty)
                              ? (isDarkMode ? Colors.blueGrey.shade700 : Colors.blueGrey.shade200)
                              : null,
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
                                '${_submitterData!['firstname'] ?? 'N/A'} ${_submitterData!['lastname'] ?? 'N/A'}',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis, // Add overflow handling
                                maxLines: 2, // Allow two lines
                              ),
                              if (_submitterData!['phone'] != null && _submitterData!['phone'].isNotEmpty)
                                Text(
                                  _submitterData!['phone'],
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                                  ),
                                  overflow: TextOverflow.ellipsis, // Add overflow handling
                                  maxLines: 2, // Allow two lines
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
              
              const SizedBox(height: 16),
              
              // Target
              _targetData == null
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Icon(Icons.person_off, color: Colors.red.shade400),
                          const SizedBox(width: 8),
                          Expanded( // Wrap Text in Expanded
                            child: Text(
                              'Informations du défendeur non disponibles',
                              style: GoogleFonts.poppins(
                                color: isDarkMode ? Colors.red.shade200 : Colors.red.shade700,
                                fontStyle: FontStyle.italic,
                              ),
                              overflow: TextOverflow.ellipsis, // Add overflow handling
                              maxLines: 2, // Allow two lines
                            ),
                          ),
                        ],
                      ),
                    )
                  : Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundImage: (_targetData!['avatarUrl'] != null && _targetData!['avatarUrl'].isNotEmpty)
                              ? NetworkImage(_targetData!['avatarUrl'])
                              : null,
                          child: (_targetData!['avatarUrl'] == null || _targetData!['avatarUrl'].isEmpty)
                              ? Icon(
                                  Icons.person,
                                  color: isDarkMode ? Colors.white : Colors.orange,
                                )
                              : null,
                          backgroundColor: (_targetData!['avatarUrl'] == null || _targetData!['avatarUrl'].isEmpty)
                              ? (isDarkMode ? Colors.orange.shade700 : Colors.orange.shade200)
                              : null,
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
                                '${_targetData!['firstname'] ?? 'N/A'} ${_targetData!['lastname'] ?? 'N/A'}',
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                                overflow: TextOverflow.ellipsis, // Add overflow handling
                                maxLines: 2, // Allow two lines
                              ),
                              if (_targetData!['phone'] != null && _targetData!['phone'].isNotEmpty)
                                Text(
                                  _targetData!['phone'],
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                                  ),
                                  overflow: TextOverflow.ellipsis, // Add overflow handling
                                  maxLines: 2, // Allow two lines
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
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        
        const SizedBox(height: 8),
        
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDarkMode ? AppColors.darkCardBackground : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildReservationInfoRow(
                'Service',
                _reservationData?['serviceName'] ?? 'Non spécifié',
                isDarkMode,
              ),
              
              const SizedBox(height: 12),
              
              _buildReservationInfoRow(
                'Date de réservation',
                _reservationData?['createdAt'] != null
                    ? DateFormat('dd/MM/yyyy à HH:mm').format((_reservationData!['createdAt'] as Timestamp).toDate())
                    : 'Non spécifiée',
                isDarkMode,
              ),
              
              const SizedBox(height: 12),
              
              _buildReservationInfoRow(
                'Statut de la réservation',
                _getReservationStatusText(_reservationData?['status']),
                isDarkMode,
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildReservationInfoRow(String label, String value, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black87,
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

  Widget _buildSummaryInfoRow(String label, String value, bool isDarkMode, {bool isTitle = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: isDarkMode ? Colors.white70 : Colors.black54,
          ),
        ),
        Text(
          value,
          style: isTitle
              ? GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black87,
                )
              : GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
          overflow: TextOverflow.ellipsis,
          maxLines: isTitle ? 2 : 1, // Allow title to wrap, others single line
        ),
      ],
    );
  }

  String _getReclamationStatusText(String? status) {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'resolved':
        return 'Résolue';
      case 'rejected':
        return 'Rejetée';
      default:
        return 'Inconnu';
    }
  }
}
