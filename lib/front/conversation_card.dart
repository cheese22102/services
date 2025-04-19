import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class ConversationCard extends StatelessWidget {
  final bool isDarkMode;
  final String userName;
  final String? userAvatar;
  final String postTitle;
  final String lastMessage;
  final DateTime? timestamp;
  final bool isLastMessageFromMe;
  final int currentUserUnreadCount;
  final VoidCallback onTap;

  const ConversationCard({
    super.key,
    required this.isDarkMode,
    required this.userName,
    required this.userAvatar,
    required this.postTitle,
    required this.lastMessage,
    required this.timestamp,
    required this.isLastMessageFromMe,
    required this.currentUserUnreadCount,
    required this.onTap,
  });

  String _formatLastMessageTime(DateTime timestamp) {
    final now = DateTime.now();
    if (now.difference(timestamp).inDays == 0) {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (now.difference(timestamp).inDays == 1) {
      return 'Hier';
    } else if (now.difference(timestamp).inDays < 7) {
      return ['Dim.', 'Lun.', 'Mar.', 'Mer.', 'Jeu.', 'Ven.', 'Sam.'][timestamp.weekday - 1];
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Always use the same card color
    final cardColor = isDarkMode
        ? AppColors.darkInputBackground
        : AppColors.lightInputBackground;

    // Use a higher elevation and a darker shadow if there are unread messages
    final List<BoxShadow> cardShadow = currentUserUnreadCount > 0
        ? [
            BoxShadow(
              color: Colors.black.withOpacity(isDarkMode ? 0.35 : 0.22),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withOpacity(isDarkMode ? 0.18 : 0.10),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: cardShadow,
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: isDarkMode
                          ? AppColors.primaryGreen.withOpacity(0.15)
                          : AppColors.primaryDarkGreen.withOpacity(0.08),
                      backgroundImage: userAvatar != null ? NetworkImage(userAvatar!) : null,
                      child: userAvatar == null
                          ? Icon(Icons.person, color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen, size: 32)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    // Conversation details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  userName,
                                  style: GoogleFonts.poppins(
                                    fontWeight: currentUserUnreadCount > 0 ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 16,
                                    color: isDarkMode ? Colors.white : Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Post title
                          Text(
                            postTitle,
                            style: GoogleFonts.poppins(
                              color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          // Last message and time
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (isLastMessageFromMe)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Icon(Icons.done_all, size: 16, color: Colors.grey[500]),
                                ),
                              Expanded(
                                child: Text(
                                  lastMessage,
                                  style: GoogleFonts.poppins(
                                    color: currentUserUnreadCount > 0
                                        ? (isDarkMode ? Colors.white : Colors.black87)
                                        : Colors.grey[600],
                                    fontWeight: currentUserUnreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (timestamp != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  _formatLastMessageTime(timestamp!),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: isDarkMode
                                        ? AppColors.primaryGreen.withOpacity(0.7)
                                        : AppColors.primaryDarkGreen.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (currentUserUnreadCount > 0)
                Positioned(
                  top: 8,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.18),
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 24,
                    ),
                    child: Text(
                      currentUserUnreadCount > 99 ? '99+' : currentUserUnreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}