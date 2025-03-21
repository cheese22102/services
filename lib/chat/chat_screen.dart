import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'notifications_service.dart';
import 'package:collection/collection.dart';
import 'message_bubble.dart';

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
  final currentUser = FirebaseAuth.instance.currentUser;
  final ScrollController _scrollController = ScrollController();
  final FocusNode _textFieldFocus = FocusNode();
  
  String? _chatroomId;
  String? _currentUserId;
  String? _currentUserName;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isPostDeleted = false;
  bool _isChatArchived = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    if (currentUser == null) {
      setState(() {
        _errorMessage = 'Not authenticated';
        _isLoading = false;
      });
      return;
    }

    _currentUserId = currentUser!.uid;
    _currentUserName = currentUser!.displayName ?? 'User';
    _chatroomId = _generateChatroomId();

    try {
      await _findOrCreateConversation();
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize chat: $e';
        _isLoading = false;
      });
    }
  }

  String _generateChatroomId() {
    final userIds = [_currentUserId, widget.otherUserId]..sort();
    return '${userIds[0]}_${userIds[1]}_${widget.postId}';
  }

  Future<void> _findOrCreateConversation() async {
    if (_currentUserId == null || _chatroomId == null) return;

    final chatRef = _firestore.collection('conversations').doc(_chatroomId);
    final chatDoc = await chatRef.get();

    if (!chatDoc.exists) {
      await chatRef.set({
        'participants': [_currentUserId, widget.otherUserId],
        'postId': widget.postId,
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': _currentUserId,
        'unreadCount': {
          _currentUserId!: 0,
          widget.otherUserId: 0,
        },
      });
    }

    // Reset unread count for current user
    await chatRef.update({
      'unreadCount.$_currentUserId': 0,
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty || _isChatArchived || _chatroomId == null) return;
    
    try {
      final messageText = _messageController.text.trim();
      final timestamp = FieldValue.serverTimestamp();
      
      _messageController.clear();

      await _firestore
          .collection('conversations')
          .doc(_chatroomId)
          .collection('messages')
          .add({
            'text': messageText,
            'senderId': _currentUserId,
            'timestamp': timestamp,
            'reactions': {},
          });

      await _firestore.collection('conversations').doc(_chatroomId).update({
        'lastMessage': messageText,
        'lastMessageTime': timestamp,
        'lastMessageSenderId': _currentUserId,
        'unreadCount.${widget.otherUserId}': FieldValue.increment(1),
      });

      await NotificationsService.sendMessageNotification(
        receiverId: widget.otherUserId,
        messageText: messageText,
        senderName: _currentUserName ?? 'User',
        chatroomId: _chatroomId!,
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
          SnackBar(content: Text('Failed to send message: $e')),
        );
      }
    }
  }

  Widget _buildChatMessages() {
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
            final showAvatar = data['senderId'] != _currentUserId && isLastMessage;
            
            final nextMessage = index < messages.length - 1 ? messages[index + 1] : null;
            final isNextSameSender = nextMessage != null && 
                (nextMessage.data() as Map<String, dynamic>)['senderId'] == data['senderId'];

            return MessageBubble(
              messageId: message.id,
              message: data['text'],
              isSender: data['senderId'] == _currentUserId,
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
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text(_errorMessage!)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUserName),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Column(
        children: [
          Expanded(child: _buildChatMessages()),
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