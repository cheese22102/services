import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../front/app_colors.dart'; // For prestataire theme colors
import '../front/app_spacing.dart'; // For consistent spacing

class ProviderNotificationsPage extends StatefulWidget {
  const ProviderNotificationsPage({super.key});

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
  State<ProviderNotificationsPage> createState() => _ProviderNotificationsPageState();
}

class _ProviderNotificationsPageState extends State<ProviderNotificationsPage> {
  bool _isLoading = false;

  Future<void> _markAllAsRead() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    setState(() => _isLoading = true);

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
            content: Text('Toutes les notifications ont été marquées comme lues', style: GoogleFonts.poppins()),
            backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: Impossible de marquer les notifications comme lues', style: GoogleFonts.poppins()),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteAllNotifications() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer toutes les notifications', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text('Êtes-vous sûr de vouloir supprimer toutes vos notifications ?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Annuler', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Supprimer', style: GoogleFonts.poppins(color: AppColors.errorRed)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _isLoading = true);

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
            content: Text('Toutes les notifications ont été supprimées', style: GoogleFonts.poppins()),
            backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: Impossible de supprimer les notifications', style: GoogleFonts.poppins()),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
            content: Text('Notification supprimée', style: GoogleFonts.poppins()),
            backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: Impossible de supprimer la notification', style: GoogleFonts.poppins()),
            backgroundColor: AppColors.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
          ),
        );
      }
    }
  }

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
      // Silently fail or log, as this is often called on tap before navigation
      debugPrint("Error marking notification as read: $e");
    }
  }

  void _handleNotificationTap(Map<String, dynamic> notification) async {
    await _markAsRead(notification['id']);
    
    if (!mounted) return;

    final type = notification['type'] as String?;
    final title = notification['title'] as String?; // Get title
    final data = notification['data'] as Map<String, dynamic>?;

    if (data == null) {
      debugPrint("Notification data is null for notification ID ${notification['id']}, cannot navigate.");
      return; 
    }

    final reservationId = data['reservationId'] as String?; // Extract reservationId for potential use

    if (type == 'message' || type == 'new_message') {
      final chatId = data['chatId'] as String?;
      final otherUserId = data['senderId'] as String?; 
      final otherUserName = data['senderName'] as String? ?? data['otherUserName'] as String? ?? 'Utilisateur';

      if (chatId != null && chatId.isNotEmpty) {
        context.push('/prestataireHome/chat/$chatId');
      } else if (otherUserId != null && otherUserId.isNotEmpty) {
        context.push('/prestataireHome/chat/conversation/$otherUserId', extra: {'otherUserName': otherUserName});
      } else {
        debugPrint("Chat ID or Other User ID is missing for message notification ID ${notification['id']}");
      }
    } else if (type == 'new_reservation' || 
               type == 'reservation_update' || 
               type == 'reservation_cancelled' || 
               type == 'reservation_completed_by_client') {
      if (reservationId != null && reservationId.isNotEmpty) {
        context.push('/prestataireHome/reservation-details/$reservationId');
      } else {
        debugPrint("Reservation ID is missing for notification ID ${notification['id']} with type: $type");
      }
    } else if (title == "Nouvelle demande d'intervention" && 
               (type == null || type.isEmpty || (type != 'message' && type != 'new_message'))) { 
      // Fallback: if type is not a known reservation type (or null/empty) but title matches,
      // and it's not a message type (to avoid conflict if a message title happens to be this string).
      if (reservationId != null && reservationId.isNotEmpty) {
        context.push('/prestataireHome/reservation-details/$reservationId');
      } else {
        debugPrint("Reservation ID is missing for notification ID ${notification['id']} with title: $title");
      }
    }
    // Add more notification types and navigation logic as needed
    // e.g., for profile approval/rejection, navigate to profile or a status page
    // else if (type == 'profile_approved' || type == 'profile_rejected') {
    //   context.push('/prestataireHome/profile');
    // }
  }

  void _showNotificationOptions(BuildContext context, Map<String, dynamic> notification) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? AppColors.darkCardBackground : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg))),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.delete_outline, color: AppColors.errorRed),
                  title: Text('Supprimer cette notification', style: GoogleFonts.poppins(color: AppColors.errorRed)),
                  onTap: () {
                    Navigator.of(context).pop();
                    _deleteNotification(notification['id']);
                  },
                ),
                if (!(notification['read'] ?? false))
                  ListTile(
                    leading: Icon(Icons.check_circle_outline, color: primaryColor),
                    title: Text('Marquer comme lue', style: GoogleFonts.poppins(color: primaryColor)),
                    onTap: () {
                      Navigator.of(context).pop();
                      _markAsRead(notification['id']);
                    },
                  ),
                ListTile(
                  leading: Icon(Icons.close, color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                  title: Text('Annuler', style: GoogleFonts.poppins(color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                  onTap: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    if (difference.inDays > 7) return DateFormat('dd/MM/yyyy').format(timestamp);
    if (difference.inDays > 0) return 'Il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    if (difference.inHours > 0) return 'Il y a ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    if (difference.inMinutes > 0) return 'Il y a ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    return 'À l\'instant';
  }

  IconData _getNotificationIcon(String? type) {
    switch (type) {
      case 'approval':
      case 'profile_approved':
        return Icons.check_circle_outline;
      case 'rejection':
      case 'profile_rejected':
        return Icons.highlight_off_outlined;
      case 'message':
        return Icons.message_outlined;
      case 'new_reservation':
        return Icons.calendar_today_outlined;
      case 'reservation_update':
        return Icons.edit_calendar_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen;
    final scaffoldBackgroundColor = isDarkMode ? AppColors.darkBackground : AppColors.lightBackground;
    final appBarBackgroundColor = isDarkMode ? AppColors.darkCardBackground : Colors.white; // Or AppColors.lightCardBackground

    return Scaffold(
      backgroundColor: scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Notifications', style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: primaryColor)),
        backgroundColor: appBarBackgroundColor,
        elevation: 0, // Flat appbar
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, size: 20, color: primaryColor),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: _isLoading ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor)) : Icon(Icons.done_all, color: primaryColor),
            tooltip: 'Marquer tout comme lu',
            onPressed: _isLoading ? null : _markAllAsRead,
          ),
          IconButton(
            icon: Icon(Icons.delete_sweep_outlined, color: primaryColor),
            tooltip: 'Supprimer toutes les notifications',
            onPressed: _isLoading ? null : _deleteAllNotifications,
          ),
          const SizedBox(width: AppSpacing.sm),
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
            return Center(child: CircularProgressIndicator(color: primaryColor));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur de chargement des notifications', style: GoogleFonts.poppins(color: AppColors.errorRed)));
          }
          final notifications = snapshot.data?.docs ?? [];
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 64, color: isDarkMode ? Colors.grey.shade600 : Colors.grey.shade400),
                  const SizedBox(height: AppSpacing.md),
                  Text('Aucune notification', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w500, color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600)),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Vous n\'avez pas de notifications pour le moment', style: GoogleFonts.poppins(fontSize: 14, color: isDarkMode ? Colors.grey.shade500 : Colors.grey.shade500), textAlign: TextAlign.center),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.md),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notificationData = notifications[index].data() as Map<String, dynamic>;
              notificationData['id'] = notifications[index].id; // Add document ID for operations
              
              final isRead = notificationData['read'] ?? false;
              final timestamp = notificationData['timestamp'] as Timestamp?;
              final formattedTime = timestamp != null ? _formatTimestamp(timestamp.toDate()) : '';
              final notificationType = notificationData['type'] as String?;

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: isRead
                      ? (isDarkMode ? AppColors.darkCardBackground : AppColors.lightCardBackground) 
                      : (isDarkMode ? primaryColor.withOpacity(0.15) : primaryColor.withOpacity(0.08)),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: () => _handleNotificationTap(notificationData),
                  onLongPress: () => _showNotificationOptions(context, notificationData),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isRead
                                ? (isDarkMode ? Colors.grey.shade700 : Colors.grey.shade200)
                                : (isDarkMode ? primaryColor.withOpacity(0.25) : primaryColor.withOpacity(0.15)),
                            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                          ),
                          child: Icon(
                            _getNotificationIcon(notificationType),
                            color: isRead
                                ? (isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600)
                                : primaryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  if (!isRead)
                                    Container(
                                      width: 7,
                                      height: 7,
                                      margin: const EdgeInsets.only(right: AppSpacing.sm),
                                      decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                                    ),
                                  Expanded(
                                    child: Text(
                                      notificationData['title'] ?? 'Notification',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14.5,
                                        fontWeight: isRead ? FontWeight.w500 : FontWeight.w600,
                                        color: isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Text(
                                    formattedTime,
                                    style: GoogleFonts.poppins(fontSize: 11.5, color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs / 2),
                              Text(
                                notificationData['body'] ?? '',
                                style: GoogleFonts.poppins(fontSize: 13, color: isDarkMode ? AppColors.darkTextSecondary : AppColors.lightTextSecondary.withOpacity(0.8)),
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
}
