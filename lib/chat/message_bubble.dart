import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'reaction_display.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'reaction_manager.dart';

class MessageBubble extends StatelessWidget {
  final String message;
  final bool isSender;
  final String messageId;
  final String chatroomId;
  final Map<String, dynamic>? reactions;
  final DateTime? timestamp;

  const MessageBubble({
    Key? key,
    required this.message,
    required this.isSender,
    required this.messageId,
    required this.chatroomId,
    this.reactions,
    this.timestamp,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          isSender ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: () {
            _toggleReaction(context);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: BoxDecoration(
              color: isSender ? Colors.blueAccent : Colors.grey[200],
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    color: isSender ? Colors.white : Colors.black,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('HH:mm').format(timestamp ?? DateTime.now()),
                      style: TextStyle(
                        color: isSender ? Colors.white70 : Colors.grey,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (reactions != null &&
            reactions!['❤️'] != null &&
            (reactions!['❤️'] as List).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 8),
            child: ReactionDisplay(reactions: reactions),
          ),
      ],
    );
  }

  void _toggleReaction(BuildContext context) async {
    final reactionManager = ReactionManager();
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    await reactionManager.toggleReaction(
      chatroomId: chatroomId,
      messageId: messageId,
      userId: currentUserId,
    );
  }
}
