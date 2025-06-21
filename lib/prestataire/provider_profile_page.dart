import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../front/app_colors.dart';
import '../front/app_spacing.dart';
import '../front/app_typography.dart';
import '../utils/auth_helper.dart';
import '../front/theme_toggle_switch.dart';

class ProviderProfilePage extends StatefulWidget {
  const ProviderProfilePage({super.key});

  @override
  State<ProviderProfilePage> createState() => _ProviderProfilePageState();
}

class _ProviderProfilePageState extends State<ProviderProfilePage> {
  late Future<DocumentSnapshot> _userDataFuture;
  late Future<DocumentSnapshot> _providerDataFuture; // New: Future for provider data

  @override
  void initState() {
    super.initState();
    _userDataFuture = _fetchUserData();
    _providerDataFuture = _fetchProviderData(); // New: Fetch provider data
  }

  Future<DocumentSnapshot> _fetchUserData() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return Future.error('User not logged in');
    }
    return FirebaseFirestore.instance.collection('users').doc(userId).get();
  }

  // New: Method to fetch provider data
  Future<DocumentSnapshot> _fetchProviderData() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      return Future.error('User not logged in');
    }
    return FirebaseFirestore.instance.collection('providers').doc(userId).get();
  }

  Future<void> _logout() async {
    final bool confirmLogout = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Déconnexion'),
          content: const Text('Êtes-vous sûr de vouloir vous déconnecter ?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Déconnecter'),
            ),
          ],
        );
      },
    ) ?? false; // Default to false if dialog is dismissed

    if (confirmLogout) {
      await AuthHelper.signOut(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;

    return FutureBuilder<DocumentSnapshot>(
      future: _userDataFuture,
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: primaryColor));
        }
        if (userSnapshot.hasError) {
          return Center(child: Text('Erreur de chargement du profil: ${userSnapshot.error}', style: AppTypography.bodyLarge(context).copyWith(color: AppColors.errorRed)));
        }
        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return Center(child: Text('Profil utilisateur introuvable.', style: AppTypography.bodyLarge(context).copyWith(color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)));
        }

        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final firstName = userData['firstname'] ?? 'Prénom';
        final lastName = userData['lastname'] ?? 'Nom';
        final email = userData['email'] ?? 'Email non disponible';
        final avatarUrl = userData['avatarUrl'] as String?;
        final role = userData['role'] ?? 'Rôle non défini';

        return FutureBuilder<DocumentSnapshot>(
          future: _providerDataFuture,
          builder: (context, providerSnapshot) {
            if (providerSnapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: primaryColor));
            }
            if (providerSnapshot.hasError) {
              return Center(child: Text('Erreur de chargement des données prestataire: ${providerSnapshot.error}', style: AppTypography.bodyLarge(context).copyWith(color: AppColors.errorRed)));
            }
            // providerData might be null if the user is not a provider or hasn't submitted yet
            final providerData = providerSnapshot.data?.data() as Map<String, dynamic>?;

            return Scaffold(
              body: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: AppSpacing.lg), // Added spacing for app bar area
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg), 
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg, horizontal: AppSpacing.md),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.grey.shade900 : Colors.white,
                          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
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
                            CircleAvatar(
                              radius: AppSpacing.xxl + AppSpacing.sm,
                              backgroundColor: primaryColor.withOpacity(0.2),
                              child: avatarUrl != null && avatarUrl.isNotEmpty
                                  ? ClipOval(
                                      child: Image.network(
                                        avatarUrl,
                                        width: (AppSpacing.xxl + AppSpacing.sm) * 2,
                                        height: (AppSpacing.xxl + AppSpacing.sm) * 2,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Icon(
                                          Icons.person,
                                          size: AppSpacing.iconXl,
                                          color: primaryColor,
                                        ),
                                      ),
                                    )
                                  : Icon(
                                      Icons.person,
                                      size: AppSpacing.iconXl,
                                      color: primaryColor,
                                    ),
                            ),
                            AppSpacing.verticalSpacing(AppSpacing.md),
                            Text(
                              '$firstName $lastName',
                              style: AppTypography.h2(context).copyWith(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                            AppSpacing.verticalSpacing(AppSpacing.xs),
                            Text(
                              email,
                              style: AppTypography.bodyMedium(context).copyWith(color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                              textAlign: TextAlign.center,
                            ),
                            AppSpacing.verticalSpacing(AppSpacing.xs),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                              ),
                              child: Text(
                                role.toUpperCase(),
                                style: AppTypography.labelMedium(context).copyWith(color: primaryColor, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    AppSpacing.verticalSpacing(AppSpacing.lg),
                    Padding( 
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      child: Column(
                        children: [
                          _buildActionButton(
                            context,
                            isDarkMode,
                            Icons.person_outline,
                            'Modifier le profil',
                            () {
                              context.push('/prestataireHome/edit-profile', extra: {
                                'providerId': FirebaseAuth.instance.currentUser!.uid,
                                'providerData': providerData, 
                                'userData': userData,
                              });
                            },
                          ),
                          _buildActionButton(
                            context,
                            isDarkMode,
                            Icons.lock_outline,
                            'Changer le mot de passe',
                            () => context.push('/prestataireHome/change-password'),
                          ),
                          _buildActionButton(
                            context,
                            isDarkMode,
                            Icons.business_center_outlined,
                            'Modifier info professionnelles',
                            () {
                              context.push(
                                '/prestataireHome/edit-professional-info',
                                extra: {
                                  'initialProviderData': providerData, 
                                  'initialUserData': userData,
                                },
                              );
                            },
                          ),
                          _buildActionButton(
                            context,
                            isDarkMode,
                      Icons.notifications_outlined,
                      'Notifications',
                      () => context.push('/prestataireHome/notifications'),
                    ),
                    // AppSpacing.verticalSpacing(AppSpacing.lg), // REMOVED for consistent spacing
                    _buildThemeActionButton(context, isDarkMode),
                    _buildActionButton(
                      context,
                            isDarkMode,
                            Icons.logout_rounded,
                            'Se déconnecter',
                            () => _logout(), 
                            isDestructive: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionButton(BuildContext context, bool isDarkMode, IconData icon, String label, VoidCallback onTap, {bool isDestructive = false}) {
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;
    final textColor = isDestructive ? Colors.red : (isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary);
    final iconColor = isDestructive ? Colors.red : primaryColor;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: AppSpacing.md, right: AppSpacing.md), 
      child: ListTile(
        leading: Icon(icon, size: AppSpacing.iconMd, color: iconColor),
        title: Text(
          label,
          style: AppTypography.bodyLarge(context).copyWith(color: textColor),
        ),
        trailing: Icon(Icons.arrow_forward_ios, size: AppSpacing.iconSm, color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
        onTap: onTap,
        tileColor: isDarkMode ? AppColors.darkCardBackground : AppColors.lightCardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
      ),
    );
  }

  Widget _buildThemeActionButton(BuildContext context, bool isDarkMode) {
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm, left: AppSpacing.md, right: AppSpacing.md), 
      child: ListTile(
        leading: Icon(Icons.brightness_6_outlined, size: AppSpacing.iconMd, color: primaryColor),
        title: Text(
          'Thème',
          style: AppTypography.bodyLarge(context).copyWith(color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
        ),
        trailing: Transform.scale(
          scale: 0.8, 
          child: const ThemeToggleSwitch(),
        ),
        onTap: () {
          // Tapping the ListTile will not open the PopupMenuButton directly.
          // The ThemeToggleSwitch itself handles its tap.
          // This onTap is primarily for visual feedback if the user taps outside the switch.
        },
        tileColor: isDarkMode ? AppColors.darkCardBackground : AppColors.lightCardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
      ),
    );
  }
}
