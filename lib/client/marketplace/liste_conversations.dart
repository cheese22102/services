import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../front/app_colors.dart';
import '../../front/custom_app_bar.dart';
import '../../front/custom_bottom_nav.dart';
import '../../front/marketplace_search.dart';
import '../../front/conversation_card.dart';
import '../../front/sidebar.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  static Stream<int> getTotalUnreadCount() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(0);

    return FirebaseFirestore.instance
        .collection('conversations')
        .where('participants', arrayContains: user.uid)
        .snapshots()
        .map((snapshot) {
      int totalUnread = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final lastReadTime = (data['lastRead'] ?? {})[user.uid] ?? Timestamp(0, 0);
        final lastMessageTime = data['lastMessageTime'] ?? Timestamp(0, 0);

        if (lastMessageTime.compareTo(lastReadTime) > 0) {
          totalUnread++;
        }
      }
      return totalUnread;
    });
  }

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final int _selectedIndex = 3;
  String _searchQuery = '';

  Future<Map<String, dynamic>> _getUserInfo(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (!doc.exists) return {'name': 'Utilisateur inconnu', 'avatar': null};
      final data = doc.data()!;
      final fullName = '${data['firstname']} ${data['lastname']}'.trim();
      final avatarUrl = data['avatarUrl'] != null && data['avatarUrl'].toString().isNotEmpty 
          ? data['avatarUrl'].toString()
          : null;
      return {'name': fullName.isNotEmpty ? fullName : 'Utilisateur', 'avatar': avatarUrl};
    } catch (_) {
      return {'name': 'Utilisateur inconnu', 'avatar': null};
    }
  }

  Future<String> _getPostTitle(String postId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('marketplace').doc(postId).get();
      if (!doc.exists) return 'Annonce supprimée';
      final data = doc.data()!;
      return data['title'] ?? 'Annonce';
    } catch (_) {
      return 'Annonce supprimée';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async {
        // Navigate to home page when back button is pressed
        context.go('/clientHome');
        return false;
      },
      child: Scaffold(
        backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
        drawer: const Sidebar(), // Add the Sidebar widget as the drawer
        appBar: CustomAppBar(
          title: 'Messages',
          showBackButton: false,
          showSidebar: true,
          showNotifications: true,
          currentIndex: _selectedIndex, // Pass the current index
          backgroundColor: isDarkMode ? Colors.grey.shade900 : Colors.white,
        ),
        body: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: MarketplaceSearch(
                controller: TextEditingController(text: _searchQuery),
                hintText: 'Rechercher une conversation...',
                onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                onClear: () => setState(() => _searchQuery = ''),
              ),
            ),
            // Rest of the body content
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('conversations')
                    .where('participants', arrayContains: currentUserId)
                    .orderBy('lastMessageTime', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: isDarkMode ? Colors.redAccent : Colors.red),
                          const SizedBox(height: 16),
                          Text(
                            'Une erreur est survenue',
                            style: GoogleFonts.poppins(fontSize: 18, color: isDarkMode ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Impossible de charger les conversations.',
                            style: GoogleFonts.poppins(fontSize: 14, color: isDarkMode ? Colors.white54 : Colors.black45),
                          ),
                        ],
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final conversations = snapshot.data?.docs ?? [];
                  if (conversations.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.chat_bubble_outline, size: 64, color: isDarkMode ? Colors.white54 : Colors.black38),
                          const SizedBox(height: 16),
                          Text(
                            'Aucune conversation',
                            style: GoogleFonts.poppins(fontSize: 18, color: isDarkMode ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Commencez à discuter avec un vendeur',
                            style: GoogleFonts.poppins(fontSize: 14, color: isDarkMode ? Colors.white54 : Colors.black45),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: conversations.length,
                    separatorBuilder: (context, index) => Divider(
                      color: isDarkMode ? Colors.white12 : Colors.black12,
                      height: 24,
                    ),
                    itemBuilder: (context, index) {
                      final conversation = conversations[index].data() as Map<String, dynamic>;
                      final participants = List<String>.from(conversation['participants']);
                      final otherUserId = participants.firstWhere((id) => id != currentUserId);
                      final lastMessage = conversation['lastMessage']?.toString() ?? 'Pas encore de messages';
                      final timestamp = conversation['lastMessageTime']?.toDate();
                      final isLastMessageFromMe = conversation['lastMessageSenderId'] == currentUserId;
                      final currentUserUnreadCount = (conversation['unreadCount'] ?? {})[currentUserId] ?? 0;

                      return FutureBuilder<Map<String, dynamic>>(
                        future: Future.wait([
                          _getUserInfo(otherUserId),
                          _getPostTitle(conversation['postId']),
                        ]).then((results) => {
                          'userInfo': results[0],
                          'postTitle': results[1],
                        }),
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return Card(
                              color: isDarkMode ? AppColors.darkInputBackground : AppColors.lightInputBackground,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              child: const ListTile(
                                title: Text('Chargement...'),
                                subtitle: LinearProgressIndicator(),
                              ),
                            );
                          }

                          final userInfo = snapshot.data!['userInfo'] as Map<String, dynamic>;
                          final userName = userInfo['name'];
                          final userAvatar = userInfo['avatar'];
                          final postTitle = snapshot.data!['postTitle'];

                          // Search filtering
                          if (_searchQuery.isNotEmpty &&
                              !userName.toString().toLowerCase().contains(_searchQuery) &&
                              !postTitle.toString().toLowerCase().contains(_searchQuery)) {
                            return const SizedBox.shrink();
                          }

                          // Inside your itemBuilder, replace the old Material+Card+Stack code with:
                          return ConversationCard(
                            isDarkMode: isDarkMode,
                            userName: userName,
                            userAvatar: userAvatar,
                            postTitle: postTitle,
                            lastMessage: lastMessage,
                            timestamp: timestamp,
                            isLastMessageFromMe: isLastMessageFromMe,
                            currentUserUnreadCount: currentUserUnreadCount,
                            onTap: () => context.go(
                              '/clientHome/marketplace/chat/conversation/$otherUserId',
                              extra: {
                                'otherUserName': userName,
                                'postId': conversation['postId'],
                              },
                            ),
                          );
                        },
                      );
                    },
                );
              },
            ),
          ),
        ],
      ),
       bottomNavigationBar: CustomBottomNav(
          currentIndex: _selectedIndex,
        ),
    ),
    );
  }
}