import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'theme_toggle_switch.dart'; // Updated import
import '../client/page_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class Sidebar extends StatefulWidget {
  const Sidebar({super.key});

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  bool _isMarketplaceExpanded = false;
  bool _isServicesExpanded = false; // Add this for services section

  final Future<DocumentSnapshot> _userDataFuture = FirebaseFirestore.instance
      .collection('users')
      .doc(FirebaseAuth.instance.currentUser!.uid)
      .get();

  Future<void> _logout() async {
    try {
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      await FirebaseAuth.instance.signOut();
      await GoogleSignIn().signOut();
      if (!mounted) return;
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Erreur lors de la déconnexion")),
      );
    }
  }

  void _navigateToProfile() {
    Navigator.pop(context);
    context.go('/clientHome/profile');
  }

  void _navigateToNotifications() {
    Navigator.pop(context);
    context.go('/clientHome/notifications');
  }

  Widget _buildMarketplaceItem(String title, IconData icon, VoidCallback onTap) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return ListTile(
      leading: Icon(
        icon,
        size: 20,
        color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
      contentPadding: const EdgeInsets.only(left: 32.0),
      onTap: onTap,
      dense: true,
    );
  }

  Widget _buildMarketplaceSection() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;
    
    return Column(
      children: [
        ListTile(
          leading: Icon(
            Icons.shopping_bag_outlined,
            color: primaryColor,
            size: 22,
          ),
          title: Text(
            'Marketplace',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
          ),
          trailing: AnimatedRotation(
            duration: const Duration(milliseconds: 300),
            turns: _isMarketplaceExpanded ? 0.5 : 0,
            child: Icon(
              Icons.arrow_drop_down,
              color: primaryColor,
            ),
          ),
          onTap: () {
            setState(() {
              _isMarketplaceExpanded = !_isMarketplaceExpanded;
            });
          },
        ),
        // Replaced AnimatedCrossFade with a more smooth animation approach
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: _isMarketplaceExpanded ? 200 : 0, // Adjust height based on content
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              children: [
                _buildMarketplaceItem(
                  'Accueil',
                  Icons.storefront_outlined,
                  () {
                    Navigator.pop(context);
                    context.go('/clientHome/marketplace');
                  },
                ),
                _buildMarketplaceItem(
                  'Ajouter une publication',
                  Icons.add_box_outlined,
                  () {
                    Navigator.pop(context);
                    context.go('/clientHome/marketplace/add');
                  },
                ),
                _buildMarketplaceItem(
                  'Mes favoris',
                  Icons.favorite_border_rounded,
                  () {
                    Navigator.pop(context);
                    context.go('/clientHome/marketplace/favorites');
                  },
                ),
                _buildMarketplaceItem(
                  'Mes publications',
                  Icons.grid_view_outlined,
                  () {
                    Navigator.pop(context);
                    context.go('/clientHome/marketplace/my-products');
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServicesItem(String title, IconData icon, VoidCallback onTap) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return ListTile(
      leading: Icon(
        icon,
        size: 20,
        color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
      ),
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDarkMode ? Colors.white : Colors.black87,
        ),
      ),
      contentPadding: const EdgeInsets.only(left: 32.0),
      onTap: onTap,
      dense: true,
    );
  }

  Widget _buildServicesSection() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;
    
    return Column(
      children: [
        ListTile(
          leading: Icon(
            Icons.home_repair_service,
            color: primaryColor,
            size: 22,
          ),
          title: Text(
            'Services',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: primaryColor,
            ),
          ),
          trailing: AnimatedRotation(
            duration: const Duration(milliseconds: 300),
            turns: _isServicesExpanded ? 0.5 : 0,
            child: Icon(
              Icons.arrow_drop_down,
              color: primaryColor,
            ),
          ),
          onTap: () {
            setState(() {
              _isServicesExpanded = !_isServicesExpanded;
            });
          },
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: _isServicesExpanded ? 200 : 0, // Adjust height based on content (increased from 150 to 200 to accommodate new button)
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            child: Column(
              children: [
                _buildServicesItem(
                  'Tous les services',
                  Icons.category_outlined,
                  () {
                    Navigator.pop(context);
                    context.go('/clientHome/all-services');
                  },
                ),
                _buildServicesItem(
                  'Mes réservations',
                  Icons.calendar_today_outlined,
                  () {
                    Navigator.pop(context);
                    context.go('/clientHome/my-reservations');
                  },
                ),
                _buildServicesItem(
                  'Prestataires favoris',
                  Icons.favorite_border_outlined,
                  () {
                    Navigator.pop(context);
                    context.go('/clientHome/favorite-providers');
                  },
                ),
                _buildServicesItem(
                  'Mes réclamations',
                  Icons.report_problem_outlined,
                  () {
                    Navigator.pop(context);
                    context.go('/clientHome/reclamations');
                  },
                ),
                // Add your new button here, for example:
                _buildServicesItem(
                  'Nouvelle réclamation',
                  Icons.add_circle_outline,
                  () {
                    Navigator.pop(context);
                    context.go('/clientHome/new-reclamation');
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;
    
    return Drawer(
      backgroundColor: isDarkMode ? Colors.grey.shade900 : Colors.white,
      elevation: 2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          FutureBuilder<DocumentSnapshot>(
            future: _userDataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return SizedBox(
                  // Increased height from 180 to 220
                  height: 220,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: primaryColor,
                    ),
                  ),
                );
              }
              final data = snapshot.data?.data() as Map<String, dynamic>?;
              return _UserHeader(data: data);
            },
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  ListTile(
                    leading: Icon(
                      Icons.person_outline_rounded,
                      color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                      size: 22,
                    ),
                    title: Text(
                      "Modifier le profil",
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    onTap: _navigateToProfile,
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.notifications_outlined,
                      color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                      size: 22,
                    ),
                    title: Text(
                      "Notifications",
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    trailing: StreamBuilder<int>(
                      stream: NotificationsPage.getUnreadNotificationsCount(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData && snapshot.data! > 0) {
                          return Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            child: Text(
                              '${snapshot.data}',
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    onTap: _navigateToNotifications,
                  ),
                  
                  // Add Services section before Marketplace
                  _buildServicesSection(),
                  
                  const Divider(),
                  
                  // Existing Marketplace section
                  _buildMarketplaceSection(),
                  Divider(
                    thickness: 1.2,
                    color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                    indent: 16,
                    endIndent: 16,
                  ),
                  // Removed logout button from here
                ],
              ),
            ),
          ),
          // Replaced theme switch with logout button
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: ListTile(
              leading: Icon(
                Icons.logout_rounded,
                color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                size: 22,
              ),
              title: Text(
                "Se déconnecter",
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
              onTap: _logout,
              dense: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserHeader extends StatelessWidget {
  final Map<String, dynamic>? data;

  const _UserHeader({required this.data});

  @override
  Widget build(BuildContext context) {
    final firstName = data?['firstname'] ?? "Prénom inconnu";
    final lastName = data?['lastname'] ?? "Nom inconnu";
    final avatarUrl = data?['avatarUrl'];
    final fullName = "$firstName $lastName";
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.15),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            primaryColor.withOpacity(0.2),
            primaryColor.withOpacity(0.1),
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Add theme toggle at the top right
          Align(
            alignment: Alignment.topRight,
            child: ThemeToggleSwitch(),
          ),
          const SizedBox(height: 8),
          // Make avatar bigger and centered
          CircleAvatar(
            radius: 50, // Increased from 40
            backgroundColor: primaryColor.withOpacity(0.2),
            child: avatarUrl != null && avatarUrl.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      avatarUrl,
                      width: 100, // Increased from 80
                      height: 100, // Increased from 80
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.person,
                        size: 50, // Increased from 40
                        color: primaryColor,
                      ),
                    ),
                  )
                : Icon(
                    Icons.person,
                    size: 50, // Increased from 40
                    color: primaryColor,
                  ),
          ),
          const SizedBox(height: 16),
          // Center the name and make it slightly larger
          Text(
            fullName,
            style: GoogleFonts.poppins(
              fontSize: 22, // Increased from 20
              fontWeight: FontWeight.bold,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          // Removed email and role badge
        ],
      ),
    );
  }
}
