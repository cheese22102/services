import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Import Firebase Auth
import '../front/app_colors.dart'; // Import AppColors

class AccountsManagementPage extends StatefulWidget {
  const AccountsManagementPage({super.key});

  @override
  State<AccountsManagementPage> createState() => _AccountsManagementPageState();
}

class _AccountsManagementPageState extends State<AccountsManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _currentAdminId; // To store the current admin's user ID

  @override
  void initState() {
    super.initState();
    _getCurrentAdminId();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentAdminId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      setState(() {
        _currentAdminId = user.uid;
      });
    }
  }

  Future<void> _deleteUser(String userId, String userEmail) async {
    showDialog(
      context: context,
      builder: (context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDarkMode ? AppColors.darkCardBackground : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Confirmer la suppression',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
          content: Text(
            'Voulez-vous vraiment supprimer le compte de $userEmail ? Cette action est irréversible.',
            style: GoogleFonts.poppins(
              color: isDarkMode ? Colors.white70 : Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Annuler',
                style: GoogleFonts.poppins(
                  color: isDarkMode ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                try {
                  // Delete user document from 'users' collection
                  await FirebaseFirestore.instance.collection('users').doc(userId).delete();
                  
                  // Optionally, delete related data (e.g., posts, reservations, etc.)
                  // This would require more complex logic and careful consideration of data dependencies.
                  // For now, only the user document is deleted.

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Compte de $userEmail supprimé avec succès')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur lors de la suppression du compte: $e')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Supprimer',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Gestion des Comptes',
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                color: isDarkMode ? Colors.white : Colors.black87,
              ),
              decoration: InputDecoration(
                hintText: 'Rechercher par nom, prénom ou email...',
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
                    color: primaryColor,
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
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Erreur: ${snapshot.error}',
                      style: GoogleFonts.poppins(
                        color: Colors.red[700],
                        fontSize: 16,
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: primaryColor,
                    ),
                  );
                }

                final users = snapshot.data?.docs ?? [];

                // Filter out the current admin's account and apply search query
                final filteredUsers = users.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final userId = doc.id;
                  final firstName = data['firstname']?.toString().toLowerCase() ?? '';
                  final lastName = data['lastname']?.toString().toLowerCase() ?? '';
                  final email = data['email']?.toString().toLowerCase() ?? '';
                  
                  // Exclude the current admin's account
                  if (_currentAdminId != null && userId == _currentAdminId) {
                    return false;
                  }

                  // Apply search filter
                  return firstName.contains(_searchQuery) ||
                         lastName.contains(_searchQuery) ||
                         email.contains(_searchQuery);
                }).toList();

                if (filteredUsers.isEmpty) {
                  return Center(
                    child: Text(
                      _searchQuery.isEmpty
                          ? 'Aucun compte utilisateur trouvé.'
                          : 'Aucun résultat pour "$_searchQuery"',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: isDarkMode ? Colors.white70 : Colors.black54,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final userDoc = filteredUsers[index];
                    final userData = userDoc.data() as Map<String, dynamic>;
                    final userId = userDoc.id;

                    final firstName = userData['firstname'] ?? 'N/A';
                    final lastName = userData['lastname'] ?? 'N/A';
                    final email = userData['email'] ?? 'N/A';
                    final avatarUrl = userData['avatarUrl'] as String?;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: isDarkMode ? AppColors.darkCardBackground : Colors.white,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                              ? NetworkImage(avatarUrl)
                              : null,
                          child: avatarUrl == null || avatarUrl.isEmpty
                              ? Icon(Icons.person, color: isDarkMode ? Colors.white : Colors.blueGrey)
                              : null,
                          backgroundColor: avatarUrl == null || avatarUrl.isEmpty
                              ? (isDarkMode ? Colors.blueGrey.shade700 : Colors.blueGrey.shade200)
                              : null,
                        ),
                        title: Text(
                          '$firstName $lastName',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                            color: isDarkMode ? Colors.white : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          email,
                          style: GoogleFonts.poppins(
                            color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade700,
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.delete, color: Colors.red.shade400),
                          onPressed: () => _deleteUser(userId, email),
                          tooltip: 'Supprimer le compte',
                        ),
                        onTap: () {
                          // Optionally, navigate to a user details page if needed
                          // context.push('/admin/users/$userId');
                        },
                      ),
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
