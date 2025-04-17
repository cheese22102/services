import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:plateforme_services/notifications_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../front/message_bubble.dart';
import '../../front/custom_app_bar.dart';
import '../../front/app_colors.dart';
import 'package:go_router/go_router.dart';

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
  final bool _isChatArchived = false;
  final ScrollController _scrollController = ScrollController();
  String _otherUserId = '';
  String _postId = '';
  String _productTitle = '';

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser!;
    if (widget.chatId != null && widget.chatId!.isNotEmpty) {
      _chatroomId = widget.chatId!;
      _fetchChatDetails();
    } else {
      _otherUserId = widget.otherUserId;
      _postId = widget.postId;
      _initializeChat();
    }
    _fetchProductTitle();
    
    // Add listener to text controller to rebuild UI when text changes
    _messageController.addListener(() {
      setState(() {});
    });
  }
  
  @override
  void dispose() {
    _messageController.dispose();
    _textFieldFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchProductTitle() async {
    if (_postId.isEmpty) return;
    final doc = await FirebaseFirestore.instance.collection('marketplace').doc(_postId).get();
    if (doc.exists) {
      setState(() {
        _productTitle = doc.data()?['title'] ?? '';
      });
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
      
      // Get post ID
      _postId = chatData['postId'] ?? '';
      
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
        'unreadCount.$_otherUserId': FieldValue.increment(1), // Changed from widget.otherUserId to _otherUserId
      });

      // Send notification
      await NotificationsService.sendMessageNotification(
        receiverId: _otherUserId, // Changed from widget.otherUserId to _otherUserId
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: CustomAppBar(
        title: _productTitle.isNotEmpty ? _productTitle : 'Annonce',
        showBackButton: true,
        actions: [
          if (_postId.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.info_outline,
                color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                size: 24,
              ),
              tooltip: 'Voir l\'annonce',
              onPressed: () {
                context.go('/clientHome/marketplace/details/$_postId');
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
                  color: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
                  // Removed image decoration that was causing errors
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
                color: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Attachment button
                  IconButton(
                    icon: Icon(
                      Icons.attach_file_rounded,
                      color: isDarkMode 
                          ? AppColors.primaryGreen 
                          : AppColors.primaryDarkGreen,
                      size: 24,
                    ),
                    onPressed: () {
                      // TODO: Handle attachment
                    },
                  ),
                  
                  // Text input field with container
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDarkMode ? AppColors.darkInputBackground : AppColors.lightInputBackground,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDarkMode 
                              ? Colors.transparent 
                              : AppColors.lightBorderColor.withOpacity(0.2),
                          width: 1,
                        ),
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
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          isDense: true,
                          // Add these lines to fix the background color issue
                          filled: true,
                          fillColor: isDarkMode ? AppColors.darkInputBackground : AppColors.lightInputBackground,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  
                  // Send button
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: (_messageController.text.trim().isNotEmpty && !_isChatArchived)
                            ? (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                            : (isDarkMode ? Colors.grey[700] : Colors.grey[300]),
                        shape: BoxShape.circle,
                        boxShadow: [
                          if (_messageController.text.trim().isNotEmpty && !_isChatArchived)
                            BoxShadow(
                              color: (isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen)
                                  .withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                        ],
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        onPressed: (_messageController.text.trim().isEmpty || _isChatArchived) 
                            ? null 
                            : () => _sendMessage(),
                      ),
                    ),
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
