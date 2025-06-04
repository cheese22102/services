import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts
import '../front/app_colors.dart'; // Import AppColors

class ProviderListPage extends StatefulWidget {
  const ProviderListPage({super.key});

  @override
  State<ProviderListPage> createState() => _ProviderListPageState();
}

class _ProviderListPageState extends State<ProviderListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Validation des Prestataires',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        backgroundColor: isDarkMode ? AppColors.darkBackground : Colors.white,
        elevation: 4, // Consistent elevation
        iconTheme: IconThemeData(
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/admin'),
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0), // Consistent padding
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: 'Rechercher par email ou téléphone...',
                hintStyle: TextStyle(
                  color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade400,
                ),
                prefixIcon: Icon(Icons.search, color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700),
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
                    color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                    width: 2,
                  ),
                ),
                filled: true,
                fillColor: isDarkMode ? AppColors.darkInputBackground : AppColors.lightInputBackground,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          // List of requests
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('providers')
                  .where('status', isEqualTo: 'pending')  // Only show pending requests
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Une erreur est survenue',
                      style: GoogleFonts.poppins(
                        color: Colors.red[700],
                        fontSize: 16,
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.data == null || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'Aucune demande en attente',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  );
                }

                final requests = snapshot.data!.docs;
                
                // Filter by search query if needed
                final filteredRequests = _searchQuery.isEmpty
                    ? requests
                    : requests.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return data['professionalEmail'].toString().toLowerCase().contains(_searchQuery) ||
                               data['professionalPhone'].toString().toLowerCase().contains(_searchQuery);
                      }).toList();

                return ListView.builder(
                  itemCount: filteredRequests.length,
                  itemBuilder: (context, index) {
                    final requestData = filteredRequests[index].data() as Map<String, dynamic>;
                    final requestId = filteredRequests[index].id;
                    final userId = requestData['userId'] as String?;

                    if (userId == null) {
                      return const SizedBox.shrink(); // Skip if userId is missing
                    }

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
                      builder: (context, userSnapshot) {
                        if (userSnapshot.connectionState == ConnectionState.waiting) {
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            color: isDarkMode ? AppColors.darkCardBackground : Colors.white,
                            child: const ListTile(
                              leading: CircularProgressIndicator(),
                              title: Text('Chargement du prestataire...'),
                            ),
                          );
                        }

                        if (userSnapshot.hasError) {
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            color: isDarkMode ? AppColors.darkCardBackground : Colors.white,
                            child: ListTile(
                              title: Text('Erreur de chargement: ${userSnapshot.error}'),
                            ),
                          );
                        }

                        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                        final firstName = userData?['firstname'] ?? 'Inconnu';
                        final lastName = userData?['lastname'] ?? 'Inconnu';
                        final fullName = '$firstName $lastName';
                        final profilePictureUrl = userData?['profilePictureUrl'] as String?;
                        String city = requestData['exactLocation']?['address'] as String? ?? 'Non spécifié';
                        // Extract the city name (assuming it's the second part if multiple commas exist, otherwise the whole string)
                        final addressParts = city.split(',');
                        if (addressParts.length > 1) {
                          city = addressParts[1].trim(); // Take the second part
                        } else {
                          city = addressParts.first.trim(); // If only one part, use it as the city
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Consistent margin
                          elevation: 2, // Keep 2 for list items
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          color: isDarkMode ? AppColors.darkCardBackground : Colors.white, // Consistent card background
                          child: ListTile(
                            leading: CircleAvatar(
                              radius: 24,
                              backgroundColor: isDarkMode ? AppColors.primaryGreen.withOpacity(0.2) : AppColors.primaryDarkGreen.withOpacity(0.2),
                              backgroundImage: profilePictureUrl != null && profilePictureUrl.isNotEmpty
                                  ? NetworkImage(profilePictureUrl)
                                  : null,
                              child: profilePictureUrl == null || profilePictureUrl.isEmpty
                                  ? Icon(
                                      Icons.person,
                                      color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                                      size: 28,
                                    )
                                  : null,
                            ),
                            title: Text(
                              fullName,
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w500,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                            ),
                            subtitle: Text(
                              'Ville: $city',
                              style: GoogleFonts.poppins(
                                color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                              ),
                            ),
                            trailing: Icon(Icons.arrow_forward_ios, color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700),
                            onTap: () {
                              context.push('/admin/providers/$requestId');
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
