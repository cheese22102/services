import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:AiDomi/notifications_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../front/message_bubble.dart';
import '../front/app_colors.dart';

class ChatScreenPage extends StatefulWidget {
  final String otherUserId; // ID of the other user (post owner or message sender)
  final String otherUserName; // Name of the other user for display
  final String? chatId; // Optional chat ID for direct access
  final String? postId; // Optional post ID (now optional)

  const ChatScreenPage({
    super.key,
    this.otherUserId = '',
    this.otherUserName = '',
    this.chatId,
    this.postId,
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
  final bool _isChatArchived = false;
  final ScrollController _scrollController = ScrollController();
  String _otherUserId = '';

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser!;
    
    if (widget.chatId != null && widget.chatId!.isNotEmpty) {
      // If chatId is provided, use it directly
      _chatroomId = widget.chatId!;
      _fetchChatDetails();
    } else {
      // Otherwise create a new chat ID from user IDs
      _otherUserId = widget.otherUserId;
      _initializeChat();
    }
  }

  Future<void> _fetchChatDetails() async {
    try {
      final chatDoc = await _firestore.collection('conversations').doc(_chatroomId).get();
      
      if (!chatDoc.exists) {
        setState(() {
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
      
      // Mark messages as read for current user
      await _firestore.collection('conversations').doc(_chatroomId).update({
        'unreadCount.${_currentUser.uid}': 0,
      });
      
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _initializeChat() async {
    try {
      // Create chat ID from user IDs only (no post ID)
      final userIds = [_currentUser.uid, _otherUserId]..sort();
      _chatroomId = '${userIds[0]}_${userIds[1]}';
      
      // Check if chat already exists
      final chatDoc = await _firestore.collection('conversations').doc(_chatroomId).get();
      
      if (!chatDoc.exists) {
        // Initialize a new chat if it doesn't exist
        await _firestore.collection('conversations').doc(_chatroomId).set({
          'participants': [_currentUser.uid, _otherUserId],
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': _currentUser.uid,
          'unreadCount': {
            _currentUser.uid: 0,
            _otherUserId: 0,
          },
        }, SetOptions(merge: true));
      } else {
        // Just update the read status
        await _firestore.collection('conversations').doc(_chatroomId).update({
          'unreadCount.${_currentUser.uid}': 0,
        });
      }

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
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
  
      // Add message to the conversation
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
        'lastMessageSenderId': _currentUser.uid,
        'unreadCount.$_otherUserId': FieldValue.increment(1),
      });
  
      // Send notification
      await NotificationsService.sendMessageNotification(
        receiverId: _otherUserId,
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

  // Add this method to fetch user data
  Future<Map<String, dynamic>?> _fetchUserData(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return userDoc.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: isDarkMode ? Colors.black.withOpacity(0.8) : Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
            size: 22,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: FutureBuilder<Map<String, dynamic>?>(
          future: _fetchUserData(_otherUserId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Text(
                'Chargement...',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              );
            }
            
            final userData = snapshot.data;
            final firstName = userData?['firstname'] ?? '';
            final lastName = userData?['lastname'] ?? '';
            final avatarURL = userData?['avatarUrl'] ?? userData?['avatarURL'];
            
            return Row(
              children: [
                // User avatar
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isDarkMode
                      ? AppColors.primaryGreen.withOpacity(0.15)
                      : AppColors.primaryDarkGreen.withOpacity(0.08),
                  backgroundImage: avatarURL != null && avatarURL.toString().isNotEmpty
                      ? NetworkImage(avatarURL.toString())
                      : null,
                  child: avatarURL == null || avatarURL.toString().isEmpty
                      ? Icon(
                          Icons.person,
                          color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                          size: 20,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                // User name
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$firstName $lastName',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'En ligne',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.more_vert,
              color: isDarkMode ? Colors.white70 : Colors.black54,
            ),
            onPressed: () {
              // Show chat options
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Chat messages area
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.black.withOpacity(0.9) : Colors.grey.shade50,
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isDarkMode 
                        ? [
                            AppColors.darkBackground.withOpacity(0.95),
                            AppColors.darkInputBackground.withOpacity(0.9),
                            AppColors.darkBackground.withOpacity(0.95),
                          ]
                        : [
                            AppColors.lightBackground,
                            AppColors.lightInputBackground.withOpacity(0.7),
                            AppColors.lightBackground,
                          ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                        ),
                      )
                    : _buildChatMessages(),
              ),
            ),
            
            // Message input area
            Container(
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.black.withOpacity(0.8) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Text input field with container
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: isDarkMode 
                            ? AppColors.darkInputBackground.withOpacity(0.5) 
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: TextField(
                        focusNode: _textFieldFocus,
                        controller: _messageController,
                        enabled: !_isChatArchived,
                        minLines: 1,
                        maxLines: 5,
                        style: GoogleFonts.poppins(
                          color: isDarkMode ? Colors.white : Colors.black87,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: _isChatArchived
                              ? 'Cette conversation est archivée'
                              : 'Écrivez un message...',
                          hintStyle: GoogleFonts.poppins(
                            color: isDarkMode ? Colors.white38 : Colors.black38,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.transparent, // Make TextField's own fill transparent
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  
                  // Send button
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _messageController,
                    builder: (context, value, child) {
                      final hasText = value.text.trim().isNotEmpty;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          color: (hasText && !_isChatArchived)
                              ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                              : (isDarkMode 
                                  ? AppColors.darkInputBackground.withOpacity(0.5) 
                                  : Colors.grey.shade100),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            hasText ? Icons.send_rounded : Icons.mic,
                            color: hasText 
                                ? Colors.white 
                                : (isDarkMode 
                                    ? AppColors.primaryGreen 
                                    : AppColors.primaryDarkGreen),
                            size: 20,
                          ),
                          onPressed: (hasText && !_isChatArchived) 
                              ? _sendMessage
                              : () {
                                },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
