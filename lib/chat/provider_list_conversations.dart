import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../front/app_colors.dart';
import '../front/marketplace_search.dart';

class ProviderChatListScreen extends StatefulWidget {
  const ProviderChatListScreen({super.key});

  static Stream<int> getTotalUnreadCount() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(0);

    return FirebaseFirestore.instance
        .collection('conversations')
        .where('participants', arrayContains: user.uid)
        .snapshots()
        .map((snapshot) {
      int totalUnread = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final unreadCount = (data['unreadCount'] ?? {})[user.uid];
        if (unreadCount != null) {
          // Fix: Convert num to int properly
          if (unreadCount is int) {
            totalUnread += unreadCount;
          } else if (unreadCount is double) {
            totalUnread += unreadCount.toInt();
          } else {
            // Handle other cases by parsing as int
            totalUnread += int.parse(unreadCount.toString());
          }
        }
      }
      return totalUnread;
    });
  }

  @override
  State<ProviderChatListScreen> createState() => _ProviderChatListScreenState();
}

class _ProviderChatListScreenState extends State<ProviderChatListScreen> {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      if (_searchQuery != _searchController.text.toLowerCase()) {
        setState(() {
          _searchQuery = _searchController.text.toLowerCase();
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _getUserInfo(String userId) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (!doc.exists) return {'name': 'Utilisateur inconnu', 'avatar': null};
      final data = doc.data()!;
      final fullName = '${data['firstname']} ${data['lastname']}'.trim();
      final avatarUrl = data['avatarUrl'] != null && data['avatarUrl'].toString().isNotEmpty 
          ? data['avatarUrl'].toString()
          : null;
      return {'name': fullName.isNotEmpty ? fullName : 'Utilisateur', 'avatar': avatarUrl};
    } catch (_) {
      return {'name': 'Utilisateur inconnu', 'avatar': null};
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inSeconds < 60) {
      return 'À l\'instant';
    } else if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours} h';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays} j';
    } else {
      return DateFormat('dd/MM/yyyy').format(timestamp);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Column(
        children: [
          // The search bar and filter options should be directly in the Column,
          // not wrapped in an extra Padding that might cause double spacing.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: MarketplaceSearch(
              controller: _searchController,
              hintText: 'Rechercher une conversation...',
              onChanged: (value) {
                // Listener handles this
              },
              onClear: () {
                _searchController.clear();
                setState(() => _searchQuery = '');
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('conversations')
                  .where('participants', arrayContains: currentUserId)
                  .orderBy('lastMessageTime', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: isDarkMode ? Colors.redAccent : Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Une erreur est survenue',
                          style: GoogleFonts.poppins(fontSize: 18, color: isDarkMode ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Impossible de charger les conversations.',
                          style: GoogleFonts.poppins(fontSize: 14, color: isDarkMode ? Colors.white54 : Colors.black45),
                        ),
                      ],
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final conversations = snapshot.data?.docs ?? [];
                if (conversations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: isDarkMode ? Colors.white54 : Colors.black38),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune conversation',
                          style: GoogleFonts.poppins(fontSize: 18, color: isDarkMode ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Commencez à discuter avec un client',
                          style: GoogleFonts.poppins(fontSize: 14, color: isDarkMode ? Colors.white54 : Colors.black45),
                        ),
                      ],
                    ),
                  );
                }
                
                if (_searchQuery.isNotEmpty) {
                  return FutureBuilder<List<Widget>>(
                    future: Future.wait(conversations.map((doc) async {
                      final conversation = doc.data() as Map<String, dynamic>;
                      final participants = List<String>.from(conversation['participants']);
                      final otherUserId = participants.firstWhere((id) => id != currentUserId);
                      
                      final userInfo = await _getUserInfo(otherUserId);
                      final userName = userInfo['name'].toString().toLowerCase();
                      
                      if (userName.contains(_searchQuery.toLowerCase())) {
                        final lastMessage = conversation['lastMessage']?.toString() ?? 'Pas encore de messages';
                        final timestamp = conversation['lastMessageTime']?.toDate();
                        final isLastMessageFromMe = conversation['lastMessageSenderId'] == currentUserId;
                        
                        // Fix the type casting issue
                        final unreadCountValue = (conversation['unreadCount'] ?? {})[currentUserId];
                        final currentUserUnreadCount = unreadCountValue != null ? unreadCountValue.toInt() : 0;
                        
                        final conversationId = doc.id;
                        
                        return _buildConversationItem(
                          otherUserId,
                          lastMessage,
                          timestamp,
                          isLastMessageFromMe,
                          currentUserUnreadCount,
                          conversationId,
                          isDarkMode,
                        );
                      } else {
                        return const SizedBox.shrink();
                      }
                    })),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      final filteredWidgets = snapshot.data!.where((widget) => widget is! SizedBox).toList();
                      
                      if (filteredWidgets.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off, size: 64, color: isDarkMode ? Colors.white54 : Colors.black38),
                              const SizedBox(height: 16),
                              Text(
                                'Aucun résultat',
                                style: GoogleFonts.poppins(fontSize: 18, color: isDarkMode ? Colors.white70 : Colors.black54, fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Essayez avec un autre terme de recherche',
                                style: GoogleFonts.poppins(fontSize: 14, color: isDarkMode ? Colors.white54 : Colors.black45),
                              ),
                            ],
                          ),
                        );
                      }
                      
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredWidgets.length,
                        separatorBuilder: (context, index) => Divider(
                          color: isDarkMode ? Colors.white12 : Colors.black12,
                          height: 24,
                        ),
                        itemBuilder: (context, index) => filteredWidgets[index],
                      );
                    },
                  );
                }
                
                return FutureBuilder<List<Widget>>(
                  future: Future.wait(conversations.map((doc) async {
                    final conversation = doc.data() as Map<String, dynamic>;
                    final participants = List<String>.from(conversation['participants']);
                    final otherUserId = participants.firstWhere((id) => id != currentUserId);
                    
                    final lastMessage = conversation['lastMessage']?.toString() ?? 'Pas encore de messages';
                    final timestamp = conversation['lastMessageTime']?.toDate();
                    final isLastMessageFromMe = conversation['lastMessageSenderId'] == currentUserId;
                    
                    // Fix the type casting issue
                    final unreadCountValue = (conversation['unreadCount'] ?? {})[currentUserId];
                    final currentUserUnreadCount = unreadCountValue != null ? unreadCountValue.toInt() : 0;
                    
                    final conversationId = doc.id;
                    
                    return _buildConversationItem(
                      otherUserId,
                      lastMessage,
                      timestamp,
                      isLastMessageFromMe,
                      currentUserUnreadCount,
                      conversationId,
                      isDarkMode,
                    );
                  })),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: snapshot.data!.length,
                      separatorBuilder: (context, index) => Divider(
                        color: isDarkMode ? Colors.white12 : Colors.black12,
                        height: 24,
                      ),
                      itemBuilder: (context, index) => snapshot.data![index],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildConversationItem(
    String otherUserId,
    String lastMessage,
    DateTime? timestamp,
    bool isLastMessageFromMe,
    int unreadCount,
    String conversationId,
    bool isDarkMode,
  ) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getUserInfo(otherUserId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }
        
        final userInfo = snapshot.data!;
        final userName = userInfo['name'] as String;
        final avatarUrl = userInfo['avatar'] as String?;
        
        return InkWell(
          onTap: () {
            // Navigate to chat screen with the conversation ID
            context.push('/prestataireHome/chat/$conversationId');
          },
          child: Container(
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey.shade900 : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: isDarkMode ? Colors.black26 : Colors.black12,
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null
                        ? Icon(
                            Icons.person,
                            color: isDarkMode ? Colors.white70 : Colors.grey.shade700,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  // Message content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                userName,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w500,
                                  color: isDarkMode ? Colors.white : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (timestamp != null)
                              Text(
                                _formatTimestamp(timestamp),
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: isDarkMode ? Colors.white60 : Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (isLastMessageFromMe)
                              Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Icon(
                                  Icons.done_all,
                                  size: 16,
                                  color: isDarkMode ? Colors.white38 : Colors.grey.shade500,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                lastMessage,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  color: unreadCount > 0
                                      ? (isDarkMode ? Colors.white : Colors.black87)
                                      : (isDarkMode ? Colors.white60 : Colors.grey.shade600),
                                  fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (unreadCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  unreadCount.toString(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
