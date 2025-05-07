import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../front/app_colors.dart';
import '../front/custom_app_bar.dart';
import '../front/custom_bottom_nav.dart';
import '../front/marketplace_search.dart';
import '../front/conversation_card.dart';
import '../front/sidebar.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

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
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final int _selectedIndex = 3;
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

    return WillPopScope(
      onWillPop: () async {
        context.go('/clientHome');
        return false;
      },
      child: Scaffold(
        backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
        drawer: const Sidebar(),
        appBar: CustomAppBar(
          title: 'Messages',
          showBackButton: false,
          showSidebar: true,
          showNotifications: true,
          currentIndex: _selectedIndex,
          backgroundColor: isDarkMode ? Colors.grey.shade900 : Colors.white,
        ),
        body: Column(
          children: [
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
                            'Commencez à discuter avec un vendeur',
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

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: conversations.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final conversation = conversations[index].data() as Map<String, dynamic>;
                      final participants = List<String>.from(conversation['participants']);
                      final otherUserId = participants.firstWhere((id) => id != currentUserId);
                      final lastMessage = conversation['lastMessage']?.toString() ?? 'Pas encore de messages';
                      final timestamp = conversation['lastMessageTime']?.toDate();
                      final isLastMessageFromMe = conversation['lastMessageSenderId'] == currentUserId;
                      
                      // Fix the type casting issue
                      final unreadCountValue = (conversation['unreadCount'] ?? {})[currentUserId];
                      final currentUserUnreadCount = unreadCountValue != null ? unreadCountValue.toInt() : 0;
                      
                      final conversationId = conversations[index].id;

                      return _buildConversationItem(
                        otherUserId,
                        lastMessage,
                        timestamp,
                        isLastMessageFromMe,
                        currentUserUnreadCount,
                        conversationId,
                        isDarkMode,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
        bottomNavigationBar: CustomBottomNav(
          currentIndex: _selectedIndex,
        ),
      ),
    );
  }
  
  Widget _buildConversationItem(
    String otherUserId,
    String lastMessage,
    DateTime? timestamp,
    bool isLastMessageFromMe,
    int currentUserUnreadCount,
    String conversationId,
    bool isDarkMode,
  ) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getUserInfo(otherUserId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Card(
            color: isDarkMode ? AppColors.darkInputBackground : AppColors.lightInputBackground,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: const ListTile(
              title: Text('Chargement...'),
              subtitle: LinearProgressIndicator(),
            ),
          );
        }
        
        final userName = snapshot.data!['name'];
        final userAvatar = snapshot.data!['avatar'];
        
        final formattedTime = timestamp != null ? _formatTimestamp(timestamp) : '';
        
        return ConversationCard(
          isDarkMode: isDarkMode,
          userName: userName,
          userAvatar: userAvatar,
          postTitle: "",
          lastMessage: lastMessage,
          timestamp: formattedTime,
          isLastMessageFromMe: isLastMessageFromMe,
          currentUserUnreadCount: currentUserUnreadCount,
          isLoading: false,
          onTap: () {
            if (currentUserUnreadCount > 0) {
              FirebaseFirestore.instance
                  .collection('conversations')
                  .doc(conversationId)
                  .update({
                'unreadCount.$currentUserId': 0,
                'lastRead.$currentUserId': FieldValue.serverTimestamp(),
              });
            }
            
            context.push('/clientHome/marketplace/chat/$conversationId', extra: {
              'otherUserId': otherUserId,
              'otherUserName': userName,
            });
          },
        );
      },
    );
  }
}