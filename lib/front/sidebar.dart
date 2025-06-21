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
            Icons.store_outlined, // Changed section icon
            color: primaryColor,
            size: 22,
          ),
          title: Text(
            'Marketplace', // Text remains 'Marketplace'
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
                  "Parcourir le Marché", // Changed text
                  Icons.grid_view_rounded, // Changed icon
                  () {
                    Navigator.pop(context);
                    context.go('/clientHome/marketplace');
                  },
                ),
                _buildMarketplaceItem(
                  "Vendre un Article", // Changed text
                  Icons.add_business_outlined, // Changed icon
                  () {
                    Navigator.pop(context);
                    context.go('/clientHome/marketplace/add');
                  },
                ),
                _buildMarketplaceItem(
                  "Articles Préférés", // Changed text
                  Icons.bookmark_border_outlined, // Changed icon
                  () {
                    Navigator.pop(context);
                    context.go('/clientHome/marketplace/favorites');
                  },
                ),
                _buildMarketplaceItem(
                  "Mes Articles en Vente", // Changed text
                  Icons.inventory_2_outlined, // Changed icon
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
            Icons.build_outlined, // Changed section icon
            color: primaryColor,
            size: 22,
          ),
          title: Text(
            'Services', // Text remains 'Services'
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
                  "Explorer les Services", // Changed text
                  Icons.explore_outlined, // Changed icon
                  () {
                    Navigator.pop(context);
                    context.go('/clientHome/all-services');
                  },
                ),
                _buildServicesItem(
                  "Mes Rendez-vous", // Changed text
                  Icons.event_note_outlined, // Changed icon
                  () {
                    Navigator.pop(context);
                    context.go('/clientHome/my-reservations');
                  },
                ),
                _buildServicesItem(
                  "Prestataires Favoris", // Changed text
                  Icons.favorite_border_outlined, // Kept icon
                  () {
                    Navigator.pop(context);
                    context.go('/clientHome/favorite-providers');
                  },
                ),
                _buildServicesItem(
                  "Mes Tickets de Support", // Changed text
                  Icons.support_agent_outlined, // Changed icon
                  () {
                    Navigator.pop(context);
                    context.go('/clientHome/reclamations');
                  },
                ),
                _buildServicesItem(
                  "Ouvrir un Ticket", // Changed text
                  Icons.add_comment_outlined, // Changed icon
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
                    leading: Icon( // Icon for Profile
                      Icons.account_circle_outlined, // Changed icon
                      color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                      size: 22,
                    ),
                    title: Text(
                      "Mon Profil", // Changed text
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    onTap: _navigateToProfile,
                  ),
                  // New ListTile for Change Password
                  ListTile(
                    leading: Icon(
                      Icons.lock_outline, // Icon for Change Password
                      color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                      size: 22,
                    ),
                    title: Text(
                      "Changer le mot de passe",
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/clientHome/change-password');
                    },
                  ),
                  ListTile(
                    leading: Icon( // Icon for Notifications - remains same
                      Icons.notifications_outlined,
                      color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                      size: 22,
                    ),
                    title: Text(
                      "Notifications", // Text remains same
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isDarkMode ? Colors.white : Colors.black87,
                      ),
                    ),
                    trailing: StreamBuilder<int>(
                      stream: NotificationsPage.getUnreadNotificationsCount(), // Assuming this stream still provides the count
                      builder: (context, snapshot) {
                        final bool hasUnread = snapshot.hasData && snapshot.data! > 0;
                        if (hasUnread) {
                          return Container(
                            width: 12, // Size of the red dot
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDarkMode ? Colors.grey.shade900 : Colors.white, // Border color to match background
                                width: 1.5,
                              ),
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
                  // Removed logout button from here (this comment might be outdated from previous edits)
                ],
              ),
            ),
          ),
          // Theme Toggle Switch - Made larger and centered
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0), // Increased vertical padding for the switch area
            child: Align(
              alignment: Alignment.center, // Center the switch
              child: Transform.scale(
                scale: 1.2, // Make it 20% larger
                child: ThemeToggleSwitch(),
              ),
            ),
          ),
          // Logout Button - Styled Red
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0), // Adjusted padding
            child: ListTile(
              leading: const Icon(
                Icons.logout_rounded,
                color: Colors.red, // Icon color red
                size: 22,
              ),
              title: Text(
                "Se déconnecter",
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.red, // Text color red
                ),
              ),
              onTap: _logout,
              dense: true,
              // Optional: Add a subtle background or shape for emphasis if desired
              // tileColor: Colors.red.withOpacity(0.05),
              // shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
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
          // Theme toggle removed from here
          // const SizedBox(height: 8), // This SizedBox might be conditional on the theme toggle's presence or can be adjusted
          // Make avatar bigger and centered. We might need a placeholder or adjust spacing if Align was the only thing at top.
          // For now, let's assume the avatar is the topmost visual element after this change.
          // If Align was providing some specific spacing, that might need to be re-added or handled differently.
          // Let's add a SizedBox to maintain some top padding if ThemeToggleSwitch was the only thing there.
          // However, looking at the original, ThemeToggleSwitch was inside Align(topRight), so it didn't push content down.
          // The SizedBox(height: 8) was after it.
          // So, removing Align and ThemeToggleSwitch, and the SizedBox(height:8) that followed it.
          // The CircleAvatar will now be closer to the top of the header.
          // If a top padding is desired for the header content, it should be part of the parent Container's padding or an initial SizedBox.
          // The parent Container has `padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16)`.
          // This vertical padding should provide enough space at the top.

          const SizedBox(height: 16.0), // Added top spacing for the avatar
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

// Ensure ThemeToggleSwitch is imported if not already:
// import 'theme_toggle_switch.dart'; // Already at the top of the file
