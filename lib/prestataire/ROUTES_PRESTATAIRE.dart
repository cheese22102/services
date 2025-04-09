import 'package:go_router/go_router.dart';
import 'prestataire_home_page.dart';
import 'provider_chat_list.dart';
import 'provider_notifications_page.dart';
import 'provider_registration.dart';
import 'service_requests_page.dart';
import '../chat/conversation_service_page.dart';
import '../profile_edit_page.dart';  // Import the profile edit page
import '../client/provider_profile_page.dart';  // Import the provider profile page

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
      path: 'profile',
      builder: (context, state) => const ProfileEditPage(),  // Add profile edit route
    ),
    // Add provider profile view route
    GoRoute(
      path: 'providerProfile',
      builder: (context, state) {
        final params = state.extra as Map<String, dynamic>;
        return ProviderProfilePage(
          providerId: params['providerId'],
          providerData: params['providerData'],
          userData: params['userData'],
          serviceName: params['serviceName'],
          isOwnProfile: params['isOwnProfile'] ?? false,
        );
      },
    ),
    GoRoute(
      path: 'messages',  // Changed from 'chat' to 'messages' to match the sidebar navigation
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