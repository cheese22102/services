import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class VerificationPage extends StatefulWidget {
  const VerificationPage({super.key});

  @override
  _VerificationPageState createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  late User? user;

  @override
  void initState() {
    super.initState();
    user = FirebaseAuth.instance.currentUser;
    _checkVerificationStatus();
  }

  Future<void> _resendVerificationEmail(BuildContext context) async {
    try {
      if (user != null) {
        await user!.sendEmailVerification();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Un nouvel email de vérification a été envoyé.")),
        );
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erreur: ${e.message}")),
      );
    }
  }

  void _checkVerificationStatus() async {
    if (user != null) {
      await user!.reload();
      user = FirebaseAuth.instance.currentUser;

      if (user!.emailVerified) {
        // Vérifier si l'utilisateur a déjà complété son profil
        DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();

        if (userDoc.exists && userDoc.data() != null) {
          Map<String, dynamic> userData = userDoc.data() as Map<String, dynamic>;
          if (userData.containsKey('firstName') && userData.containsKey('lastName') && userData.containsKey('role')) {
            // Si les informations existent, rediriger vers la bonne page
            String role = userData['role'];
            if (role == "client") {
              Navigator.pushReplacementNamed(context, '/clientHome');
            } else {
              Navigator.pushReplacementNamed(context, '/prestataireHome');
            }
          } else {
            // Si les informations ne sont pas encore enregistrées, aller vers Signup2Page
            Navigator.pushReplacementNamed(context, '/signup2');
          }
        } else {
          // Si le document n'existe pas, aller vers Signup2Page
          Navigator.pushReplacementNamed(context, '/signup2');
        }
      } else {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Vérification de l'email")),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Un e-mail de vérification a été envoyé à votre adresse. Veuillez vérifier votre boîte de réception.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Text(
                "Si vous n'avez pas reçu l'e-mail, vérifiez votre dossier de spam ou demandez un autre e-mail de vérification.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => _resendVerificationEmail(context),
                child: const Text("Renvoyer l'email de vérification"),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _checkVerificationStatus,
                child: const Text("Vérifier maintenant"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
