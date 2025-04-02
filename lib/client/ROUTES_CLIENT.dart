import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'accueil_client.dart';
import 'liste_prestataires.dart';
import 'marketplace/accueil_marketplace.dart';
import 'marketplace/ajouter_publication.dart';
import 'marketplace/liste_publications.dart';
import 'marketplace/favoris.dart';
import 'marketplace/details_publication.dart';
import 'marketplace/modifier_publication.dart';  // File has ModifierPostPage
import '../profile_edit_page.dart';
import 'page_notifications.dart';
import 'marketplace/liste_conversations.dart';
import 'marketplace/conversation_marketplace.dart';
import 'my_requests_page.dart'; // Make sure this import is present
import '../chat/conversation_service_page.dart';  // Add this import

final clientRoutes = GoRoute(
  path: '/clientHome',
  builder: (context, state) => const ClientHomePage(),
  routes: [
    GoRoute(
      path: 'marketplace',
      builder: (context, state) => const MarketplacePage(),
      routes: [
        GoRoute(
          path: 'add',
          builder: (context, state) => const AddPostPage(),
        ),
        GoRoute(
          path: 'favorites',
          builder: (context, state) => const FavorisPage(),
        ),
        GoRoute(
          path: 'my-products',
          builder: (context, state) => const MesProduitsPage(),
        ),
        GoRoute(
          path: 'chat',
          builder: (context, state) => const ChatListScreen(),
          routes: [
            GoRoute(
              path: 'conversation/:otherUserId',
              builder: (context, state) {
                final params = state.extra as Map<String, dynamic>;
                return ChatScreenPage(
                  otherUserId: state.pathParameters['otherUserId']!,
                  postId: params['postId'],
                  otherUserName: params['otherUserName'],
                );
              },
            ),
            // Ajouter cette route si elle n'existe pas déjà
         
          ],
        ),
        GoRoute(
          path: 'details/:postId',
          builder: (context, state) {
            final post = state.extra as DocumentSnapshot?;
            if (post == null) {
              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance
                    .collection('marketplace')
                    .doc(state.pathParameters['postId'])
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data == null) {
                    return const Scaffold(
                      body: Center(child: Text("Post not found")),
                    );
                  }
                  return PostDetailsPage(post: snapshot.data!);
                },
              );
            }
            return PostDetailsPage(post: post);
          },
        ),
        GoRoute(
          path: 'edit/:postId',
          builder: (context, state) {
            final post = state.extra as DocumentSnapshot;
            return ModifyPostPage(post: post);
          },
        ),
      ],
    ),
    GoRoute(
      path: 'services/:serviceName',
      builder: (context, state) {
        final serviceName = state.pathParameters['serviceName']!;
        return ServiceProvidersPage(serviceName: serviceName);
      },
    ),
    // Profile and notifications are now properly nested under /clientHome
    GoRoute(
      path: 'profile',
      builder: (context, state) => const ProfileEditPage(),
    ),
    GoRoute(
      path: 'notifications',
      builder: (context, state) => const NotificationsPage(),
    ),
    // Make sure this route is properly defined
    // Add a route for chat conversations
    GoRoute(
      path: 'chat/conversation/:otherUserId',
      builder: (context, state) {
        final params = state.extra as Map<String, dynamic>?;
        return ConversationServicePage(
          otherUserId: state.pathParameters['otherUserId']!,
          otherUserName: params?['otherUserName'] ?? 'Prestataire',
        );
      },
    ),
    // Add a route for request-service if it doesn't exist
    GoRoute(
      path: 'request-service',
      builder: (context, state) => const Scaffold(
        body: Center(child: Text('Request Service Page')),
      ),
    ),
     GoRoute(
      path: 'my-requests',
      builder: (context, state) => const MyRequestsPage(),
    ),
  ],
);