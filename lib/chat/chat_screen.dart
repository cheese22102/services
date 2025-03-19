import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'notifications_service.dart';

class ChatScreenPage extends StatefulWidget {
  final String otherUserId; // ID of the other user (post owner or message sender)
  final String postId; // ID of the post
  final String otherUserName; // Name of the other user for display

  const ChatScreenPage({
    Key? key,
    required this.otherUserId,
    required this.postId,
    required this.otherUserName,
  }) : super(key: key);

  @override
  _ChatScreenPageState createState() => _ChatScreenPageState();
}

class _ChatScreenPageState extends State<ChatScreenPage> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Stream<QuerySnapshot> _messagesStream;
  String? _conversationId;
  bool _isLoading = true;
  String? _currentUserId;
  String? _currentUserName;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    // Get current user
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      // Handle not logged in case
      Navigator.of(context).pop();
      return;
    }

    _currentUserId = currentUser.uid;
    _currentUserName = currentUser.displayName ?? 'User';

    try {
      // Find existing conversation or create new one
      await _findOrCreateConversation();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error initializing chat: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading chat. Please try again.')),
      );
    }
  }

  Future<void> _findOrCreateConversation() async {
    if (_currentUserId == null) return;
    
    // Create a sorted pair of user IDs to ensure consistent querying
    List<String> sortedUserIds = [_currentUserId!, widget.otherUserId]..sort();
    
    // Query for a conversation that matches both the users AND the specific post
    final QuerySnapshot conversationsQuery = await _firestore
        .collection('conversations')
        .where('sortedParticipants', isEqualTo: sortedUserIds)
        .where('postId', isEqualTo: widget.postId)
        .limit(1)
        .get();
    
    if (conversationsQuery.docs.isNotEmpty) {
      // Found existing conversation
      _conversationId = conversationsQuery.docs.first.id;
      _setupMessagesStream();
      
      // Mark unread messages as read if the current user is the recipient
      _markMessagesAsRead();
      return;
    }

    // No existing conversation found, create a new one
    await _createNewConversation(sortedUserIds);
  }

  Future<void> _createNewConversation(List<String> sortedUserIds) async {
    if (_currentUserId == null) return;
    
    final DocumentReference conversationRef = await _firestore.collection('conversations').add({
      'participants': [_currentUserId, widget.otherUserId],
      'sortedParticipants': sortedUserIds, // Store sorted IDs for easier querying
      'participantsInfo': {
        _currentUserId!: {
          'uid': _currentUserId,
          'name': _currentUserName,
        },
        widget.otherUserId: {
          'uid': widget.otherUserId,
          'name': widget.otherUserName,
        }
      },
      'initiatorId': _currentUserId, // Who started the conversation
      'lastMessage': '',
      'lastMessageTimestamp': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'postId': widget.postId,
      'unreadCount': {
        _currentUserId!: 0,
        widget.otherUserId: 0,
      },
    });

    _conversationId = conversationRef.id;
    _setupMessagesStream();
  }

  void _setupMessagesStream() {
    _messagesStream = _firestore
        .collection('conversations')
        .doc(_conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> _markMessagesAsRead() async {
    if (_currentUserId == null || _conversationId == null) return;

    // Get unread messages sent by the other user
    QuerySnapshot unreadMessages = await _firestore
        .collection('conversations')
        .doc(_conversationId)
        .collection('messages')
        .where('senderId', isEqualTo: widget.otherUserId)
        .where('read', isEqualTo: false)
        .get();

    // Update each message
    WriteBatch batch = _firestore.batch();
    for (var doc in unreadMessages.docs) {
      batch.update(doc.reference, {'read': true});
    }
    
    // Reset unread counter for current user
    batch.update(
      _firestore.collection('conversations').doc(_conversationId),
      {'unreadCount.${_currentUserId}': 0}
    );
    
    await batch.commit();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _conversationId == null || _currentUserId == null) return;

    final String messageText = _messageController.text.trim();
    _messageController.clear();

    try {
      // Add message to subcollection
      await _firestore
          .collection('conversations')
          .doc(_conversationId)
          .collection('messages')
          .add({
        'senderId': _currentUserId,
        'content': messageText,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      // Get current unread count for recipient
      DocumentSnapshot convoSnapshot = await _firestore
          .collection('conversations')
          .doc(_conversationId)
          .get();
      
      Map<String, dynamic> data = convoSnapshot.data() as Map<String, dynamic>;
      Map<String, dynamic> unreadCount = Map<String, dynamic>.from(data['unreadCount'] ?? {});
      int currentUnreadCount = (unreadCount[widget.otherUserId] ?? 0) as int;

      // Update conversation with last message and increment unread counter for other user
      await _firestore.collection('conversations').doc(_conversationId).update({
        'lastMessage': messageText,
        'lastMessageSenderId': _currentUserId,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'unreadCount.${widget.otherUserId}': currentUnreadCount + 1,
      });
      
      // Envoyer une notification à l'autre utilisateur
      await NotificationsService.sendMessageNotification(
        receiverId: widget.otherUserId,
        messageText: messageText,
        senderName: _currentUserName ?? 'User',
        chatroomId: _conversationId!,
      );
      
    } catch (e) {
      print('Error sending message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message. Please try again.')),
      );
    }
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '';
    
    final DateTime dateTime = timestamp.toDate();
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    if (messageDate == today) {
      // Today, show only time
      return DateFormat('h:mm a').format(dateTime);
    } else if (messageDate == today.subtract(Duration(days: 1))) {
      // Yesterday
      return 'Yesterday, ${DateFormat('h:mm a').format(dateTime)}';
    } else {
      // Other days
      return DateFormat('MMM d, h:mm a').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherUserName),
            Text(
              'Post #${widget.postId.substring(0, min(widget.postId.length, 8))}...',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        elevation: 1,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Messages list
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _messagesStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                        return Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text('Error loading messages'));
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(child: Text('No messages yet. Say hello!'));
                      }

                      // Mark messages as read whenever new messages appear
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _markMessagesAsRead();
                      });

                      final messages = snapshot.data!.docs;

                      return ListView.builder(
                        reverse: true,
                        padding: EdgeInsets.all(10),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final messageData = messages[index].data() as Map<String, dynamic>;
                          final isMe = messageData['senderId'] == _currentUserId;
                          final timestamp = messageData['timestamp'] as Timestamp?;
                          final isRead = messageData['read'] ?? false;

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: EdgeInsets.symmetric(vertical: 5),
                              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                              decoration: BoxDecoration(
                                color: isMe ? Colors.blue[100] : Colors.grey[200],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    messageData['content'] ?? '',
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  SizedBox(height: 5),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _formatTimestamp(timestamp),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.black54,
                                        ),
                                      ),
                                      if (isMe) SizedBox(width: 5),
                                      if (isMe) Icon(
                                        isRead ? Icons.done_all : Icons.done,
                                        size: 14,
                                        color: isRead ? Colors.blue : Colors.black54,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                
                // Message input
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        offset: Offset(0, -2),
                        blurRadius: 2,
                        color: Colors.black.withOpacity(0.1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(10),
                          ),
                          minLines: 1,
                          maxLines: 5,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.send, color: Colors.blue),
                        onPressed: _sendMessage,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  int min(int a, int b) {
    return a < b ? a : b;
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }
}