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
      // Allow access to login/signup routes, verification, complete profile, and tutorial
      if (state.matchedLocation.startsWith('/') || 
          state.matchedLocation.startsWith('/signup') || 
          state.matchedLocation.startsWith('/forgot-password') ||
          state.matchedLocation.startsWith('/verification') || // Added
          state.matchedLocation.startsWith('/completer-profile') || // Added
          state.matchedLocation == '/tutorial') {
        return null; // Allow access to these routes
      }
      // Redirect to login for all other routes
      return '/login';
    } else {
      // User is logged in
      print('User logged in: ${currentUser.uid}');
      print('Current location: ${state.matchedLocation}');

      try {
        // Reload user to get the latest email verification status
        await currentUser.reload();
        final updatedUser = FirebaseAuth.instance.currentUser; // Get reloaded user

        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(updatedUser!.uid) // Use updatedUser
            .get();
        
        final userData = userDoc.data();
        // Determine if signed in with Google based on provider data
        final isGoogleSignIn = updatedUser.providerData.any((info) => info.providerId == 'google.com');
        final profileCompleted = userData?['profileCompleted'] ?? false;
        final userRole = userData?['role'] as String?;

        // If user document does not exist, force profile completion
        // This handles cases where a user is authenticated but their Firestore profile isn't created yet.
        if (!userDoc.exists) {
          if (state.matchedLocation != '/completer-profile') {
            return '/completer-profile';
          }
          return null; // Allow access to complete profile page
        }

        // 1. Email Verification Check (for non-Google sign-ins)
        // If email is not verified AND it's not a Google sign-in
        if (!updatedUser.emailVerified && !isGoogleSignIn) { // Use updatedUser
          // If not already on the verification page, redirect there
          if (state.matchedLocation != '/verification') {
            return '/verification';
          }
          // If already on /verification, allow it
          return null; 
        }

        // 2. Profile Completion Check (after email verification or if Google sign-in)
        // If profile is not completed
        if (!profileCompleted) {
          // If not already on the complete profile page, redirect there
          if (state.matchedLocation != '/completer-profile') {
            return '/completer-profile';
          }
          // If already on /completer-profile, allow it
          return null; 
        }
        
        // If trying to access login/signup/verification/complete-profile/root pages while logged in and fully set up, redirect to appropriate home
        if (state.matchedLocation.startsWith('/login') || 
            state.matchedLocation.startsWith('/signup') || 
            state.matchedLocation.startsWith('/forgot-password') ||
            state.matchedLocation.startsWith('/verification') || 
            state.matchedLocation.startsWith('/completer-profile') || 
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
        
        // Prevent access to routes not matching the user's role (only if profile is completed and email verified)
        if (userRole == 'admin' && !state.matchedLocation.startsWith('/admin')) {
          return '/admin';
        } else if (userRole == 'prestataire' && !state.matchedLocation.startsWith('/prestataireHome')) {
          return '/prestataireHome';
        } else if (userRole == 'client' && !state.matchedLocation.startsWith('/clientHome')) {
          return '/clientHome';
        }
      } catch (e) {
        print('Error in redirect logic: $e');
        // If there's an error (e.g., network issue, malformed user data),
        // redirect to login to prevent infinite loops or unhandled states.
        return '/login'; 
      }
    }
    
    return null; // Allow the navigation if no redirects were triggered
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
