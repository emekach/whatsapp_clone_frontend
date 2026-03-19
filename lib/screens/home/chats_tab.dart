// lib/screens/home/chats_tab.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../providers/chat_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/models.dart';
import '../../utils/app_theme.dart';

class ChatsTab extends StatelessWidget {
  const ChatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (chat.loading && chat.conversations.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      );
    }

    if (chat.conversations.isEmpty) {
      return _buildEmptyState(context, isDark);
    }

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () => context.read<ChatProvider>().loadConversations(),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: chat.conversations.length,
        separatorBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(left: 82),
          child: Divider(
            height: 1,
            thickness: 0.5,
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.grey.withOpacity(0.15),
          ),
        ),
        itemBuilder: (_, i) => _ConversationTile(conv: chat.conversations[i]),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 48,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No chats yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Start a conversation by tapping\n"New chat" below',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => context.push('/new-chat'),
            icon: const Icon(Icons.add_comment_rounded),
            label: const Text('Start a chat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Conversation Tile ─────────────────────────────────────────────────────

class _ConversationTile extends StatelessWidget {
  final ConversationModel conv;
  const _ConversationTile({required this.conv});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasUnread = conv.unreadCount > 0;
    final currentUser = context.read<AuthProvider>().user;

    return InkWell(
      onTap: () => context.push('/chat/${conv.id}', extra: conv.name),
      onLongPress: () => _showOptions(context, isDark),
      splashColor: AppTheme.primary.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // ── Avatar ────────────────────────────────────────────
            Stack(
              children: [
                Hero(
                  tag: 'conv_avatar_${conv.id}',
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: conv.isGroup
                          ? AppTheme.primaryDark
                          : AppTheme.primary,
                      image: conv.avatarUrl != null
                          ? DecorationImage(
                              image:
                                  CachedNetworkImageProvider(conv.avatarUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: conv.avatarUrl == null
                        ? Center(
                            child: conv.isGroup
                                ? const Icon(Icons.group_rounded,
                                    color: Colors.white, size: 26)
                                : Text(
                                    conv.name.isNotEmpty
                                        ? conv.name[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          )
                        : null,
                  ),
                ),

                // Online indicator
                if (!conv.isGroup && conv.isOnline)
                  Positioned(
                    right: 1,
                    bottom: 1,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? AppTheme.darkBg : Colors.white,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),

            // ── Content ───────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + time
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conv.name,
                          style: TextStyle(
                            fontWeight:
                                hasUnread ? FontWeight.w700 : FontWeight.w600,
                            fontSize: 15.5,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatTime(conv.lastMessage?.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              hasUnread ? FontWeight.w600 : FontWeight.normal,
                          color: hasUnread
                              ? AppTheme.primary
                              : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Last message + badge
                  Row(
                    children: [
                      // Sent ticks for last message
                      if (conv.lastMessage?.isMe == true) ...[
                        Icon(
                          conv.lastMessage?.isRead == true
                              ? Icons.done_all_rounded
                              : Icons.done_all_rounded,
                          size: 15,
                          color: conv.lastMessage?.isRead == true
                              ? const Color(0xFF53BDEB)
                              : Colors.grey.shade400,
                        ),
                        const SizedBox(width: 3),
                      ],

                      // Message preview
                      Expanded(
                        child: Text(
                          conv.lastMessage?.preview ?? 'Start a conversation',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: hasUnread
                                ? (isDark ? Colors.white70 : Colors.black87)
                                : Colors.grey.shade500,
                            fontWeight:
                                hasUnread ? FontWeight.w500 : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Unread badge
                      if (hasUnread)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          constraints: const BoxConstraints(minWidth: 20),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            conv.unreadCount > 99
                                ? '99+'
                                : '${conv.unreadCount}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                      // Muted icon
                      if (!hasUnread)
                        Icon(
                          Icons.volume_off_outlined,
                          size: 14,
                          color: Colors.transparent,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptions(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Conversation name header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppTheme.primary,
                    backgroundImage: conv.avatarUrl != null
                        ? CachedNetworkImageProvider(conv.avatarUrl!)
                        : null,
                    child: conv.avatarUrl == null
                        ? Text(conv.name[0].toUpperCase(),
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold))
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(conv.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
            const Divider(height: 1),
            _opt(context, Icons.archive_outlined, 'Archive chat', Colors.blue),
            _opt(context, Icons.volume_off_outlined, 'Mute', Colors.orange),
            _opt(context, Icons.push_pin_outlined, 'Pin chat', Colors.purple),
            _opt(context, Icons.mark_chat_read_outlined, 'Mark as read',
                Colors.green),
            _opt(context, Icons.delete_outline_rounded, 'Delete chat',
                Colors.red),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _opt(BuildContext context, IconData icon, String label, Color color) {
    return ListTile(
      dense: true,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
            color: color.withOpacity(0.1), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      onTap: () => Navigator.pop(context),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inDays == 0) return DateFormat('HH:mm').format(dt);
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return DateFormat('EEE').format(dt);
    return DateFormat('dd/MM/yy').format(dt);
  }
}
