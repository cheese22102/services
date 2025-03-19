import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'chat_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
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
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              otherUserName,
                              style: TextStyle(
                                fontWeight: currentUserUnreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 4),
                          Text(
                            _formatLastMessageTime(timestamp),
                            style: TextStyle(
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
                              ),
                            ),
                        ],
                      ),
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
}