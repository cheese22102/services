import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async'; // Ajoutez cette ligne

class VerificationPage extends StatefulWidget {
  const VerificationPage({super.key});

  @override
  _VerificationPageState createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  late User _user;
  bool _isLoading = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser!;
    _startVerificationCheck();
  }

  void _startVerificationCheck() {
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _checkVerification());
  }

  Future<void> _checkVerification() async {
    await _user.reload();
    final currentUser = FirebaseAuth.instance.currentUser!;
    
    if (currentUser.emailVerified) {
      _timer?.cancel();
      _navigateBasedOnProfile();
    }
  }

  Future<void> _navigateBasedOnProfile() async {
  final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(_user.uid)
      .get();

  if (doc.exists) {
    final data = doc.data();
    final role = data?['role'] ?? 'client';
    final profileCompleted = data?['profileCompleted'] ?? false;

    if (profileCompleted) {
      Navigator.pushReplacementNamed(
        context, 
        role == 'client' ? '/clientHome' : '/prestataireHome'
      );
      return;
    }
  }
  
  Navigator.pushReplacementNamed(context, '/signup2');
}

  Future<void> _resendVerification() async {
    setState(() => _isLoading = true);
    try {
      await _user.sendEmailVerification();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email de vérification envoyé !')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vérification Email')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mark_email_unread_outlined,
                  size: 100, color: Theme.of(context).primaryColor),
              const SizedBox(height: 30),
              Text(
                'Un email de vérification a été envoyé à:',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                _user.email ?? '',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Renvoyer l\'email'),
                onPressed: _isLoading ? null : _resendVerification,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('J\'ai déjà vérifié'),
                onPressed: _checkVerification,
              ),
              if (_isLoading) const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}