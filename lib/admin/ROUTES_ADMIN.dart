import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'accueil_admin.dart';
import 'gérer_services.dart';
import 'provider_list_page.dart';
import 'provider_approval_page.dart';
import 'valider_publications.dart';
import 'post_details_page.dart'; // Add this import
import 'reclamations_management_page.dart';
import 'reclamation_details_page.dart';
import 'accounts_management_page.dart'; // Add this import

// Define all admin-related routes
final adminRoutes = GoRoute(
  path: '/admin',
  builder: (BuildContext context, GoRouterState state) => const AdminHomePage(),
  routes: [
    // Services management route
    GoRoute(
      path: 'services',
      builder: (BuildContext context, GoRouterState state) => 
          const ServicesManagementPage(),
    ),
    
    // Provider approval list route
    GoRoute(
      path: 'providers',
      builder: (BuildContext context, GoRouterState state) => 
          const ProviderListPage(),
    ),
    
    // Provider approval details route
    GoRoute(
      path: 'providers/:providerId',
      builder: (BuildContext context, GoRouterState state) {
        final providerId = state.pathParameters['providerId'] ?? '';
        return ProviderApprovalDetailsPage(providerId: providerId);
      },
    ),
    
    // Posts validation list route
    GoRoute(
      path: 'posts',
      builder: (BuildContext context, GoRouterState state) => 
          const PostsValidationPage(),
    ),
    
    // Post details route
    GoRoute(
      path: 'posts/:postId',
      builder: (BuildContext context, GoRouterState state) {
        final postId = state.pathParameters['postId'] ?? '';
        return PostDetailsPage(postId: postId);
      },
    ),

    // Reclamations management route
    GoRoute(
      path: 'reclamations',
      builder: (BuildContext context, GoRouterState state) => 
          const ReclamationsManagementPage(),
    ),
    
    // Reclamation details route
    GoRoute(
      path: 'reclamations/details/:reclamationId',
      builder: (BuildContext context, GoRouterState state) {
        final reclamationId = state.pathParameters['reclamationId'] ?? '';
        return ReclamationDetailsPage(reclamationId: reclamationId);
      },
    ),

    // Accounts management route
    GoRoute(
      path: 'accounts',
      builder: (BuildContext context, GoRouterState state) =>
          const AccountsManagementPage(),
    ),
  ],
);
