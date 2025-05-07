import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class ConversationCard extends StatelessWidget {
  final bool isDarkMode;
  final String userName;
  final String? userAvatar;
  final String postTitle;
  final String lastMessage;
  final String timestamp;
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
    required bool isLoading,
  });

  @override
  Widget build(BuildContext context) {
    // Modern card color with slight transparency
    final cardColor = isDarkMode
        ? AppColors.darkInputBackground.withOpacity(0.95)
        : AppColors.lightInputBackground;

    // Subtle shadow for depth
    final List<BoxShadow> cardShadow = currentUserUnreadCount > 0
        ? [
            BoxShadow(
              color: isDarkMode 
                  ? Colors.black.withOpacity(0.25) 
                  : Colors.black.withOpacity(0.15),
              blurRadius: 12,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ]
        : [
            BoxShadow(
              color: isDarkMode 
                  ? Colors.black.withOpacity(0.15) 
                  : Colors.black.withOpacity(0.08),
              blurRadius: 4,
              spreadRadius: 0,
              offset: const Offset(0, 2),
            ),
          ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: cardShadow,
            border: currentUserUnreadCount > 0 
                ? Border.all(
                    color: isDarkMode 
                        ? AppColors.primaryGreen.withOpacity(0.3) 
                        : AppColors.primaryDarkGreen.withOpacity(0.15),
                    width: 1.5,
                  )
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar - smaller size
                CircleAvatar(
                  radius: 22,
                  backgroundColor: isDarkMode
                      ? AppColors.primaryGreen.withOpacity(0.15)
                      : AppColors.primaryDarkGreen.withOpacity(0.08),
                  backgroundImage: userAvatar != null ? NetworkImage(userAvatar!) : null,
                  child: userAvatar == null
                      ? Icon(Icons.person, color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen, size: 24)
                      : null,
                ),
                const SizedBox(width: 12),
                // Conversation details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Name row with unread count badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              userName,
                              style: GoogleFonts.poppins(
                                fontWeight: currentUserUnreadCount > 0 ? FontWeight.bold : FontWeight.w500,
                                fontSize: 14,
                                color: isDarkMode ? Colors.white : Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Unread count badge positioned next to the name
                          if (currentUserUnreadCount > 0)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.shade600,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 20,
                                minHeight: 20,
                              ),
                              child: Text(
                                currentUserUnreadCount > 99 ? '99+' : currentUserUnreadCount.toString(),
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ),
                      
                      if (postTitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          postTitle,
                          style: GoogleFonts.poppins(
                            color: isDarkMode ? AppColors.primaryGreen : AppColors.primaryDarkGreen,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      
                      const SizedBox(height: 3),
                      // Last message with timestamp
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (isLastMessageFromMe)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.done_all, 
                                size: 14, 
                                color: isDarkMode ? Colors.grey[400] : Colors.grey[500]
                              ),
                            ),
                          Expanded(
                            child: Text(
                              lastMessage,
                              style: GoogleFonts.poppins(
                                color: currentUserUnreadCount > 0
                                    ? (isDarkMode ? Colors.white : Colors.black87)
                                    : isDarkMode ? Colors.grey[400] : Colors.grey[600],
                                fontWeight: currentUserUnreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (timestamp.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              timestamp,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: isDarkMode
                                    ? Colors.white70
                                    : Colors.black54,
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
        ),
      ),
    );
  }
}