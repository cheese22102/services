import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:collection/collection.dart'; // Pour firstWhereOrNull
import 'package:plateforme_services/notifications_service.dart';
import 'message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final String senderId;
  final String receiverId;
  final String postId;

  const ChatScreen({
    Key? key,
    required this.senderId,
    required this.receiverId,
    required this.postId,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _textFieldFocus = FocusNode();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User _currentUser = FirebaseAuth.instance.currentUser!;

  String? _chatroomId;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isPostDeleted = false;
  bool _isChatArchived = false;
  bool _isTyping = false;
  Timer? _typingTimer;

  String? _partnerName;
  late String _partnerId;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _partnerId = (_currentUser.uid == widget.senderId)
        ? widget.receiverId
        : widget.senderId;
    _chatroomId = _generateChatroomId();
    _fetchPartnerName();
    _initializeChatroom();
    _setupTypingListener();
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
    }
  }

  Future<void> _initializeChatroom() async {
    try {
      final userIds = [widget.senderId, widget.receiverId]..sort();
      final postDoc =
          await _firestore.collection('marketplace').doc(widget.postId).get();
      if (!postDoc.exists) {
        setState(() {
          _isPostDeleted = true;
          _isChatArchived = true;
          _isLoading = false;
        });
        return;
      }
      await _firestore.collection('chats').doc(_chatroomId).set({
        'participants': userIds,
        'postId': widget.postId,
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'reactions': {},
      }, SetOptions(merge: true));
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error initializing chat: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  void _setupTypingListener() {
    _firestore
        .collection('chats')
        .doc(_chatroomId)
        .collection('typing')
        .snapshots()
        .listen((snapshot) {
      if (mounted) {
        final partnerDoc =
            snapshot.docs.firstWhereOrNull((doc) => doc.id == _partnerId);
        setState(() {
          _isTyping =
              (partnerDoc != null && partnerDoc.data()['isTyping'] == true);
        });
      }
    });
  }

  Future<void> _updateTypingStatus(bool isTyping) async {
    try {
      await _firestore
          .collection('chats')
          .doc(_chatroomId)
          .collection('typing')
          .doc(_currentUser.uid)
          .set({'isTyping': isTyping});
    } catch (e) {
      print('Error updating typing status: $e');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty ||
        _isChatArchived ||
        _chatroomId == null) return;
    try {
      await _updateTypingStatus(false);
      final messageText = _messageController.text.trim();
      final timestamp = FieldValue.serverTimestamp();
      final senderId = _currentUser.uid;
      await _firestore
          .collection('chats')
          .doc(_chatroomId)
          .collection('messages')
          .add({
        'text': messageText,
        'senderId': senderId,
        'timestamp': timestamp,
        'reactions': {},
      });
      await _firestore.collection('chats').doc(_chatroomId).update({
        'lastMessage': messageText,
        'lastMessageTime': timestamp,
      });
      final senderDoc =
          await _firestore.collection('users').doc(senderId).get();
      final senderName = senderDoc.data()?['firstname'] ?? 'Un utilisateur';
      await NotificationsService.sendMessageNotification(
        receiverId: _partnerId,
        messageText: messageText,
        senderName: senderName,
        chatroomId: _chatroomId!,
      );
      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
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
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chats')
          .doc(_chatroomId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final messages = snapshot.data?.docs ?? [];
        return ListView.builder(
          controller: _scrollController,
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final data = message.data() as Map<String, dynamic>;
            return MessageBubble(
              messageId: message.id,
              message: data['text'],
              isSender: data['senderId'] == _currentUser.uid,
              chatroomId: _chatroomId!,
              timestamp: data['timestamp']?.toDate(),
              reactions: data['reactions'] is Map
                  ? Map<String, dynamic>.from(data['reactions'])
                  : null,
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_errorMessage != null)
      return Scaffold(
          appBar: AppBar(title: const Text('Error')),
          body: Center(child: Text(_errorMessage!)));
    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<DocumentSnapshot>(
          future:
              _firestore.collection('marketplace').doc(widget.postId).get(),
          builder: (context, snapshot) {
            final postTitle = snapshot.hasData
                ? snapshot.data!['title'] ?? 'Produit'
                : 'Loading...';
            return Text(
              'Chat about: $postTitle',
              style: const TextStyle(color: Colors.white),
            );
          },
        ),
        backgroundColor: Colors.deepPurple,
      ),
      body: Column(
        children: [
          Expanded(child: _buildChatMessages()),
          if (_isTyping)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_partnerName ?? 'Partner'} is typing...',
                  style: const TextStyle(
                    fontStyle: FontStyle.italic,
                    color: Colors.grey,
                  ),
                ),
              ),
            ),
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
                      hintText: _isChatArchived
                          ? 'This conversation is archived'
                          : 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor:
                          _isChatArchived ? Colors.grey[100] : Colors.grey[200],
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.emoji_emotions_outlined),
                        onPressed: () {},
                      ),
                    ),
                    onChanged: (text) {
                      _typingTimer?.cancel();
                      _updateTypingStatus(true);
                      _typingTimer = Timer(const Duration(seconds: 2), () {
                        _updateTypingStatus(false);
                      });
                    },
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor:
                      _isChatArchived ? Colors.grey : Colors.deepPurple,
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
    _typingTimer?.cancel();
    _updateTypingStatus(false);
    _textFieldFocus.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
