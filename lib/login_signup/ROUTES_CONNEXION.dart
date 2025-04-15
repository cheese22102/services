import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'inscription.dart';
import 'connexion.dart';
import 'vérification_email.dart';
import 'compléter_profil.dart';
import 'mot_passe_oublié.dart';
import '../front/page_transition.dart';

// This router configuration can be imported and used in the main router
final loginSignupRoutes = [
  GoRoute(
    path: '/',
    pageBuilder: (BuildContext context, GoRouterState state) {
      final extra = state.extra as Map<String, dynamic>?;
      final direction = extra?['direction'] as String?;
      
      return CustomTransitionPage(
        key: state.pageKey,
        child: const LoginPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (direction == null) {
            return FadeTransition(opacity: animation, child: child);
          }
          
          return CustomPageTransition(
            animation: animation,
            direction: direction == 'leftToRight' 
                ? SlideDirection.leftToRight 
                : SlideDirection.rightToLeft,
            child: child,
          );
        },
      );
    },
    routes: [
      GoRoute(
        path: 'signup',
        pageBuilder: (BuildContext context, GoRouterState state) {
          final extra = state.extra as Map<String, dynamic>?;
          final direction = extra?['direction'] as String?;
          
          return CustomTransitionPage(
            key: state.pageKey,
            child: const SignupPage(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              if (direction == null) {
                return FadeTransition(opacity: animation, child: child);
              }
              
              var begin = direction == 'rightToLeft' 
                  ? const Offset(1.0, 0.0) 
                  : const Offset(-1.0, 0.0);
              var end = Offset.zero;
              var curve = Curves.easeInOutCubic;
              var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              var offsetAnimation = animation.drive(tween);
              
              return SlideTransition(
                position: offsetAnimation,
                child: FadeTransition(opacity: animation, child: child),
              );
            },
          );
        },
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