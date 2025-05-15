import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/reclamation_model.dart';

class ReclamationsManagementPage extends StatefulWidget {
  const ReclamationsManagementPage({super.key});

  @override
  State<ReclamationsManagementPage> createState() => _ReclamationsManagementPageState();
}

class _ReclamationsManagementPageState extends State<ReclamationsManagementPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
  
  Stream<QuerySnapshot> _getReclamationsStream(String? status) {
    final query = FirebaseFirestore.instance.collection('reclamations');
    
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
      appBar: AppBar(
        title: const Text('Gestion des Réclamations'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Toutes'),
            Tab(text: 'En attente'),
            Tab(text: 'Traitées'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher une réclamation...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade100,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          
          // Reclamations list
          Expanded(
            child: TabBarView(
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
          ),
        ],
      ),
    );
  }
  
  Widget _buildReclamationsList(String? status, bool isDarkMode) {
    return StreamBuilder<QuerySnapshot>(
      stream: _getReclamationsStream(status),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Text('Erreur: ${snapshot.error}'),
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
        // Filter reclamations based on search query
        final filteredReclamations = reclamations.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final title = data['title']?.toString().toLowerCase() ?? '';
          final description = data['description']?.toString().toLowerCase() ?? '';
          final id = data['id']?.toString().toLowerCase() ?? '';
          
          return title.contains(_searchQuery) || 
                 description.contains(_searchQuery) || 
                 id.contains(_searchQuery);
        }).toList();
        
        if (filteredReclamations.isEmpty) {
          return Center(
            child: Text(
              'Aucun résultat pour "$_searchQuery"',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: isDarkMode ? Colors.white70 : Colors.black54,
              ),
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: filteredReclamations.length,
          itemBuilder: (context, index) {
            final doc = filteredReclamations[index];
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
    
    // Status color
    Color statusColor;
    String statusText;
    
    switch (reclamation.status) {
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'En attente';
        break;
      case 'resolved':
        statusColor = Colors.green;
        statusText = 'Traitée';
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
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          context.push('/admin/reclamations/details/${reclamation.id}');
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
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      statusText,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                reclamation.description,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: isDarkMode ? Colors.white70 : Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Soumise le $formattedDate',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white60 : Colors.black54,
                    ),
                  ),
                  if (reclamation.imageUrls.isNotEmpty)
                    const Icon(
                      Icons.image,
                      size: 16,
                      color: Colors.grey,
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