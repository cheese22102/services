import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'custom_text_field.dart'; // Assuming CustomTextField is in lib/front/
import 'custom_button.dart';    // Assuming CustomButton is in lib/front/
import 'custom_snackbar.dart';  // Assuming CustomSnackbar is in lib/front/
import 'password_strength_indicator.dart'; // Assuming PasswordStrengthIndicator is in lib/front/
import 'loading_overlay.dart'; // Assuming LoadingOverlay is in lib/front/
import 'package:go_router/go_router.dart';

class ChangerMotDePassePage extends StatefulWidget {
  const ChangerMotDePassePage({super.key});

  @override
  State<ChangerMotDePassePage> createState() => _ChangerMotDePassePageState();
}

class _ChangerMotDePassePageState extends State<ChangerMotDePassePage> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmNewPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureOldPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmNewPassword = true;

  String? _authProviderId;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    if (_currentUser != null) {
      // Check the primary sign-in method
      for (var providerData in _currentUser!.providerData) {
        if (providerData.providerId == 'password') {
          _authProviderId = 'password';
          break;
        } else if (providerData.providerId == 'google.com') {
          _authProviderId = 'google.com';
          // If google.com is found, it's likely the primary for passwordless Google sign-in
          // unless 'password' is also explicitly listed (e.g. linked accounts)
        }
      }
      // If after checking all providers, 'password' was not found but 'google.com' was,
      // and there's only one provider (Google), then it's a Google-only sign-in.
      if (_authProviderId != 'password' && _currentUser!.providerData.length == 1 && _currentUser!.providerData[0].providerId == 'google.com') {
         _authProviderId = 'google.com';
      } else if (_authProviderId == null && _currentUser!.providerData.isNotEmpty) {
        // Fallback if only other OAuth providers are present (e.g. Facebook, Apple)
         _authProviderId = _currentUser!.providerData[0].providerId;
      }


    }
    _newPasswordController.addListener(() {
      setState(() {}); // To update password strength indicator
    });
  }

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_newPasswordController.text != _confirmNewPasswordController.text) {
      CustomSnackbar.showError(context: context, message: 'Les nouveaux mots de passe ne correspondent pas.');
      return;
    }

    // Check if new password is the same as the old one
    if (_oldPasswordController.text == _newPasswordController.text) {
      CustomSnackbar.showError(context: context, message: 'Le nouveau mot de passe doit être différent de l\'ancien.');
      // Do not set _isLoading to true or show LoadingOverlay if this check fails
      return;
    }

    setState(() => _isLoading = true);
    LoadingOverlay.show(context, message: 'Modification du mot de passe...');

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        throw Exception('Utilisateur non trouvé ou email manquant.');
      }

      // Re-authenticate user
      AuthCredential credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _oldPasswordController.text,
      );

      await user.reauthenticateWithCredential(credential);

      // Change password
      await user.updatePassword(_newPasswordController.text);

      if (mounted) {
        LoadingOverlay.hide();
        CustomSnackbar.showSuccess(context: context, message: 'Mot de passe modifié avec succès !');
        // Optionally pop or navigate away
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/clientHome/profile'); // Fallback navigation
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) LoadingOverlay.hide();
      String errorMessage = "Une erreur s'est produite.";
      if (e.code == 'wrong-password') {
        errorMessage = 'L\'ancien mot de passe est incorrect.';
      } else if (e.code == 'weak-password') {
        errorMessage = 'Le nouveau mot de passe est trop faible.';
      } else if (e.code == 'requires-recent-login') {
        errorMessage = 'Cette opération nécessite une connexion récente. Veuillez vous reconnecter.';
      }
      if (mounted) CustomSnackbar.showError(context: context, message: errorMessage);
    } catch (e) {
      if (mounted) LoadingOverlay.hide();
      if (mounted) CustomSnackbar.showError(context: context, message: 'Erreur: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;
    final backgroundColor = isDarkMode ? AppColors.darkBackground : AppColors.lightInputBackground;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'Changer le mot de passe',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.white : Colors.black87,
          ),
        ),
        backgroundColor: backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryColor),
      ),
      body: _currentUser == null
          ? Center(child: Text("Utilisateur non connecté.", style: GoogleFonts.poppins(color: isDarkMode ? Colors.white70 : Colors.black54)))
          : _authProviderId != 'password'
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.lock_outline, size: 80, color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400),
                        const SizedBox(height: 20),
                        Text(
                          'Modification de mot de passe non applicable',
                          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: isDarkMode ? Colors.white : Colors.black87),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _authProviderId == 'google.com'
                              ? 'Vous êtes connecté avec Google. Pour des raisons de sécurité, veuillez gérer votre mot de passe via votre compte Google.'
                              : 'Vous êtes connecté via un fournisseur externe (${_authProviderId ?? 'inconnu'}). La modification de mot de passe se fait via ce fournisseur.',
                          style: GoogleFonts.poppins(fontSize: 14, color: isDarkMode ? Colors.white70 : Colors.black54),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CustomTextField(
                          controller: _oldPasswordController,
                          labelText: 'Ancien mot de passe',
                          hintText: 'Entrez votre ancien mot de passe',
                          obscureText: _obscureOldPassword,
                          prefixIcon: Icon(Icons.lock_open_outlined, color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureOldPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                            onPressed: () => setState(() => _obscureOldPassword = !_obscureOldPassword),
                          ),
                          validator: (value) => value == null || value.isEmpty ? 'Champ requis' : null,
                        ),
                        const SizedBox(height: 20),
                        CustomTextField(
                          controller: _newPasswordController,
                          labelText: 'Nouveau mot de passe',
                          hintText: 'Entrez votre nouveau mot de passe',
                          obscureText: _obscureNewPassword,
                           prefixIcon: Icon(Icons.lock_outline, color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureNewPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                            onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Champ requis';
                            if (value.length < 6) return 'Au moins 6 caractères';
                            if (!value.contains(RegExp(r'[A-Z]'))) return 'Au moins une majuscule';
                            if (!value.contains(RegExp(r'[a-z]'))) return 'Au moins une minuscule'; // Added lowercase check
                            if (!value.contains(RegExp(r'[0-9]'))) return 'Au moins un chiffre';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        PasswordStrengthIndicator(
                          password: _newPasswordController.text,
                          isDarkMode: isDarkMode,
                        ),
                        const SizedBox(height: 20),
                        CustomTextField(
                          controller: _confirmNewPasswordController,
                          labelText: 'Confirmer le nouveau mot de passe',
                          hintText: 'Retapez votre nouveau mot de passe',
                          obscureText: _obscureConfirmNewPassword,
                          prefixIcon: Icon(Icons.lock_outline, color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureConfirmNewPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                            onPressed: () => setState(() => _obscureConfirmNewPassword = !_obscureConfirmNewPassword),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Champ requis';
                            if (value != _newPasswordController.text) return 'Les mots de passe ne correspondent pas';
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),
                        CustomButton(
                          text: 'Enregistrer les modifications',
                          onPressed: _isLoading ? null : _changePassword,
                          isLoading: _isLoading,
                          height: 50,
                          backgroundColor: primaryColor,
                          useFullScreenLoader: true,
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
