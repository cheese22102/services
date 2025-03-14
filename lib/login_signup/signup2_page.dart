import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Signup2Page extends StatefulWidget {
  const Signup2Page({super.key});

  @override
  _Signup2PageState createState() => _Signup2PageState();
}

class _Signup2PageState extends State<Signup2Page> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  String _role = "client"; // Valeur par défaut

  // Fonction pour enregistrer les informations dans Firestore
  Future<void> _saveUserInfo() async {
    if (_formKey.currentState!.validate()) {
      try {
        final user = FirebaseAuth.instance.currentUser;

        if (user != null) {
          // Enregistrer les données dans Firestore sans écraser les anciennes
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
            'firstName': _firstNameController.text.trim(),
            'lastName': _lastNameController.text.trim(),
            'role': _role,
          }, SetOptions(merge: true)); // Merge pour éviter d’écraser les anciennes données

          // Redirection vers la page appropriée en fonction du rôle
          if (_role == "client") {
            Navigator.pushReplacementNamed(context, '/clientHome');
          } else {
            Navigator.pushReplacementNamed(context, '/prestataireHome');
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de l'enregistrement : $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Complétez vos informations"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(labelText: 'Prénom'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer votre prénom';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(labelText: 'Nom'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer votre nom';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              // Sélection du rôle
              DropdownButtonFormField<String>(
                value: _role,
                onChanged: (String? newValue) {
                  setState(() {
                    _role = newValue!;
                  });
                },
                items: const [
                  DropdownMenuItem(value: "client", child: Text("Client")),
                  DropdownMenuItem(value: "prestataire", child: Text("Prestataire")),
                ],
                decoration: const InputDecoration(labelText: 'Rôle'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _saveUserInfo,
                child: const Text("Enregistrer"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
