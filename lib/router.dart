import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'login_signup/ROUTES_CONNEXION.dart';
import 'tutorial_screen.dart';
import 'admin/ROUTES_ADMIN.dart'; // Import the admin routes
import 'client/ROUTES_CLIENT.dart';
import 'prestataire/ROUTES_PRESTATAIRE.dart';
import 'initial_loading_screen.dart'; // Import the new initial loading screen

class AppRouter {
  static GoRouter createRouter(bool isFirstLaunchApp) {
    return GoRouter(
      initialLocation: '/initial-loading', // Start at the initial loading screen
      redirect: (context, state) async {
        // No complex redirect logic here, InitialLoadingScreen handles it.
        return null;
      },
      routes: <RouteBase>[
        GoRoute(
          path: '/initial-loading',
          builder: (BuildContext context, GoRouterState state) => const InitialLoadingScreen(),
        ),
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
  }
}
