import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_signup/ROUTES_CONNEXION.dart';
import 'tutorial_screen.dart';
import 'admin/ROUTES_ADMIN.dart'; // Import the admin routes
import 'client/ROUTES_CLIENT.dart';
import 'prestataire/ROUTES_PRESTATAIRE.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GoRouter router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('is_first_launch') ?? true;
    
    // If it's the first launch, show the tutorial
    if (isFirstLaunch && state.matchedLocation != '/tutorial') {
      return '/tutorial';
    }
    
    // Check if user is logged in
    final currentUser = FirebaseAuth.instance.currentUser;
    
    // If no user is logged in and not trying to access login/signup pages
    if (currentUser == null) {
      // Allow access to login/signup routes and tutorial
      if (state.matchedLocation.startsWith('/') || 
          state.matchedLocation.startsWith('/signup') || 
          state.matchedLocation.startsWith('/forgot-password') ||
          state.matchedLocation == '/tutorial') {
        return null; // Allow access to these routes
      }
      // Redirect to login for all other routes
      return '/login';
    } else {
      // User is logged in, check their role
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .get();
        
        if (userDoc.exists) {
          final userData = userDoc.data();
          final userRole = userData?['role'] as String?;
          
          // If trying to access login/signup pages while logged in, redirect to appropriate home
          if (state.matchedLocation.startsWith('/login') || 
              state.matchedLocation.startsWith('/signup') || 
              state.matchedLocation.startsWith('/forgot-password') ||
              state.matchedLocation == '/') {
            
            // Redirect based on role
            if (userRole == 'admin') {
              return '/admin';
            } else if (userRole == 'prestataire') {
              return '/prestataireHome';
            } else {
              return '/clientHome'; // Default to client
            }
          }
          
          // Prevent access to routes not matching the user's role
          if (userRole == 'admin' && !state.matchedLocation.startsWith('/admin')) {
            return '/admin';
          } else if (userRole == 'prestataire' && !state.matchedLocation.startsWith('/prestataireHome')) {
            return '/prestataireHome';
          } else if (userRole == 'client' && !state.matchedLocation.startsWith('/clientHome')) {
            return '/clientHome';
          }
        }
      } catch (e) {
        print('Error checking user role: $e');
      }
    }
    
    return null; // Allow the navigation
  },
  routes: <RouteBase>[
    ...loginSignupRoutes,
    clientRoutes,
    prestataireRoutes,    
    GoRoute(
      path: '/tutorial',
      builder: (BuildContext context, GoRouterState state) => const TutorialScreen(),
    ),
    adminRoutes, // Add the admin routes
  ],
);