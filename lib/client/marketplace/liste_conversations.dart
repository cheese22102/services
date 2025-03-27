import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/bottom_navbar.dart';
import '../../widgets/search_bar.dart';

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
  final int _selectedIndex = 4;
  // Add search query state
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
      return {
        'name': fullName.isEmpty ? 'Utilisateur inconnu' : fullName,
        'avatar': avatarUrl,
      };
    } catch (e) {
      return {'name': 'Erreur de chargement', 'avatar': null};
    }
  }

  Future<String> _getPostTitle(String postId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('marketplace').doc(postId).get();
      return doc.exists ? doc['title'] ?? 'Sans titre' : 'Produit supprimé';
    } catch (e) {
      return 'Erreur de chargement';
    }
  }

  String _formatLastMessageTime(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (messageDate == today) {
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == yesterday) {
      return 'Hier';
    } else if (now.difference(timestamp).inDays < 7) {
      return ['Dim.', 'Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.'][timestamp.weekday - 1];
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/clientHome/marketplace'),
        ),
        title: Row(
          children: [
            const Text('Messages'),
            const SizedBox(width: 8),
            StreamBuilder<int>(
              stream: ChatListScreen.getTotalUnreadCount(),
              builder: (context, snapshot) {
                final unreadCount = snapshot.data ?? 0;
                if (unreadCount == 0) return const SizedBox.shrink();
                
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          CustomSearchBar(
            onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
            hintText: 'Rechercher une conversation...',
          ),
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
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Une erreur est survenue',
                          style: TextStyle(
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final conversations = snapshot.data?.docs ?? [];
                if (conversations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune conversation',
                          style: TextStyle(
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Commencez à discuter avec un vendeur',
                          style: TextStyle(
                            fontSize: 14,
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: conversations.length,
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
                          return const Card(
                            child: ListTile(
                              title: Text('Chargement...'),
                              subtitle: LinearProgressIndicator(),
                            ),
                          );
                        }

                        final userInfo = snapshot.data!['userInfo'] as Map<String, dynamic>;
                        final userName = userInfo['name'];
                        final userAvatar = userInfo['avatar']; // Add this line
                        final postTitle = snapshot.data!['postTitle'];

                        // Add search filtering
                        if (_searchQuery.isNotEmpty &&
                            !userName.toString().toLowerCase().contains(_searchQuery) &&
                            !postTitle.toString().toLowerCase().contains(_searchQuery)) {
                          return const SizedBox.shrink();
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                              backgroundImage: userAvatar != null ? NetworkImage(userAvatar) : null,
                              child: userAvatar == null
                                  ? Icon(
                                      Icons.person,
                                      color: Theme.of(context).colorScheme.primary,
                                    )
                                  : null,
                            ),
                            title: Text(
                              userName,
                              style: TextStyle(
                                fontWeight: currentUserUnreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                                fontSize: 16,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text(
                                  postTitle,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (isLastMessageFromMe)
                                      const Padding(
                                        padding: EdgeInsets.only(right: 4),
                                        child: Icon(
                                          Icons.done_all,
                                          size: 16,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    Expanded(
                                      child: Text(
                                        lastMessage,
                                        style: TextStyle(
                                          color: currentUserUnreadCount > 0 ? Colors.black87 : Colors.grey[600],
                                          fontWeight: currentUserUnreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (currentUserUnreadCount > 0)
                                      Container(
                                        margin: const EdgeInsets.only(left: 4),
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          currentUserUnreadCount.toString(),
                                          style: const TextStyle(color: Colors.white, fontSize: 12),
                                        ),
                                      ),
                                    if (timestamp != null) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatLastMessageTime(timestamp),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            onTap: () => context.go(
                              '/clientHome/marketplace/chat/conversation/$otherUserId',
                              extra: {
                                'otherUserName': userName,
                                'postId': conversation['postId'],
                              },
                            ),
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
      bottomNavigationBar: MarketplaceBottomNav(
        selectedIndex: _selectedIndex,
      ),
    );
  }
}