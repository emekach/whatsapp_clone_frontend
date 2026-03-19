// lib/services/notification_service.dart

import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/app_theme.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  // Track which conversation is currently open so we
  // don't show a notification for the chat the user is already in
  int? _activeChatId;

  void setActiveChatId(int? id) => _activeChatId = id;

  // ── Show in-app message notification ─────────────────────────────

  void showMessageNotification({
    required int conversationId,
    required String senderName,
    required String message,
    String? avatarUrl,
    required VoidCallback onTap,
  }) {
    // Don't show if user is already in this conversation
    if (_activeChatId == conversationId) return;

    showOverlayNotification(
      (context) => _MessageNotificationCard(
        senderName: senderName,
        message: message,
        avatarUrl: avatarUrl,
        onTap: onTap,
      ),
      duration: const Duration(seconds: 4),
      position: NotificationPosition.top,
    );
  }

  // ── Show simple toast ─────────────────────────────────────────────

  void showToast(String message, {bool isError = false}) {
    showSimpleNotification(
      Text(message,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w500)),
      background: isError ? Colors.red.shade700 : AppTheme.primary,
      autoDismiss: true,
      duration: const Duration(seconds: 2),
      slideDismissDirection: DismissDirection.up,
    );
  }
}

// ── Notification card widget ──────────────────────────────────────────────

class _MessageNotificationCard extends StatelessWidget {
  final String senderName;
  final String message;
  final String? avatarUrl;
  final VoidCallback onTap;

  const _MessageNotificationCard({
    required this.senderName,
    required this.message,
    required this.avatarUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        OverlaySupportEntry.of(context)?.dismiss();
        onTap();
      },
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1F2C34) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.06)
                  : Colors.black.withOpacity(0.04),
            ),
          ),
          child: Row(children: [
            // Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: AppTheme.primary,
              backgroundImage: avatarUrl != null
                  ? CachedNetworkImageProvider(avatarUrl!)
                  : null,
              child: avatarUrl == null
                  ? Text(
                      senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ))
                  : null,
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    // App name badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('WhatsApp',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          )),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _timeNow(),
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 11,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    senderName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: TextStyle(
                      color: isDark ? Colors.white60 : Colors.grey.shade600,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Dismiss button
            GestureDetector(
              onTap: () => OverlaySupportEntry.of(context)?.dismiss(),
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: Colors.grey.shade400,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  String _timeNow() {
    final now = DateTime.now();
    final h = now.hour.toString().padLeft(2, '0');
    final m = now.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
