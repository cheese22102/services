import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatScreen extends StatefulWidget {
  final String senderId;
  final String receiverId;
  final String postId;

  const ChatScreen({
    super.key,
    required this.senderId,
    required this.receiverId,
    required this.postId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late String _chatroomId;
  bool _isLoading = true;
  String? _errorMessage;
  bool _isPostDeleted = false;
  bool _isChatArchived = false;

  @override
  void initState() {
    super.initState();
    _initializeChatroom();
    _markMessagesAsSeen();
  }

  Future<void> _initializeChatroom() async {
    try {
      final postDoc = await _firestore.collection('marketplace').doc(widget.postId).get();
      if (!postDoc.exists) {
        setState(() {
          _isPostDeleted = true;
          _isChatArchived = true;
        });
        return;
      }

      List<String> userIds = [widget.senderId, widget.receiverId];
      userIds.sort();
      _chatroomId = '${userIds[0]}_${userIds[1]}_${widget.postId}';

      await _firestore.collection('chats').doc(_chatroomId).set({
        'participants': userIds,
        'postId': widget.postId,
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _errorMessage = 'Error initializing chat: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.isEmpty || _isChatArchived) return;

    try {
      await _firestore
          .collection('chats')
          .doc(_chatroomId)
          .collection('messages')
          .add({
        'text': _messageController.text,
        'senderId': widget.senderId,
        'postId': widget.postId,
        'status': 'sent',
        'timestamp': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('chats').doc(_chatroomId).update({
        'lastMessage': _messageController.text,
        'lastMessageTime': FieldValue.serverTimestamp(),
      });

      _messageController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: ${e.toString()}')),
      );
    }
  }

  Future<void> _markMessagesAsSeen() async {
    final messages = await _firestore
        .collection('chats')
        .doc(_chatroomId)
        .collection('messages')
        .where('senderId', isEqualTo: widget.receiverId)
        .where('status', whereIn: ['sent', 'delivered'])
        .get();

    for (var doc in messages.docs) {
      await doc.reference.update({'status': 'seen'});
    }
  }

  Widget _buildMessageBubble(DocumentSnapshot message) {
    final isMe = message['senderId'] == FirebaseAuth.instance.currentUser!.uid;
    final timestamp = message['timestamp']?.toDate() ?? DateTime.now();
    final status = message['status'] ?? 'sent';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isMe ? Colors.blueAccent : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isMe ? const Radius.circular(20) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message['text'],
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 8),
                  Icon(
                    _getStatusIcon(status),
                    size: 14,
                    color: isMe ? Colors.white70 : Colors.grey[600],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'seen':
        return Icons.done_all;
      case 'delivered':
        return Icons.done_all;
      default:
        return Icons.done;
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
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final messages = snapshot.data?.docs ?? [];
        if (messages.isEmpty) {
          return Center(
            child: Text(
              _isChatArchived 
                ? 'This conversation is archived'
                : 'Start the conversation!',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }

        return ListView.builder(
          reverse: false,
          itemCount: messages.length,
          itemBuilder: (context, index) => _buildMessageBubble(messages[index]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_errorMessage != null) return Scaffold(appBar: AppBar(title: const Text('Error')), body: Center(child: Text(_errorMessage!)));

    return Scaffold(
      appBar: AppBar(
        title: FutureBuilder<DocumentSnapshot>(
          future: _firestore.collection('marketplace').doc(widget.postId).get(),
          builder: (context, snapshot) {
            final postTitle = snapshot.hasData 
                ? snapshot.data!['title'] ?? 'Deleted Post'
                : 'Loading...';
            return Text(
              'Chat about: $postTitle',
              style: TextStyle(color: Colors.white),
            );
          },
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue, Colors.lightBlueAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
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
                      fillColor: _isChatArchived ? Colors.grey[100] : Colors.grey[200],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.emoji_emotions_outlined,
                            color: Colors.grey[600]),
                        onPressed: () {},
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: _isChatArchived ? Colors.grey : Colors.blue,
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
      floatingActionButton: _isChatArchived 
          ? null
          : FloatingActionButton(
              onPressed: () {},
              mini: true,
              backgroundColor: Colors.blue,
              child: const Icon(Icons.attach_file, color: Colors.white),
            ),
    );
  }
}