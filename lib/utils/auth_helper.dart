import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../login_signup/login_page.dart';

class AuthHelper {
  static Future<bool> checkUserRole(BuildContext context, String requiredRole) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _redirectToLogin(context);
      return false;
    }

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!doc.exists || doc.data()?['role'] != requiredRole) {
      _redirectToLogin(context);
      return false;
    }

    return true;
  }

  static void _redirectToLogin(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  static Future<void> signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    _redirectToLogin(context);
  }
}