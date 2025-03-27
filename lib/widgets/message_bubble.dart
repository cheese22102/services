import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MessageBubble extends StatefulWidget {
  final String messageId;
  final String message;
  final bool isSender;
  final String chatroomId;
  final DateTime? timestamp;
  final Map<String, dynamic>? reactions;
  final bool showAvatar;
  final bool isGrouped;
  final bool isSeen;  // Add this

  const MessageBubble({
    super.key,
    required this.messageId,
    required this.message,
    required this.isSender,
    required this.chatroomId,
    this.timestamp,
    this.reactions,
    this.showAvatar = false,
    this.isGrouped = false,
    this.isSeen = false,  // Add this
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _showStatus = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showStatus = !_showStatus;
        });
      },
      onDoubleTap: () async {
        final currentUserId = FirebaseAuth.instance.currentUser?.uid;
        if (currentUserId == null) return;

        final messageRef = FirebaseFirestore.instance
            .collection('conversations')
            .doc(widget.chatroomId)  // Access through widget
            .collection('messages')
            .doc(widget.messageId);   // Access through widget

        if (widget.reactions?.containsKey(currentUserId) ?? false) {  // Access through widget
          await messageRef.update({
            'reactions.$currentUserId': FieldValue.delete(),
          });
        } else {
          await messageRef.update({
            'reactions.$currentUserId': '❤️',
          });
        }
      },
      child: Padding(
        padding: EdgeInsets.only(
          left: 8.0,
          right: 8.0,
          top: widget.isGrouped ? 2.0 : 8.0,
          bottom: 4.0,
        ),
        child: Row(
          mainAxisAlignment: widget.isSender ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!widget.isSender && widget.showAvatar) ...[
              const CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey,
                child: Icon(Icons.person, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: widget.isSender ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                      minWidth: 50.0,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: widget.isSender ? Colors.deepPurple : Colors.grey[300],
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: Radius.circular(widget.isSender ? 20 : 5),
                          bottomRight: Radius.circular(widget.isSender ? 5 : 20),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            widget.message,
                            style: TextStyle(
                              color: widget.isSender ? Colors.white : Colors.black,
                              fontSize: 16,
                            ),
                            softWrap: true,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('HH:mm').format(widget.timestamp ?? DateTime.now()),
                            style: TextStyle(
                              color: widget.isSender ? Colors.white70 : Colors.black54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.reactions?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            spreadRadius: 1,
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('❤️'),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.reactions?.length}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_showStatus && widget.isSender) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.isSeen ? 'Vu' : 'Envoyé',
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.isSeen ? Colors.blue : Colors.grey,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
