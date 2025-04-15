import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:plateforme_services/notifications_service.dart';
import '../../widgets/message_bubble.dart';

class ChatScreenPage extends StatefulWidget {
  final String otherUserId; // ID of the other user (post owner or message sender)
  final String postId; // ID of the post
  final String otherUserName; // Name of the other user for display
  final String? chatId; // Optional chat ID for direct access

  const ChatScreenPage({
    super.key,
    this.otherUserId = '',
    this.postId = '',
    this.otherUserName = '',
    this.chatId,
  });

  @override
  State<ChatScreenPage> createState() => _ChatScreenPageState();
}

class _ChatScreenPageState extends State<ChatScreenPage> {
  late final User _currentUser;
  late String _chatroomId;
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FocusNode _textFieldFocus = FocusNode();
  bool _isLoading = true;
  String? _errorMessage;
  final bool _isChatArchived = false;
  final ScrollController _scrollController = ScrollController();
  String _otherUserId = '';
  String _postId = '';

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser!;
    
    if (widget.chatId != null && widget.chatId!.isNotEmpty) {
      // If chatId is provided, use it directly and fetch other details
      _chatroomId = widget.chatId!;
      _fetchChatDetails();
    } else {
      // Otherwise use the provided user and post IDs
      _otherUserId = widget.otherUserId;
      _postId = widget.postId;
      _initializeChat();
    }
  }

  Future<void> _fetchChatDetails() async {
    try {
      final chatDoc = await _firestore.collection('conversations').doc(_chatroomId).get();
      
      if (!chatDoc.exists) {
        setState(() {
          _errorMessage = 'Conversation introuvable';
          _isLoading = false;
        });
        return;
      }
      
      final chatData = chatDoc.data() as Map<String, dynamic>;
      final participants = List<String>.from(chatData['participants'] ?? []);
      
      // Determine the other user ID
      _otherUserId = participants.firstWhere(
        (id) => id != _currentUser.uid,
        orElse: () => '',
      );
      
      // Get post ID
      _postId = chatData['postId'] ?? '';
      
      // Mark messages as read for current user
      await _firestore.collection('conversations').doc(_chatroomId).update({
        'unreadCount.${_currentUser.uid}': 0,
      });
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _initializeChat() async {
    try {
      final userIds = [_currentUser.uid, _otherUserId]..sort();
      _chatroomId = '${userIds[0]}_${userIds[1]}_$_postId';
      
      // Make sure we're using 'conversations' collection
      final chatRef = _firestore.collection('conversations').doc(_chatroomId);
      
      // Initialize or update chat
      await chatRef.set({
        'participants': [_currentUser.uid, _otherUserId],
        'postId': _postId,
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': _currentUser.uid,
        'unreadCount': {
          _currentUser.uid: 0,
          _otherUserId: 0,
        },
      }, SetOptions(merge: true));

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _errorMessage = 'Chat initialization error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty || _isChatArchived) return;
    try {
      final messageText = _messageController.text.trim();
      final timestamp = FieldValue.serverTimestamp();
      
      _messageController.clear();

      // Make sure we're using 'conversations' collection
      await _firestore
          .collection('conversations')
          .doc(_chatroomId)
          .collection('messages')
          .add({
            'text': messageText,
            'senderId': _currentUser.uid,
            'timestamp': timestamp,
            'reactions': {},
          });

      // Update conversation metadata
      await _firestore.collection('conversations').doc(_chatroomId).update({
        'lastMessage': messageText,
        'lastMessageTime': timestamp,
        'unreadCount.${widget.otherUserId}': FieldValue.increment(1),
      });

      // Send notification
      await NotificationsService.sendMessageNotification(
        receiverId: widget.otherUserId,
        messageText: messageText,
        senderName: _currentUser.displayName ?? 'Un utilisateur',
        chatroomId: _chatroomId,
      );

      if (mounted) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec de l\'envoi du message: $e')),
        );
      }
    }
  }


  Widget _buildChatMessages() {
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
                  chatroomId: _chatroomId,
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
          // Use _postId instead of widget.postId since we set it in initState
          future: _postId.isNotEmpty 
              ? _firestore.collection('marketplace').doc(_postId).get()
              : null,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Text('Chargement...');
            }
            
            if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
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
    _textFieldFocus.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
