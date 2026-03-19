// lib/providers/chat_provider.dart

import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class ChatProvider extends ChangeNotifier {
  final _api = ApiService();

  List<ConversationModel> _conversations = [];
  bool _loading = false;
  String? _error;

  List<ConversationModel> get conversations => _conversations;
  bool get loading => _loading;
  String? get error => _error;

  int get totalUnread =>
      _conversations.fold(0, (sum, c) => sum + c.unreadCount);

  Future<void> loadConversations() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await _api.getConversations();
      _conversations = (data['data'] as List)
          .map((c) => ConversationModel.fromJson(c))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void updateOnlineStatus(int userId, bool isOnline) {
    for (final conv in _conversations) {
      if (!conv.isGroup && conv.otherUserId == userId) {
        final idx = _conversations.indexOf(conv);
        _conversations[idx] = ConversationModel(
          id: conv.id,
          type: conv.type,
          name: conv.name,
          avatarUrl: conv.avatarUrl,
          isOnline: isOnline,
          otherUserId: conv.otherUserId,
          unreadCount: conv.unreadCount,
          participants: conv.participants,
          lastMessage: conv.lastMessage,
          updatedAt: conv.updatedAt,
        );
      }
    }
    notifyListeners();
  }

  void addOrUpdateConversation(ConversationModel conv) {
    final idx = _conversations.indexWhere((c) => c.id == conv.id);
    if (idx >= 0) {
      _conversations[idx] = conv;
    } else {
      _conversations.insert(0, conv);
    }
    _conversations.sort((a, b) =>
        (b.updatedAt ?? DateTime(0)).compareTo(a.updatedAt ?? DateTime(0)));
    notifyListeners();
  }

  void updateLastMessage(int conversationId, LastMessageModel msg,
      {String? avatarUrl, VoidCallback? onTap}) {
    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    if (idx >= 0) {
      _conversations[idx].lastMessage = msg;
      if (!msg.isMe) {
        _conversations[idx].unreadCount++;
        // ── Show in-app notification for received messages ────────
        NotificationService().showMessageNotification(
          conversationId: conversationId,
          senderName: msg.senderName ?? _conversations[idx].name,
          message: msg.preview,
          avatarUrl: avatarUrl ?? _conversations[idx].avatarUrl,
          onTap: onTap ?? () {},
        );
      }
      final conv = _conversations.removeAt(idx);
      _conversations.insert(0, conv);
      notifyListeners();
    }
  }

  void markConversationRead(int conversationId) {
    final idx = _conversations.indexWhere((c) => c.id == conversationId);
    if (idx >= 0) {
      _conversations[idx].unreadCount = 0;
      notifyListeners();
    }
  }

  Future<void> deleteConversation(int conversationId) async {
    try {
      await _api.deleteConversation(conversationId);
    } catch (_) {}
    _conversations.removeWhere((c) => c.id == conversationId);
    notifyListeners();
  }

  Future<void> archiveConversation(int conversationId, bool archive) async {
    try {
      await _api.archiveConversation(conversationId, archive);
    } catch (_) {}
    _conversations.removeWhere((c) => c.id == conversationId);
    notifyListeners();
  }
}
