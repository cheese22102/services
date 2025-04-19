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
import '../chat/conversation_service_page.dart';  // Add this import
import 'request_service_page.dart';
import 'provider_profile_page.dart';
import 'all_services_page.dart'; // Add this import
import 'chatbot_page.dart';


final clientRoutes = GoRoute(
  path: '/clientHome',
  builder: (context, state) => const ClientHomePage(),
  routes: [
    // Add the all-services route
    GoRoute(
      path: 'all-services',
      builder: (context, state) => const AllServicesPage(),
    ),
    
    // Update the service-providers route to handle parameters
    GoRoute(
      path: 'service-providers/:serviceName',
      builder: (context, state) {
        final serviceName = state.pathParameters['serviceName'] ?? '';
        return ServiceProvidersPage(serviceName: serviceName);
      },
    ),
    GoRoute(
  path: 'chatbot',
  builder: (context, state) => const ChatbotPage(),
),
    
    // Existing routes
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
           // Keep only one route for chatId
           GoRoute(
             path: ':chatId',
             builder: (context, state) {
               final chatId = state.pathParameters['chatId']!;
               return ChatScreenPage(chatId: chatId);
             },
           ),
           // Remove the duplicate route below
         ],
       ),
        GoRoute(
          path: 'details/:postId',
          builder: (context, state) {
            final postId = state.pathParameters['postId']!;
            return PostDetailsPage(postId: postId);
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
          otherUserId: state.pathParameters['otherUserId'] ?? params?['otherUserId'] ?? '',
          otherUserName: params?['otherUserName'] ?? '',
          serviceName: params?['serviceName'] ?? '', // Add this line
        );
      },
    ),
    // Add a route for request-service if it doesn't exist
    GoRoute(
      path: 'request-service',
      builder: (context, state) => const RequestServicePage(),
    ),
    // Add provider-details route
    GoRoute(
      path: 'provider-details/:providerId',
      builder: (context, state) {
        // Debug the parameter value
        final providerId = state.pathParameters['providerId'] ?? '';
        return ProviderProfilePage(providerId: providerId);
      },
    ),
  ],
);

// Add this function at the end of the file
