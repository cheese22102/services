import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // Import go_router
import 'package:google_sign_in/google_sign_in.dart'; // Import google_sign_in

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
    // Use GoRouter for navigation
    context.go('/');
  }

  static Future<void> signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut(); // Sign out from Google as well
    _redirectToLogin(context);
  }
}
