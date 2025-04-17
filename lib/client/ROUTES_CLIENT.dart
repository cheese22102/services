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
    GoRoute(
      path: 'provider/:providerId',
      builder: (context, state) {
        final providerId = state.pathParameters['providerId']!;
        final extra = state.extra as Map<String, dynamic>?;
        
        // If we have extra data, use it directly
        if (extra != null && 
            extra.containsKey('providerData') && 
            extra.containsKey('userData')) {
          return ProviderProfilePage(
            providerId: providerId,
            providerData: extra['providerData'],
            userData: extra['userData'],
            serviceName: extra['serviceName'] ?? '',
          );
        }
        
        // Otherwise, fetch the data
        return FutureBuilder<Map<String, dynamic>>(
          future: _fetchProviderData(providerId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            
            if (snapshot.hasError || !snapshot.hasData) {
              return Scaffold(
                appBar: AppBar(title: const Text('Erreur')),
                body: Center(child: Text('Erreur: ${snapshot.error ?? "Données non disponibles"}')),
              );
            }
            
            final data = snapshot.data!;
            return ProviderProfilePage(
              providerId: providerId,
              providerData: data['providerData'],
              userData: data['userData'],
              serviceName: data['serviceName'] ?? '',
            );
          },
        );
      },
    ),
  ],
);

// Add this function at the end of the file
Future<Map<String, dynamic>> _fetchProviderData(String providerId) async {
  // First, try to get provider data from provider_requests collection
  final providerDoc = await FirebaseFirestore.instance
      .collection('provider_requests')
      .where('userId', isEqualTo: providerId)
      .limit(1)
      .get();
  
  Map<String, dynamic> providerData;
  
  // If not found in provider_requests, try the providers collection
  if (providerDoc.docs.isEmpty) {
    final directProviderDoc = await FirebaseFirestore.instance
        .collection('providers')
        .doc(providerId)
        .get();
    
    if (!directProviderDoc.exists) {
      throw Exception('Provider not found');
    }
    
    providerData = directProviderDoc.data() ?? {};
  } else {
    providerData = providerDoc.docs.first.data();
  }
  
  // Get user data
  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(providerId)
      .get();
  
  if (!userDoc.exists) {
    throw Exception('User not found');
  }
  
  final userData = userDoc.data() ?? {};
  
  // Determine service name if possible
  String serviceName = '';
  if (providerData.containsKey('services') && 
      providerData['services'] is List && 
      (providerData['services'] as List).isNotEmpty) {
    serviceName = (providerData['services'] as List).first.toString();
  }
  
  return {
    'providerData': providerData,
    'userData': userData,
    'serviceName': serviceName,
  };
}