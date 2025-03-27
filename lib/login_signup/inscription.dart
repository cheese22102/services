import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../widgets/custom_button.dart';
import '../widgets/social_icon.dart';
import'../widgets/labeled_text_field.dart';
import '../widgets/custom_dialog.dart';
import '../widgets/password_strength_indicator.dart';
import '../widgets/dark_mode_switch.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  bool _isLoading = false;
  // In the state class, add these variables
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  
  void _showErrorDialog(String message) {
    CustomDialog.show(
      context,
      "Erreur d'inscription",
      message,
    );
  }

  void _showSuccessDialog(String message) {
    CustomDialog.show(
      context,
      "Succès",
      message,
      onConfirm: () {
        // Replace Navigator with GoRouter
        context.push('/verification');
      },
    );
  }

  Future<void> _signupWithEmail() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_passwordController.text != _confirmPasswordController.text) {
      _showErrorDialog("Les mots de passe ne correspondent pas");
      return;
    }
    
    setState(() => _isLoading = true);

    try {
      final UserCredential userCredential = 
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (userCredential.user != null) {
        await _handleNewUser(userCredential.user!);
      }
    } on FirebaseAuthException catch (e) {
      _handleSignupError(e);
    } catch (e) {
      _showErrorDialog("Une erreur inattendue s'est produite");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleNewUser(User user) async {
    try {
      await user.sendEmailVerification();
      
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': user.email,
        'createdAt': FieldValue.serverTimestamp(),
        'role': 'pending',
        'emailVerified': false,  // Add this line
      });

      _showSuccessDialog(
        "Votre compte a été créé avec succès. Veuillez vérifier votre email pour activer votre compte."
      );
    } catch (e) {
      _showErrorDialog("Erreur lors de la configuration du compte");
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = 
          await FirebaseAuth.instance.signInWithCredential(credential);
      
      if (userCredential.user != null) {
        await _handleGoogleUser(userCredential);
      }
    } on FirebaseAuthException catch (e) {
      _showErrorDialog("Erreur Google : ${e.message}");
    } catch (e) {
      _showErrorDialog("Une erreur s'est produite lors de la connexion avec Google");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleUser(UserCredential userCredential) async {
    final user = userCredential.user!;
    final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

    try {
      if (isNewUser) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': user.email,
          'role': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
          'provider': 'google',
          'emailVerified': true,  // Google users are already verified
        });
        
        _showSuccessDialog(
          "Votre compte Google a été créé avec succès. Vous allez être redirigé."
        );
      } else {
        _showErrorDialog("Un compte existe déjà avec cet email Google");
      }
    } catch (e) {
      _showErrorDialog("Erreur lors de la configuration du compte Google");
    }
  }

  void _handleSignupError(FirebaseAuthException e) {
    String message = "Échec de l'inscription";
    switch (e.code) {
      case 'email-already-in-use':
        message = "Cette adresse email est déjà utilisée";
        break;
      case 'weak-password':
        message = "Le mot de passe doit contenir au moins 6 caractères";
        break;
      case 'invalid-email':
        message = "Format d'email invalide";
        break;
      case 'operation-not-allowed':
        message = "La création de compte est temporairement désactivée";
        break;
      case 'network-request-failed':
        message = "Vérifiez votre connexion internet";
        break;
      case 'too-many-requests':
        message = "Trop de tentatives. Réessayez plus tard";
        break;
      default:
        message = "Une erreur s'est produite: ${e.message}";
    }
    _showErrorDialog(message);
  }

  // Add this widget builder method
  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required IconData icon,
    required String hint,
    required String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabeledTextField(
          label: label,
          controller: controller,
          hint: hint,
          icon: icon,
          obscure: obscure,
          suffixIcon: IconButton(
            icon: Icon(
              obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: Theme.of(context).brightness == Brightness.dark 
                ? Colors.grey[400] 
                : Colors.grey[600],
            ),
            onPressed: () => setState(() {
              if (label == 'Mot de passe') {
                _obscurePassword = !_obscurePassword;
              } else {
                _obscureConfirmPassword = !_obscureConfirmPassword;
              }
            }),
          ),
          validator: validator,
        ),
        if (label == 'Mot de passe') // Show strength indicator only for main password
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: PasswordStrengthIndicator(password: controller.text),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with back button and dark mode switch
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        onPressed: () => context.go('/'),  // Navigate to root route
                      ),
                      const DarkModeSwitch(),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Illustration d'inscription
                  Center(
                    child: Image.asset(
                      "assets/images/register.png",
                      height: 180,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Texte d'inscription
                  Text(
                    "S'inscrire",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  Text(
                    "Remplissez vos informations ci-dessous",
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Champ Email
                  LabeledTextField(
                    label: 'Email',
                    controller: _emailController,
                    hint: 'Entrez votre email',
                    icon: Icons.email,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "L'email est requis";
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return "Format d'email invalide";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Champ Mot de passe
                  _buildPasswordField(
                    label: 'Mot de passe',
                    controller: _passwordController,
                    obscure: _obscurePassword,
                    icon: Icons.lock,
                    hint: 'Entrez votre mot de passe',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Le mot de passe est requis';
                      }
                      if (value.length < 8) {
                        return 'Le mot de passe doit contenir au moins 8 caractères';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Champ Confirmation mot de passe
                  _buildPasswordField(
                    label: 'Confirmer le mot de passe',
                    controller: _confirmPasswordController,
                    obscure: _obscureConfirmPassword,
                    icon: Icons.lock_outline,
                    hint: 'Confirmez votre mot de passe',
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez confirmer votre mot de passe';
                      }
                      if (value != _passwordController.text) {
                        return 'Les mots de passe ne correspondent pas';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),

                  // Bouton d'inscription
                  CustomButton(
                    text: "S'inscrire",
                    onPressed: _isLoading ? () {} : _signupWithEmail,
                  ),
                  const SizedBox(height: 24),

                  // Section Connexion Sociale
                  Center(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: isDark ? Colors.grey[700] : Colors.grey[300],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text(
                                'Ou continuer avec',
                                style: TextStyle(
                                  color: isDark ? Colors.grey[400] : Colors.grey,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: isDark ? Colors.grey[700] : Colors.grey[300],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            onTap: _signInWithGoogle,
                            child: const Padding(
                              padding: EdgeInsets.all(12),
                              child: SocialIcon(
                                imagePath: "assets/images/google.jpg",
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Lien de Connexion
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Vous avez déjà un compte ? ",
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey,
                          ),
                        ),
                        // When navigating back to login from signup
                        TextButton(
                          onPressed: () => context.go('/'),
                          child: Text(
                            'Se connecter',
                            style: TextStyle(
                              color: isDark ? const Color(0xFF62B6CB) : const Color(0xFF1A5F7A),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() {
      setState(() {});  // This will rebuild the widget when password changes
    });
  }

  @override
  void dispose() {
    _passwordController.removeListener(() {});
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailController.dispose();
    super.dispose();
  }
}