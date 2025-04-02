import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'inscription.dart';
import 'connexion.dart';
import 'vérification_email.dart';
import 'compléter_profil.dart';
import 'mot_passe_oublié.dart';

// This router configuration can be imported and used in the main router
final loginSignupRoutes = [
  GoRoute(
    path: '/',
    builder: (BuildContext context, GoRouterState state) => const LoginPage(),
    routes: [
      GoRoute(
        path: 'signup',  // This is correct - it becomes '/signup' when accessed
        builder: (BuildContext context, GoRouterState state) => SignupPage(),
      ),
      GoRoute(
        path: 'verification',  // This becomes '/verification' when accessed
        builder: (BuildContext context, GoRouterState state) => const VerificationPage(),
      ),
      GoRoute(
        path: 'signup2',  // This becomes '/signup2' when accessed
        builder: (BuildContext context, GoRouterState state) => const Signup2Page(),
      ),
      GoRoute(
        path: 'forgot-password',  // This becomes '/forgot-password' when accessed
        builder: (BuildContext context, GoRouterState state) => const ForgotPasswordPage(),
      ),
    ],
  ),
];