import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'accueil_client.dart';
import 'services/liste_prestataires.dart';
import 'marketplace/accueil_marketplace.dart';
import 'marketplace/ajouter_publication.dart';
import 'marketplace/liste_publications.dart';
import 'marketplace/favoris.dart';
import 'marketplace/details_publication.dart';
import 'marketplace/modifier_publication.dart';
import '../profile_edit_page.dart';
import 'page_notifications.dart';
import '../chat/liste_conversations.dart';
import '../chat/conversation_marketplace.dart';
import 'services/provider_profile_page.dart';
import 'services/all_services_page.dart';
import 'chatbot_page.dart';
import 'services/reservation_page.dart';
import 'services/client_reservations_page.dart';
import 'services/favorite_providers_page.dart';
import 'services/reservation_details_page.dart';
import 'services/reclamation_form_page.dart';
import 'services/client_reclamations_page.dart';
import 'services/client_reclamation_details_page.dart';
import '../front/changer_mot_de_passe_page.dart'; // Added import


final clientRoutes = GoRoute(
  path: '/clientHome',
  builder: (context, state) => const ClientHomePage(),
  routes: [
    // Add the all-services route
    GoRoute(
      path: 'all-services',
      builder: (context, state) => const AllServicesPage(),
    ),
    
    // Add route for client reservations
    GoRoute(
      path: 'my-reservations',
      builder: (context, state) => const ClientReservationsPage(),
    ),
    
    // Add route for reservation details
    GoRoute(
      path: 'reservation-details/:reservationId',
      builder: (context, state) {
        final reservationId = state.pathParameters['reservationId'] ?? '';
        return ReservationDetailsPage(reservationId: reservationId);
      },
    ),
    
    // Add route for favorite providers
    GoRoute(
      path: 'favorite-providers',
      builder: (context, state) => const FavoriteProvidersPage(),
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
    
    // Add reservation route
    GoRoute(
      path: 'reservation/:providerId',
      builder: (context, state) {
        final providerId = state.pathParameters['providerId'] ?? '';
        final params = state.extra as Map<String, dynamic>?;
        return ReservationPage(
          providerId: providerId,
          providerName: params?['providerName'] ?? '',
          serviceName: params?['serviceName'] ?? '',
        );
      },
    ),
    
    // Add route for client reclamations list
    GoRoute(
      path: 'reclamations',
      builder: (context, state) => const ClientReclamationsPage(),
    ),
    
    // Add route for reclamation details
    GoRoute(
      path: 'reclamations/details/:reclamationId',
      builder: (context, state) {
        final reclamationId = state.pathParameters['reclamationId'] ?? '';
        return ClientReclamationDetailsPage(reclamationId: reclamationId);
      },
    ),
    
    // Add route for creating a new reclamation
    GoRoute(
      path: 'reclamations/create/:reservationId',
      builder: (context, state) {
        final reservationId = state.pathParameters['reservationId'] ?? '';
        return ReclamationFormPage(reservationId: reservationId);
      },
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
               final params = state.extra as Map<String, dynamic>?;
               return ChatScreenPage(
                 otherUserId: state.pathParameters['otherUserId']!,
                 otherUserName: params?['otherUserName'] ?? '',
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
    // Profile and notifications are now properly nested under /clientHome
    GoRoute(
      path: 'profile',
      builder: (context, state) => const ProfileEditPage(),
    ),
    GoRoute(
      path: 'change-password', // New route for changing password
      builder: (context, state) => const ChangerMotDePassePage(),
    ),
    GoRoute(
      path: 'notifications',
      builder: (context, state) => const NotificationsPage(),
    ),

    GoRoute(
      path: 'provider-details/:providerId',
      builder: (context, state) {
        final providerId = state.pathParameters['providerId'] ?? '';
        final serviceName = state.extra as String? ?? '';
        return ProviderProfilePage(
          providerId: providerId,
          serviceName: serviceName,
        );
      },
    ),
  ],
);
