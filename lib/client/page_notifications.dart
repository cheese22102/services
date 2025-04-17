import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../front/app_colors.dart';
import '../front/sidebar.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  // Static method to get unread notifications count
  static Stream<int> getUnreadNotificationsCount() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return Stream.value(0);
  
    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _isLoading = false;
  
  // Mark all notifications as read
  Future<void> _markAllAsRead() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final batch = FirebaseFirestore.instance.batch();
      final notifications = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .get();

      for (var doc in notifications.docs) {
        batch.update(doc.reference, {'read': true});
      }

      await batch.commit();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Toutes les notifications ont été marquées comme lues',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Theme.of(context).brightness == Brightness.dark 
                ? AppColors.primaryGreen 
                : AppColors.primaryDarkGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur: Impossible de marquer les notifications comme lues',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Delete all notifications
  Future<void> _deleteAllNotifications() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Supprimer toutes les notifications',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer toutes vos notifications ?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Annuler',
              style: GoogleFonts.poppins(
                color: Colors.grey,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Supprimer',
              style: GoogleFonts.poppins(
                color: Colors.red,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final batch = FirebaseFirestore.instance.batch();
      final notifications = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .get();

      for (var doc in notifications.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Toutes les notifications ont été supprimées',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Theme.of(context).brightness == Brightness.dark 
                ? AppColors.primaryGreen 
                : AppColors.primaryDarkGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur: Impossible de supprimer les notifications',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Delete a single notification
  Future<void> _deleteNotification(String notificationId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .delete();
          
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Notification supprimée',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Theme.of(context).brightness == Brightness.dark 
                ? AppColors.primaryGreen 
                : AppColors.primaryDarkGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur: Impossible de supprimer la notification',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  // Mark a single notification as read
  Future<void> _markAsRead(String notificationId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur: Impossible de marquer la notification comme lue',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  // Handle notification tap based on type
  void _handleNotificationTap(Map<String, dynamic> notification) async {
    await _markAsRead(notification['id']);
    
    if (!mounted) return;
    
    final type = notification['type'];
    final data = notification['data'] as Map<String, dynamic>?;
    
    if (type == 'message') {
      final chatroomId = data?['chatroomId'];
      final postId = data?['postId'];
      final otherUserId = data?['senderId'];
      final otherUserName = data?['senderName'] ?? '';
      
      if (chatroomId != null && postId != null && otherUserId != null) {
        // Navigate to marketplace conversation with all required parameters
        context.push('/clientHome/marketplace/chat/conversation/$otherUserId', 
          extra: {
            'postId': postId,
            'otherUserName': otherUserName,
            'chatId': chatroomId,
          }
        );
      } else if (chatroomId != null) {
        // Navigate using just the chatId
        context.push('/clientHome/marketplace/chat/${chatroomId}');
      } else if (otherUserId != null) {
        // Navigate to service conversation
        context.push('/clientHome/chat/conversation/$otherUserId',
          extra: {
            'otherUserName': otherUserName,
            'serviceName': data?['serviceName'] ?? '',
          }
        );
      }
    } else if (type == 'post') {
      // Handle post notifications (e.g., someone commented on your post)
      final postId = data?['postId'];
      if (postId != null) {
        context.push('/clientHome/marketplace/details/$postId');
      }
    } else if (type == 'system') {
      // Handle system notifications if needed
    }
  }

  // Show options menu for a notification
  void _showNotificationOptions(BuildContext context, Map<String, dynamic> notification) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? Colors.grey.shade900 : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: Colors.red,
                  ),
                  title: Text(
                    'Supprimer cette notification',
                    style: GoogleFonts.poppins(
                      color: Colors.red,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _deleteNotification(notification['id']);
                  },
                ),
                if (!(notification['read'] ?? false))
                  ListTile(
                    leading: Icon(
                      Icons.check_circle_outline,
                      color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                    ),
                    title: Text(
                      'Marquer comme lue',
                      style: GoogleFonts.poppins(
                        color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(context).pop();
                      _markAsRead(notification['id']);
                    },
                  ),
                ListTile(
                  leading: Icon(
                    Icons.close,
                    color: isDarkMode ? Colors.white70 : Colors.black54,
                  ),
                  title: Text(
                    'Annuler',
                    style: GoogleFonts.poppins(),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;
    
    return Scaffold(
      backgroundColor: isDarkMode ? AppColors.darkBackground : AppColors.lightBackground,
      drawer: const Sidebar(),
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
          ),
        ),
        backgroundColor: isDarkMode ? Colors.grey.shade900 : Colors.white,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            size: 20,
          ),
          color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Mark all as read button
          IconButton(
            icon: _isLoading 
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                    ),
                  )
                : Icon(
                    Icons.done_all,
                    color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                  ),
            tooltip: 'Marquer tout comme lu',
            onPressed: _isLoading ? null : _markAllAsRead,
          ),
          // Delete all button
          IconButton(
            icon: Icon(
              Icons.delete_sweep,
              color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
            ),
            tooltip: 'Supprimer toutes les notifications',
            onPressed: _isLoading ? null : _deleteAllNotifications,
          ),
          // Add padding at the end like in CustomAppBar
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid)
            .collection('notifications')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                color: primaryColor,
              ),
            );
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Erreur de chargement des notifications',
                style: GoogleFonts.poppins(
                  color: Colors.red,
                ),
              ),
            );
          }
          
          final notifications = snapshot.data?.docs ?? [];
          
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 64,
                    color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune notification',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vous n\'avez pas de notifications pour le moment',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index].data() as Map<String, dynamic>;
              notification['id'] = notifications[index].id;
              
              final isRead = notification['read'] ?? false;
              final timestamp = notification['timestamp'] as Timestamp?;
              final formattedTime = timestamp != null
                  ? _formatTimestamp(timestamp.toDate())
                  : '';
              
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: isRead
                      ? (isDarkMode ? Colors.grey.shade800 : Colors.white)
                      : (isDarkMode 
                          ? AppColors.primaryGreen.withOpacity(0.15) 
                          : AppColors.primaryDarkGreen.withOpacity(0.08)),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: () => _handleNotificationTap(notification),
                  onLongPress: () => _showNotificationOptions(context, notification),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Notification icon
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isRead
                                ? (isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200)
                                : (isDarkMode 
                                    ? AppColors.primaryGreen.withOpacity(0.2) 
                                    : AppColors.primaryDarkGreen.withOpacity(0.15)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            notification['type'] == 'message'
                                ? Icons.message_outlined
                                : Icons.notifications_outlined,
                            color: isRead
                                ? (isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600)
                                : primaryColor,
                            size: 18,
                          ),
                        ),
                        
                        const SizedBox(width: 12),
                        
                        // Notification content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title row
                              Row(
                                children: [
                                  // Unread indicator
                                  if (!isRead)
                                    Container(
                                      width: 6,
                                      height: 6,
                                      margin: const EdgeInsets.only(right: 6),
                                      decoration: BoxDecoration(
                                        color: isDarkMode 
                                            ? AppColors.primaryGreen 
                                            : AppColors.primaryDarkGreen,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  
                                  // Title with flexible width
                                  Expanded(
                                    child: Text(
                                      notification['title'] ?? 'Notification',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
                                        color: isDarkMode ? Colors.white : Colors.black87,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  
                                  // Timestamp with some spacing
                                  const SizedBox(width: 4),
                                  Text(
                                    formattedTime,
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: isDarkMode 
                                          ? Colors.grey.shade400 
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 4),
                              
                              // Message
                              Text(
                                notification['body'] ?? '',
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: isDarkMode 
                                      ? Colors.grey.shade300 
                                      : Colors.grey.shade700,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
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
        },
      ),
    );
  }
  
  // Format timestamp to relative time
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 7) {
      return DateFormat('dd/MM/yyyy').format(timestamp);
    } else if (difference.inDays > 0) {
      return 'Il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Il y a ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'Il y a ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'À l\'instant';
    }
  }
}