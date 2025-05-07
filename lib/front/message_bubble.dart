import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class MessageBubble extends StatefulWidget {
  final String messageId;
  final String message;
  final bool isSender;
  final String chatroomId;
  final DateTime? timestamp;
  final Map<String, dynamic>? reactions;
  final bool showAvatar;
  final bool isGrouped;
  final bool isSeen;

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
    this.isSeen = false,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _showStatus = false;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // Define colors based on theme - using your app's color palette
    final senderBubbleColor = isDarkMode 
        ? AppColors.primaryDarkGreen
        : AppColors.primaryGreen;
    
    final receiverBubbleColor = isDarkMode
        ? Colors.grey.shade800
        : Colors.white;
    
    final senderTextColor = Colors.white;
    final receiverTextColor = isDarkMode ? Colors.white : Colors.black87;
    
    // Extract reaction logic to a separate method for reuse
    Future<void> toggleReaction() async {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      final messageRef = FirebaseFirestore.instance
          .collection('conversations')
          .doc(widget.chatroomId)
          .collection('messages')
          .doc(widget.messageId);

      if (widget.reactions?.containsKey(currentUserId) ?? false) {
        await messageRef.update({
          'reactions.$currentUserId': FieldValue.delete(),
        });
      } else {
        await messageRef.update({
          'reactions.$currentUserId': '❤️',
        });
      }
    }
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _showStatus = !_showStatus;
        });
      },
      onDoubleTap: toggleReaction,
      onLongPress: toggleReaction,
      child: Padding(
        padding: EdgeInsets.only(
          left: widget.isSender ? 60.0 : 16.0,
          right: widget.isSender ? 16.0 : 60.0,
          top: widget.isGrouped ? 2.0 : 8.0,
          bottom: 4.0,
        ),
        child: Row(
          mainAxisAlignment: widget.isSender ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Removed the avatar that was here
            Flexible(
              child: Column(
                crossAxisAlignment: widget.isSender ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: widget.isSender ? senderBubbleColor : receiverBubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(widget.isSender ? 18 : 4),
                        bottomRight: Radius.circular(widget.isSender ? 4 : 18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          widget.message,
                          style: GoogleFonts.poppins(
                            color: widget.isSender ? senderTextColor : receiverTextColor,
                            fontSize: 14,
                            height: 1.3,
                          ),
                          softWrap: true,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.timestamp != null
                                  ? DateFormat('HH:mm').format(widget.timestamp!)
                                  : '',
                              style: GoogleFonts.poppins(
                                color: widget.isSender ? Colors.white70 : (isDarkMode ? Colors.white60 : Colors.black45),
                                fontSize: 10,
                              ),
                            ),
                            if (widget.isSender) ...[
                              const SizedBox(width: 4),
                              Icon(
                                widget.isSeen ? Icons.done_all : Icons.done,
                                size: 12,
                                color: widget.isSeen 
                                    ? Colors.white70
                                    : Colors.white38,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (widget.reactions?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.grey.shade800 : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            spreadRadius: 1,
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('❤️', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 2),
                          Text(
                            '${widget.reactions?.length}',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: isDarkMode ? Colors.white70 : Colors.grey[600],
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
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: widget.isSeen 
                            ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                            : (isDarkMode ? Colors.white54 : Colors.grey[600]),
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

