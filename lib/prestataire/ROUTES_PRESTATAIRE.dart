import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'prestataire_home_page.dart';
import 'provider_notifications_page.dart';
import 'provider_registration.dart';
import '../profile_edit_page.dart';
import 'provider_reservations_page.dart';
import 'reservation_details_page.dart';
import 'reservation_completion_page.dart';
import '../chat/conversation_marketplace.dart';
import '../chat/provider_list_conversations.dart';

final prestataireRoutes = GoRoute(
  path: '/prestataireHome',
  builder: (context, state) => const PrestataireHomePage(),
  routes: [
    GoRoute(
      path: 'registration',
      builder: (context, state) => const ProviderRegistrationForm(),
    ),
    GoRoute(
      path: 'notifications',
      builder: (context, state) => const ProviderNotificationsPage(),
    ),
    GoRoute(
      path: 'profile',
      builder: (context, state) => const ProfileEditPage(),
    ),
    

    GoRoute(
      path: 'reservations',
      builder: (BuildContext context, GoRouterState state) {
        return const ProviderReservationsPage();
      },
    ),
    GoRoute(
      path: 'reservation-details/:reservationId',
      builder: (BuildContext context, GoRouterState state) {
        final reservationId = state.pathParameters['reservationId'] ?? '';
        return ReservationDetailsPage(reservationId: reservationId);
      },
    ),
    
    GoRoute(
      path: 'reservation-completion/:reservationId',
      builder: (BuildContext context, GoRouterState state) {
        final reservationId = state.pathParameters['reservationId'] ?? '';
        return ReservationCompletionPage(reservationId: reservationId);
      },
    ),

    // Updated chat routes
    GoRoute(
      path: 'chat',
      builder: (context, state) => const ProviderChatListScreen(),
      routes: [
        // Route for conversation with a specific user
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
        // Route for existing chat by chatId
        GoRoute(
          path: ':chatId',
          builder: (context, state) {
            final chatId = state.pathParameters['chatId']!;
            return ChatScreenPage(chatId: chatId);
          },
        ),
      ],
    ),

    // Add profile edit route
    GoRoute(
      path: 'editProfile',
      builder: (context, state) {
        final params = state.extra as Map<String, dynamic>;
        return ProfileEditPage(
          providerId: params['providerId'],
          providerData: params['providerData'],
          userData: params['userData'],
        );
      },
    ),
  ],
);