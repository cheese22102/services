import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';

<<<<<<< Updated upstream
class ConversationsListPage extends StatefulWidget {
  const ConversationsListPage({Key? key}) : super(key: key);

  @override
  _ConversationsListPageState createState() => _ConversationsListPageState();
}

class _ConversationsListPageState extends State<ConversationsListPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = true;
  Stream<QuerySnapshot>? _conversationsStream;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _initializeConversations();
  }

  Future<void> _initializeConversations() async {
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      // Instead of showing login UI, we'll use a default user ID for testing
      // In production, you'd want to handle authentication properly
      _currentUserId = 'default_user_id';
    } else {
      _currentUserId = currentUser.uid;
    }
    
    // Set up stream for conversations where user is a participant
    _conversationsStream = _firestore
        .collection('conversations')
        .where('participants', arrayContains: _currentUserId)
        .orderBy('lastMessageTimestamp', descending: true)
        .snapshots();

    setState(() {
      _isLoading = false;
    });
  }

  String _formatLastMessageTime(Timestamp? timestamp) {
    if (timestamp == null) return '';
    
    final DateTime dateTime = timestamp.toDate();
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime yesterday = today.subtract(Duration(days: 1));
    final DateTime messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (messageDate == today) {
      // Today, show only time
      return DateFormat('h:mm a').format(dateTime);
    } else if (messageDate == yesterday) {
      // Yesterday
      return 'Yesterday';
    } else if (now.difference(dateTime).inDays < 7) {
      // This week
      return DateFormat('EEEE').format(dateTime); // Day name
    } else {
      // Older
      return DateFormat('MMM d').format(dateTime);
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey[400]),
          SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Your conversations will appear here',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
=======
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});
>>>>>>> Stashed changes

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
  Future<Map<String, dynamic>> _getUserInfo(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (!doc.exists) return {'name': 'Utilisateur inconnu', 'avatar': null};
      final data = doc.data()!;
      final fullName = '${data['firstname']} ${data['lastname']}'.trim();
      // Get the other user's image URL from avatarUrl field
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
<<<<<<< Updated upstream
        title: Text('Messages'),
        elevation: 1,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: _conversationsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading conversations. Please try again.'),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return _buildEmptyState();
                }

                final conversations = snapshot.data!.docs;

                return ListView.separated(
                  itemCount: conversations.length,
                  separatorBuilder: (context, index) => Divider(height: 1, indent: 72),
                  itemBuilder: (context, index) {
                    final conversationData = conversations[index].data() as Map<String, dynamic>;
                    final conversationId = conversations[index].id;
                    
                    // Get the other participant's info
                    final List<dynamic> participants = conversationData['participants'] ?? [];
                    final String otherUserId = participants.firstWhere(
                      (userId) => userId != _currentUserId,
                      orElse: () => '',
                    );
                    
                    if (otherUserId.isEmpty) return SizedBox(); // Skip if there's an issue
                    
                    final Map<String, dynamic> participantsInfo = Map<String, dynamic>.from(conversationData['participantsInfo'] ?? {});
                    final Map<String, dynamic> otherUserInfo = Map<String, dynamic>.from(participantsInfo[otherUserId] ?? {});
                    
                    final String otherUserName = otherUserInfo['name'] ?? 'User';
                    final String lastMessage = conversationData['lastMessage'] ?? '';
                    final String? lastMessageSenderId = conversationData['lastMessageSenderId'];
                    final bool isLastMessageFromMe = lastMessageSenderId == _currentUserId;
                    final Timestamp? timestamp = conversationData['lastMessageTimestamp'];
                    
                    // Get unread count for current user
                    final Map<String, dynamic> unreadCount = Map<String, dynamic>.from(conversationData['unreadCount'] ?? {});
                    final int currentUserUnreadCount = (unreadCount[_currentUserId] ?? 0) as int;
                    
                    // Get post ID if available
                    final String postId = conversationData['postId'] ?? '';
                    
                    return ListTile(
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue[100],
                        radius: 28,
                        child: Text(
                          otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
=======
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
      body: StreamBuilder<QuerySnapshot>(
        // Updated collection name to match Firestore rules
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
            return Center(
              child: CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
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
              final conversation = conversations[index];
              final participants = List<String>.from(conversation['participants']);
              final otherUserId = participants.firstWhere((id) => id != currentUserId);

              return FutureBuilder<Map<String, dynamic>>(
                future: Future.wait([
                  _getUserInfo(otherUserId),
                  _getPostTitle(conversation['postId']),
                  Future.value(true),
                ]).then((results) => {
                      'userInfo': results[0],
                      'postTitle': results[1],
                      'postActive': results[2],
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
                  final userAvatar = userInfo['avatar'];
                  final postTitle = snapshot.data!['postTitle'];
                  final postActive = snapshot.data!['postActive'];
                  final lastMessage = conversation['lastMessage']?.toString() ?? 'Pas encore de messages';
                  final timestamp = conversation['lastMessageTime']?.toDate();

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
                        child: userAvatar == null ? Icon(
                          Icons.person,
                          color: Theme.of(context).colorScheme.primary,
                        ) : null,
>>>>>>> Stashed changes
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
<<<<<<< Updated upstream
                              otherUserName,
                              style: TextStyle(
                                fontWeight: currentUserUnreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 4),
=======
                              userName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          if (!postActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Archivé',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                        ],
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
>>>>>>> Stashed changes
                          Text(
                            _formatLastMessageTime(timestamp),
                            style: TextStyle(
<<<<<<< Updated upstream
                              fontSize: 12,
                              color: currentUserUnreadCount > 0 ? Colors.blue : Colors.grey,
                              fontWeight: currentUserUnreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Row(
                        children: [
                          if (isLastMessageFromMe)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.done_all,
                                size: 16,
                                color: Colors.grey,
                              ),
                            ),
                          Expanded(
                            child: Text(
                              lastMessage.isEmpty ? 'Start a conversation' : lastMessage,
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
                              margin: EdgeInsets.only(left: 4),
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                currentUserUnreadCount.toString(),
                                style: TextStyle(color: Colors.white, fontSize: 12),
=======
                              color: lastMessage == 'Pas encore de messages'
                                  ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
                                  : null,
                            ),
                          ),
                          if (timestamp != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('dd MMM yyyy • HH:mm', 'en_US').format(timestamp),
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
>>>>>>> Stashed changes
                              ),
                            ),
                          ],
                        ],
                      ),
<<<<<<< Updated upstream
                      onTap: () {
                        // Always navigate to ChatScreenPage with the conversation details
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreenPage(
                              otherUserId: otherUserId,
                              postId: postId,
                              otherUserName: otherUserName,
                            ),
=======
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            senderId: currentUserId,
                            receiverId: otherUserId,
                            postId: conversation['postId'],
>>>>>>> Stashed changes
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
<<<<<<< Updated upstream
=======

  // Helper methods remain the same but with translated error messages
  Future<String> _getUserName(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (!doc.exists) return 'Utilisateur inconnu';
      final fullName = '${doc['firstname']} ${doc['lastname']}'.trim();
      return fullName.isEmpty ? 'Utilisateur inconnu' : fullName;
    } catch (e) {
      return 'Erreur de chargement';
    }
  }
>>>>>>> Stashed changes
}