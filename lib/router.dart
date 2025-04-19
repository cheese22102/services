import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
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
    
    if (isFirstLaunch && state.matchedLocation != '/tutorial') {
      return '/tutorial';
    }
    return null;
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