import 'package:go_router/go_router.dart';
import 'prestataire_home_page.dart';
import 'provider_chat_list.dart';
import 'provider_notifications_page.dart';
import 'provider_registration.dart';
import 'service_requests_page.dart';
import '../chat/conversation_service_page.dart';

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
      path: 'requests',
      builder: (context, state) => const ServiceRequestsPage(),
    ),
    GoRoute(
      path: 'chat',
      builder: (context, state) => const ProviderChatListScreen(),
      routes: [
        GoRoute(
          path: 'conversation/:otherUserId',
          builder: (context, state) {
            final params = state.extra as Map<String, dynamic>?;
            return ConversationServicePage(
              otherUserId: state.pathParameters['otherUserId']!,
              otherUserName: params?['otherUserName'] ?? '',
            );
          },
        ),
      ],
    ),
  ],
);