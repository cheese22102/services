import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
<<<<<<< Updated upstream
import 'package:intl/intl.dart';
import 'notifications_service.dart';
=======
import 'package:collection/collection.dart';
import 'package:plateforme_services/chat/notifications_service.dart';
import 'package:intl/intl.dart';
import 'message_bubble.dart';
>>>>>>> Stashed changes

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

<<<<<<< Updated upstream
class _ChatScreenPageState extends State<ChatScreenPage> {
=======
class _ChatScreenState extends State<ChatScreen> {
  // Add back the partnerId variable
  late String _partnerId;
  String? _partnerName;
>>>>>>> Stashed changes
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late Stream<QuerySnapshot> _messagesStream;
  String? _conversationId;
  bool _isLoading = true;
<<<<<<< Updated upstream
  String? _currentUserId;
  String? _currentUserName;
=======
  String? _errorMessage;
  bool _isPostDeleted = false;
  bool _isChatArchived = false;
  // Remove typing-related variables
  final ScrollController _scrollController = ScrollController();
>>>>>>> Stashed changes

  @override
  void initState() {
    super.initState();
<<<<<<< Updated upstream
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    // Get current user
    final User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      // Handle not logged in case
      Navigator.of(context).pop();
      return;
=======
    _partnerId = (_currentUser.uid == widget.senderId)
        ? widget.receiverId
        : widget.senderId;
    _chatroomId = _generateChatroomId();
    _fetchPartnerName();
    _initializeChatroom();
    // Remove _setupTypingListener();
  }

  // Remove _updateTypingStatus and _setupTypingListener methods

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty || _isChatArchived || _chatroomId == null) return;
    try {
      final messageText = _messageController.text.trim();
      final timestamp = FieldValue.serverTimestamp();
      final senderId = _currentUser.uid;
      
      _messageController.clear();

      // Send message
      await _firestore
          .collection('conversations')
          .doc(_chatroomId)
          .collection('messages')
          .add({
            'text': messageText,
            'senderId': senderId,
            'timestamp': timestamp,
            'reactions': {},
          });

      // Update conversation metadata and increment unread counter for recipient
      await _firestore.collection('conversations').doc(_chatroomId).update({
        'lastMessage': messageText,
        'lastMessageTime': timestamp,
        'unreadCount.$_partnerId': FieldValue.increment(1),
      });

      final senderDoc = await _firestore.collection('users').doc(senderId).get();
      final senderName = senderDoc.data()?['firstname'] ?? 'Un utilisateur';
      
      await NotificationsService.sendMessageNotification(
        receiverId: _partnerId,
        messageText: messageText,
        senderName: senderName,
        chatroomId: _chatroomId!,
      );

      // Add a small delay to ensure the message is loaded in the stream
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        _scrollController.animateTo(
          0.0, // Scroll to top since ListView is reversed
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Échec de l\'envoi du message: $e')),
      );
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Widget _buildChatMessages() {
    if (_chatroomId == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _firestore.collection('conversations').doc(_chatroomId).snapshots(),
      builder: (context, conversationSnapshot) {
        if (conversationSnapshot.hasError) {
          return Center(child: Text('Error: ${conversationSnapshot.error}'));
        }

        if (!conversationSnapshot.hasData) {
          return const SizedBox.shrink();
        }

        if (!conversationSnapshot.data!.exists) {
          return const Center(child: Text('No conversation found'));
        }

        final conversationData = conversationSnapshot.data!.data() as Map<String, dynamic>;
        final participants = List<String>.from(conversationData['participants'] ?? []);

        if (!participants.contains(_currentUser.uid)) {
          return const Center(child: Text('Access denied'));
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('conversations')
              .doc(_chatroomId)
              .collection('messages')
              .orderBy('timestamp', descending: true)
              .limit(50)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            // Remove loading indicator for subsequent updates
            if (!snapshot.hasData && _isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final messages = snapshot.data?.docs ?? [];
            if (messages.isEmpty) {
              return const Center(child: Text('No messages yet'));
            }

            return ListView.builder(
              reverse: true,
              controller: _scrollController,
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                final data = message.data() as Map<String, dynamic>;
                final isLastMessage = index == 0;
                // Fix the type comparison here
                final showAvatar = data['senderId'] != _currentUser.uid && isLastMessage;
                
                // Check if next message is from same sender (for grouping)
                final nextMessage = index < messages.length - 1 ? messages[index + 1] : null;
                final isNextSameSender = nextMessage != null && 
                    (nextMessage.data() as Map<String, dynamic>)['senderId'] == data['senderId'];

                return MessageBubble(
                  messageId: message.id,
                  message: data['text'],
                  isSender: data['senderId'] == _currentUser.uid,
                  chatroomId: _chatroomId!,
                  timestamp: data['timestamp']?.toDate(),
                  reactions: data['reactions'] is Map ? Map<String, dynamic>.from(data['reactions']) : null,
                  showAvatar: showAvatar,
                  isGrouped: isNextSameSender,
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text(_errorMessage!)),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<DocumentSnapshot>(
          future: _firestore.collection('marketplace').doc(widget.postId).get(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text('Error loading post');
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return const Text('Chat');
            }
            final postData = snapshot.data!.data() as Map<String, dynamic>;
            final postTitle = postData['title'] ?? 'Chat';
            return Text(
              'Chat: $postTitle',
              style: const TextStyle(color: Colors.white),
              overflow: TextOverflow.ellipsis,
            );
          },
        ),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          Expanded(child: _buildChatMessages()),
          // Remove typing indicator widget
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    focusNode: _textFieldFocus,
                    controller: _messageController,
                    enabled: !_isChatArchived,
                    decoration: InputDecoration(
                      hintText: _isChatArchived ? 'This conversation is archived' : 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: _isChatArchived ? Colors.grey[100] : Colors.grey[200],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.emoji_emotions_outlined),
                        onPressed: () {},
                      ),
                    ),
                    // Remove onChanged typing handler
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: _isChatArchived ? Colors.grey : Colors.deepPurple,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white),
                    onPressed: _isChatArchived ? null : _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Remove typing timer cancel
    _textFieldFocus.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _generateChatroomId() {
    final userIds = [widget.senderId, widget.receiverId]..sort();
    return '${userIds[0]}_${userIds[1]}_${widget.postId}';
  }

  Future<void> _fetchPartnerName() async {
    try {
      final doc = await _firestore.collection('users').doc(_partnerId).get();
      if (doc.exists) {
        final data = doc.data()!;
        String name = '';
        if (data['firstname'] != null && data['lastname'] != null) {
          name = '${data['firstname']} ${data['lastname']}';
        }
        setState(() {
          _partnerName = name.isEmpty ? 'Partner' : name;
        });
      } else {
        setState(() {
          _partnerName = 'Partner';
        });
      }
    } catch (e) {
      setState(() {
        _partnerName = 'Partner';
      });
>>>>>>> Stashed changes
    }

    _currentUserId = currentUser.uid;
    _currentUserName = currentUser.displayName ?? 'User';

    try {
<<<<<<< Updated upstream
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
=======
      final userIds = [widget.senderId, widget.receiverId]..sort();
      _chatroomId = '${userIds[0]}_${userIds[1]}_${widget.postId}';
      
      final chatRef = _firestore.collection('conversations').doc(_chatroomId);
      
      await chatRef.set({
        'participants': [widget.senderId, widget.receiverId],
        'postId': widget.postId,
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': _currentUser.uid,
        'unreadCount': {
          widget.senderId: 0,
          widget.receiverId: 0,
        },
      }, SetOptions(merge: true));

      // Reset unread count for current user when opening chat
      await chatRef.update({
        'unreadCount.${_currentUser.uid}': 0,
      });

      // First, try to create the conversation if it doesn't exist
      await chatRef.set({
        'participants': [widget.senderId, widget.receiverId],
        'postId': widget.postId,
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': _currentUser.uid,
      }, SetOptions(merge: true)); // Use merge to avoid overwriting existing data

      // Then verify access
      final chatDoc = await chatRef.get();
      if (!chatDoc.exists) {
        throw Exception('Failed to initialize chat');
      }

      final data = chatDoc.data()!;
      final participants = List<String>.from(data['participants'] ?? []);
      if (!participants.contains(_currentUser.uid)) {
        throw Exception('Access denied');
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _errorMessage = 'Chat initialization error: $e';
        _isLoading = false;
      });
    }
  }

>>>>>>> Stashed changes
}