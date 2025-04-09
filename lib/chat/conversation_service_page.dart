import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../notifications_service.dart';


class ConversationServicePage extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String serviceName; // Add this parameter

  const ConversationServicePage({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    this.serviceName = '', // Make it optional with a default value
  });

  @override
  State<ConversationServicePage> createState() => _ConversationServicePageState();
}

class _ConversationServicePageState extends State<ConversationServicePage> {
  final TextEditingController _messageController = TextEditingController();
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.otherUserName),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('service_conversations')
                  .doc(_getChatId())
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Une erreur est survenue'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data?.docs ?? [];

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index].data() as Map<String, dynamic>;
                    final isMe = message['senderId'] == currentUserId;
                    
                    // Handle null timestamp
                    final timestamp = message['timestamp'] != null 
                        ? (message['timestamp'] as Timestamp).toDate()
                        : DateTime.now();

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 4.0,
                      ),
                      child: Row(
                        mainAxisAlignment: isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        children: [
                          Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.7,
                            ),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isMe ? Colors.blue : Colors.grey[300],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  message['text'],
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  DateFormat('HH:mm').format(timestamp),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isMe
                                        ? Colors.white.withOpacity(0.7)
                                        : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Écrivez votre message...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getChatId() {
    final List<String> ids = [currentUserId!, widget.otherUserId];
    ids.sort();
    return ids.join('_');
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    _messageController.clear();
    final timestamp = FieldValue.serverTimestamp();

    try {
      final chatId = _getChatId();
      
      // Add message to the conversation
      await FirebaseFirestore.instance
          .collection('service_conversations')
          .doc(chatId)
          .collection('messages')
          .add({
        'text': messageText,
        'senderId': currentUserId,
        'timestamp': timestamp,
      });

      // Update conversation metadata
      await FirebaseFirestore.instance
          .collection('service_conversations')
          .doc(chatId)
          .set({
        'participants': [currentUserId!, widget.otherUserId],
        'lastMessage': messageText,
        'lastMessageTime': timestamp,
        'lastMessageSenderId': currentUserId,
        'unreadCount': {
          widget.otherUserId: FieldValue.increment(1),
        },
      }, SetOptions(merge: true));


    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }
}