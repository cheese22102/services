import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../widgets/search_bar.dart';

class ProviderChatListScreen extends StatefulWidget {
  const ProviderChatListScreen({super.key});

  static Stream<int> getTotalUnreadCount() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(0);

    return FirebaseFirestore.instance
        .collection('service_conversations')
        .where('participants', arrayContains: user.uid)
        .snapshots()
        .map((snapshot) {
      int totalUnread = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final unreadCount = (data['unreadCount'] ?? {})[user.uid] ?? 0;
        totalUnread += unreadCount as int;
      }
      return totalUnread;
    });
  }

  @override
  State<ProviderChatListScreen> createState() => _ProviderChatListScreenState();
}

class _ProviderChatListScreenState extends State<ProviderChatListScreen> {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  String _searchQuery = '';

  Future<Map<String, dynamic>> _getUserInfo(String userId) async {
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .get();
    final userData = userDoc.data() ?? {};
    return {
      'name': '${userData['firstname'] ?? ''} ${userData['lastname'] ?? ''}',
      'avatar': userData['avatarUrl'],
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
      ),
      body: Column(
        children: [
          CustomSearchBar(
            onChanged: (value) => setState(() => _searchQuery = value),
            hintText: 'Rechercher une conversation...',
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('service_conversations')
                  .where('participants', arrayContains: currentUserId)
                  .orderBy('lastMessageTime', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final conversations = snapshot.data?.docs ?? [];

                if (conversations.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Aucune conversation',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: conversations.length,
                  itemBuilder: (context, index) {
                    final conversation = conversations[index].data() as Map<String, dynamic>;
                    final participants = List<String>.from(conversation['participants']);
                    final otherUserId = participants.firstWhere((id) => id != currentUserId);
                    final lastMessage = conversation['lastMessage'] ?? 'Pas de message';
                    final timestamp = conversation['lastMessageTime']?.toDate();
                    final unreadCount = (conversation['unreadCount'] ?? {})[currentUserId] ?? 0;

                    return FutureBuilder<Map<String, dynamic>>(
                      future: _getUserInfo(otherUserId),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Card(
                            child: ListTile(
                              title: Text('Chargement...'),
                              subtitle: LinearProgressIndicator(),
                            ),
                          );
                        }

                        final userInfo = snapshot.data!;
                        final userName = userInfo['name'];

                        if (_searchQuery.isNotEmpty &&
                            !userName.toString().toLowerCase().contains(_searchQuery.toLowerCase())) {
                          return const SizedBox.shrink();
                        }

                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundImage: userInfo['avatar'] != null
                                  ? NetworkImage(userInfo['avatar'])
                                  : null,
                              child: userInfo['avatar'] == null
                                  ? Text(userName[0].toUpperCase())
                                  : null,
                            ),
                            title: Text(userName),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lastMessage,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (timestamp != null)
                                  Text(
                                    DateFormat('dd/MM/yyyy HH:mm').format(timestamp),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withOpacity(0.5),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: unreadCount > 0
                                ? Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      unreadCount.toString(),
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  )
                                : null,
                            // In the conversation list item onTap
                            onTap: () {
                              context.go('/prestataireHome/chat/conversation/$otherUserId', 
                                extra: {'otherUserName': userName}
                              );
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
    );
  }
}