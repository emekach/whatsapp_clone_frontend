// lib/screens/chat/chat_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/chat_theme_provider.dart';
import '../../services/api_service.dart';
import '../../utils/app_theme.dart';
import '../widgets/message_bubble.dart';
import 'media_preview_screen.dart';
import '../../services/notification_service.dart';

class ChatScreen extends StatefulWidget {
  final int conversationId;
  final String conversationName;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.conversationName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _api = ApiService();
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _picker = ImagePicker();

  List<MessageModel> _messages = [];
  bool _loading = true;
  bool _sending = false;
  int _lastMessageId = 0;
  MessageModel? _replyingTo;

  Timer? _pollTimer;
  Timer? _typingTimer;
  Timer? _pingTimer;

  bool _isTyping = false;
  List<dynamic> _typingUsers = [];
  ConversationModel? _conversation;
  bool _otherIsOnline = false;
  String _otherLastSeen = '';
  bool _showEmoji = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Tell notification service we're in this chat
    NotificationService().setActiveChatId(widget.conversationId);
    _loadConversation();
    _loadMessages();
    _startPolling();
    _startPingTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().markConversationRead(widget.conversationId);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Clear active chat so notifications show again
    NotificationService().setActiveChatId(null);
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _pollTimer?.cancel();
    _typingTimer?.cancel();
    _pingTimer?.cancel();
    _api.sendTyping(widget.conversationId, false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
      context.read<ChatProvider>().markConversationRead(widget.conversationId);
    } else {
      _pollTimer?.cancel();
    }
  }

  // ── Loading ───────────────────────────────────────────────────────

  Future<void> _loadConversation() async {
    try {
      final data = await _api.getConversation(widget.conversationId);
      if (mounted) {
        setState(() {
          _conversation = ConversationModel.fromJson(data['conversation']);
          _otherIsOnline = _conversation?.isOnline ?? false;
          _otherLastSeen = _conversation?.lastSeen ?? '';
        });
      }
    } catch (_) {}
  }

  Future<void> _loadMessages() async {
    try {
      final data = await _api.getMessages(widget.conversationId);
      final msgs = (data['data'] as List)
          .map((m) => MessageModel.fromJson(m))
          .toList()
          .reversed
          .toList();
      if (mounted) {
        setState(() {
          _messages = msgs;
          _lastMessageId = msgs.isNotEmpty ? msgs.last.id : 0;
          _loading = false;
        });
        _scrollToBottom(animate: false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  Future<void> _poll() async {
    try {
      final data = await _api.pollMessages(widget.conversationId,
          lastId: _lastMessageId);
      if (!mounted) return;

      final newMsgs = (data['messages'] as List)
          .map((m) => MessageModel.fromJson(m))
          .toList();

      if (newMsgs.isNotEmpty) {
        setState(() {
          _messages.addAll(newMsgs);
          _lastMessageId = newMsgs.last.id;
        });
        _scrollToBottom();
        final last = newMsgs.last;
        context.read<ChatProvider>().updateLastMessage(
            widget.conversationId,
            LastMessageModel.fromJson({
              'id': last.id,
              'type': last.type,
              'content': last.content,
              'sender_id': last.sender.id,
              'sender_name': last.sender.name,
              'created_at': last.createdAt.toIso8601String(),
              'is_mine': last.isMe,
              'is_read': last.isRead,
            }),
            avatarUrl: last.sender.avatarUrl,
            onTap: () => context.go('/chat/\${widget.conversationId}',
                extra: widget.conversationName));
        context
            .read<ChatProvider>()
            .markConversationRead(widget.conversationId);
      }

      setState(() => _typingUsers = data['typing_users'] as List? ?? []);

      final participants = data['participants'] as List? ?? [];
      if (participants.isNotEmpty) {
        setState(() {
          _otherIsOnline = participants.first['is_online'] ?? false;
          _otherLastSeen = participants.first['last_seen'] ?? '';
        });
      }
    } catch (_) {}
  }

  void _startPingTimer() {
    _pingTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _api.ping());
    _api.ping();
  }

  // ── Send ──────────────────────────────────────────────────────────

  Future<void> _sendText() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;
    _msgCtrl.clear();
    _api.sendTyping(widget.conversationId, false);
    setState(() => _sending = true);
    try {
      final data = await _api.sendTextMessage(widget.conversationId, text,
          replyToId: _replyingTo?.id);
      _onMessageSent(MessageModel.fromJson(data['message']), text);
    } catch (_) {
      setState(() => _sending = false);
    }
  }

  Future<void> _sendImage({bool fromCamera = false}) async {
    final result = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 92,
    );
    if (result == null) return;

    // Show preview screen with caption
    final res = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
          builder: (_) => MediaPreviewScreen(
                filePath: result.path,
                type: MediaPreviewType.image,
                fileName: result.name,
                contactName: widget.conversationName,
              )),
    );
    if (res == null) return;

    setState(() => _sending = true);
    try {
      final data = await _api.sendFileMessage(
          widget.conversationId, res['path'], 'image',
          filename: result.name,
          caption: res['caption']?.isNotEmpty == true ? res['caption'] : null);
      _onMessageSent(MessageModel.fromJson(data['message']),
          res['caption']?.isNotEmpty == true ? res['caption'] : '📷 Photo');
    } catch (_) {
      setState(() => _sending = false);
    }
  }

  Future<void> _sendVideo() async {
    final result = await _picker.pickVideo(source: ImageSource.gallery);
    if (result == null) return;

    // Show preview screen
    final res = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
          builder: (_) => MediaPreviewScreen(
                filePath: result.path,
                type: MediaPreviewType.video,
                fileName: result.name,
                contactName: widget.conversationName,
              )),
    );
    if (res == null) return;

    setState(() => _sending = true);
    try {
      final data = await _api.sendFileMessage(
          widget.conversationId, res['path'], 'video',
          filename: result.name,
          caption: res['caption']?.isNotEmpty == true ? res['caption'] : null);
      _onMessageSent(MessageModel.fromJson(data['message']),
          res['caption']?.isNotEmpty == true ? res['caption'] : '🎥 Video');
    } catch (_) {
      setState(() => _sending = false);
    }
  }

  Future<void> _sendDocument() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.any,
    );
    if (result == null || result.files.single.path == null) return;
    final file = result.files.single;

    // Show preview screen
    final res = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
          builder: (_) => MediaPreviewScreen(
                filePath: file.path!,
                type: MediaPreviewType.document,
                fileName: file.name,
                fileSize: file.size,
                contactName: widget.conversationName,
              )),
    );
    if (res == null) return;

    setState(() => _sending = true);
    try {
      final data = await _api.sendFileMessage(
          widget.conversationId, res['path'], 'document',
          filename: file.name,
          caption: res['caption']?.isNotEmpty == true ? res['caption'] : null);
      _onMessageSent(
          MessageModel.fromJson(data['message']),
          res['caption']?.isNotEmpty == true
              ? res['caption']
              : '📄 ${file.name}');
    } catch (_) {
      setState(() => _sending = false);
    }
  }

  void _onMessageSent(MessageModel msg, String preview) {
    if (!mounted) return;
    setState(() {
      _messages.add(msg);
      _lastMessageId = msg.id;
      _replyingTo = null;
      _sending = false;
    });
    _scrollToBottom();
    context.read<ChatProvider>().updateLastMessage(
        widget.conversationId,
        LastMessageModel.fromJson({
          'id': msg.id,
          'type': msg.type,
          'content': preview,
          'sender_id': msg.sender.id,
          'sender_name': msg.sender.name,
          'created_at': msg.createdAt.toIso8601String(),
          'is_mine': true,
          'is_read': false,
        }));
  }

  void _onTypingChanged(String text) {
    _typingTimer?.cancel();
    if (text.isNotEmpty) {
      if (!_isTyping) {
        _isTyping = true;
        _api.sendTyping(widget.conversationId, true);
      }
      _typingTimer = Timer(const Duration(seconds: 2), () {
        _isTyping = false;
        _api.sendTyping(widget.conversationId, false);
      });
    } else {
      _isTyping = false;
      _api.sendTyping(widget.conversationId, false);
    }
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        if (animate) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        } else {
          _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
        }
      }
    });
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AttachmentSheet(
        onCamera: () {
          Navigator.pop(context);
          _sendImage(fromCamera: true);
        },
        onGallery: () {
          Navigator.pop(context);
          _sendImage();
        },
        onVideo: () {
          Navigator.pop(context);
          _sendVideo();
        },
        onDocument: () {
          Navigator.pop(context);
          _sendDocument();
        },
      ),
    );
  }

  void _showWallpaperPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WallpaperSheet(
        onSelect: (id) {
          context.read<ChatThemeProvider>().setBackground(id);
          Navigator.pop(context);
        },
        currentId: context.read<ChatThemeProvider>().selectedBgId,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chatTheme = context.watch<ChatThemeProvider>();

    return PopScope(
      canPop: !_showEmoji,
      onPopInvoked: (didPop) {
        if (!didPop && _showEmoji) setState(() => _showEmoji = false);
      },
      child: Scaffold(
        appBar: _buildAppBar(isDark),
        body: Stack(
          children: [
            // Background
            Positioned.fill(child: chatTheme.buildBackground(context)),

            // Content
            Column(
              children: [
                // Messages
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppTheme.primary))
                      : _messages.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                              controller: _scrollCtrl,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 8),
                              itemCount: _messages.length,
                              itemBuilder: (_, i) {
                                final msg = _messages[i];
                                final showDate = i == 0 ||
                                    !_isSameDay(_messages[i - 1].createdAt,
                                        msg.createdAt);
                                return Column(
                                  children: [
                                    if (showDate)
                                      _DateChip(date: msg.createdAt),
                                    MessageBubble(
                                      message: msg,
                                      isGroup: _conversation?.isGroup ?? false,
                                      onReply: () =>
                                          setState(() => _replyingTo = msg),
                                      onDelete: () async {
                                        await _api.deleteMessage(msg.id);
                                        setState(() {
                                          _messages[i] = MessageModel(
                                            id: msg.id,
                                            type: msg.type,
                                            isDeleted: true,
                                            isMe: msg.isMe,
                                            isRead: msg.isRead,
                                            createdAt: msg.createdAt,
                                            sender: msg.sender,
                                          );
                                        });
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                ),

                // Typing indicator
                if (_typingUsers.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        _TypingDots(),
                        const SizedBox(width: 8),
                        Text(
                          '${_typingUsers.map((u) => u['user_name']).join(', ')} is typing',
                          style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black45,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Reply bar
                if (_replyingTo != null) _buildReplyBar(isDark),

                // Input
                _InputBar(
                  controller: _msgCtrl,
                  sending: _sending,
                  showEmoji: _showEmoji,
                  onEmojiToggle: () {
                    if (!_showEmoji) FocusScope.of(context).unfocus();
                    setState(() => _showEmoji = !_showEmoji);
                  },
                  onSend: _sendText,
                  onAttach: _showAttachmentSheet,
                  onCameraImage: () => _sendImage(fromCamera: true),
                  onTyping: _onTypingChanged,
                  onSendVoice: (path, duration) async {
                    setState(() => _sending = true);
                    try {
                      final data = await _api.sendFileMessage(
                        widget.conversationId,
                        path,
                        'audio',
                        filename: 'voice.m4a',
                        duration: duration,
                      );
                      _onMessageSent(MessageModel.fromJson(data['message']),
                          '🎤 Voice message');
                    } catch (_) {
                      setState(() => _sending = false);
                    }
                  },
                ),

                // Emoji picker
                if (_showEmoji)
                  SizedBox(
                    height: 280,
                    child: EmojiPicker(
                      onEmojiSelected: (_, emoji) {
                        final pos = _msgCtrl.selection.baseOffset;
                        final text = _msgCtrl.text;
                        final newText = pos < 0
                            ? text + emoji.emoji
                            : text.substring(0, pos) +
                                emoji.emoji +
                                text.substring(pos);
                        _msgCtrl.value = TextEditingValue(
                          text: newText,
                          selection: TextSelection.collapsed(
                              offset: pos < 0
                                  ? newText.length
                                  : pos + emoji.emoji.length),
                        );
                      },
                      config: Config(
                        emojiViewConfig: EmojiViewConfig(
                          backgroundColor: isDark
                              ? AppTheme.darkSurface
                              : const Color(0xFFF8F8F8),
                          columns: 8,
                          emojiSizeMax: 26,
                        ),
                        categoryViewConfig: CategoryViewConfig(
                          backgroundColor:
                              isDark ? AppTheme.darkCard : Colors.white,
                          indicatorColor: AppTheme.primary,
                          iconColorSelected: AppTheme.primary,
                          iconColor:
                              isDark ? Colors.white38 : Colors.grey.shade500,
                          tabIndicatorAnimDuration: kTabScrollDuration,
                        ),
                        searchViewConfig: SearchViewConfig(
                          backgroundColor: isDark
                              ? AppTheme.darkSurface
                              : const Color(0xFFF8F8F8),
                          buttonIconColor:
                              isDark ? Colors.white54 : Colors.grey,
                        ),
                        checkPlatformCompatibility: true,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(bool isDark) {
    return AppBar(
      titleSpacing: 0,
      backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.primaryDark,
      foregroundColor: Colors.white,
      leadingWidth: 56,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.pop(),
      ),
      title: InkWell(
        onTap: () {},
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.white24,
              backgroundImage: _conversation?.avatarUrl != null
                  ? CachedNetworkImageProvider(_conversation!.avatarUrl!)
                  : null,
              child: _conversation?.avatarUrl == null
                  ? Text(
                      widget.conversationName.isNotEmpty
                          ? widget.conversationName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold))
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _conversation?.name ?? widget.conversationName,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _typingUsers.isNotEmpty
                        ? 'typing...'
                        : (_otherIsOnline ? 'online' : _otherLastSeen),
                    style: TextStyle(
                      fontSize: 12,
                      color: _typingUsers.isNotEmpty || _otherIsOnline
                          ? Colors.greenAccent.shade100
                          : Colors.white60,
                      fontStyle: _typingUsers.isNotEmpty
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(icon: const Icon(Icons.videocam_rounded), onPressed: () {}),
        IconButton(icon: const Icon(Icons.call_rounded), onPressed: () {}),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (val) {
            if (val == 'wallpaper') _showWallpaperPicker();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
                value: 'wallpaper', child: Text('Change wallpaper')),
            const PopupMenuItem(value: 'search', child: Text('Search')),
            const PopupMenuItem(
                value: 'mute', child: Text('Mute notifications')),
            const PopupMenuItem(value: 'clear', child: Text('Clear chat')),
          ],
        ),
      ],
    );
  }

  Widget _buildReplyBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            const Border(left: BorderSide(color: AppTheme.primary, width: 4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _replyingTo!.sender.name,
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  _replyingTo!.content ??
                      (_replyingTo!.type == 'audio'
                          ? '🎤 Voice message'
                          : _replyingTo!.type == 'image'
                              ? '📷 Photo'
                              : '📄 Document'),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? Colors.white60 : Colors.black54,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () => setState(() => _replyingTo = null),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.07),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Icon(Icons.lock_outline_rounded,
                    size: 28, color: Colors.grey),
                const SizedBox(height: 8),
                const Text(
                  'Messages are end-to-end encrypted.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  'Say hello to ${_conversation?.name ?? widget.conversationName}! 👋',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.day == b.day && a.month == b.month && a.year == b.year;
}

// ── Date Chip ─────────────────────────────────────────────────────────────

class _DateChip extends StatelessWidget {
  final DateTime date;
  const _DateChip({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    String label;
    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      label = 'Today';
    } else if (now.difference(date).inDays == 1) {
      label = 'Yesterday';
    } else {
      label = DateFormat('MMMM d, yyyy').format(date);
    }

    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white,
            shadows: [
              Shadow(color: Colors.black26, blurRadius: 4),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Typing Dots ───────────────────────────────────────────────────────────

class _TypingDots extends StatefulWidget {
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          children: List.generate(3, (i) {
            final delay = i * 0.33;
            final val = ((_ctrl.value - delay) % 1.0).clamp(0.0, 1.0);
            final offset = val < 0.5 ? val * 2 : (1 - val) * 2;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 6,
              height: 6,
              transform: Matrix4.translationValues(0, -offset * 4, 0),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}

// ── Input Bar ─────────────────────────────────────────────────────────────

class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final bool sending;
  final bool showEmoji;
  final VoidCallback onEmojiToggle;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onCameraImage;
  final ValueChanged<String> onTyping;
  final Function(String path, int dur) onSendVoice;

  const _InputBar({
    required this.controller,
    required this.sending,
    required this.showEmoji,
    required this.onEmojiToggle,
    required this.onSend,
    required this.onAttach,
    required this.onCameraImage,
    required this.onTyping,
    required this.onSendVoice,
  });

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar>
    with SingleTickerProviderStateMixin {
  final _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _hasText = false;
  DateTime? _recordStart;
  Timer? _recordTimer;
  String _recordDuration = '0:00';
  late AnimationController _micAnim;

  @override
  void initState() {
    super.initState();
    _micAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    widget.controller.addListener(() {
      final has = widget.controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _recorder.dispose();
    _recordTimer?.cancel();
    _micAnim.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) return;
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    _recordStart = DateTime.now();
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 128000),
      path: path,
    );
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_recordStart == null) return;
      final diff = DateTime.now().difference(_recordStart!);
      setState(() => _recordDuration =
          '${diff.inMinutes}:${(diff.inSeconds % 60).toString().padLeft(2, '0')}');
    });
    setState(() => _isRecording = true);
  }

  Future<void> _stopRecording() async {
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    setState(() {
      _isRecording = false;
      _recordDuration = '0:00';
    });
    if (path != null && _recordStart != null) {
      final dur = DateTime.now().difference(_recordStart!).inSeconds;
      if (dur >= 1) widget.onSendVoice(path, dur);
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    await _recorder.cancel();
    setState(() {
      _isRecording = false;
      _recordDuration = '0:00';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child:
            _isRecording ? _buildRecordingBar(isDark) : _buildNormalBar(isDark),
      ),
    );
  }

  Widget _buildRecordingBar(bool isDark) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)
        ],
      ),
      child: Row(
        children: [
          // Cancel
          GestureDetector(
            onTap: _cancelRecording,
            child: const Icon(Icons.delete_outline_rounded,
                color: Colors.red, size: 26),
          ),
          const SizedBox(width: 12),

          // Pulse mic icon
          AnimatedBuilder(
            animation: _micAnim,
            builder: (_, __) => Icon(
              Icons.mic_rounded,
              color:
                  Color.lerp(Colors.red, Colors.red.shade800, _micAnim.value),
              size: 22,
            ),
          ),
          const SizedBox(width: 8),

          // Duration
          Text(
            _recordDuration,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w600, color: Colors.red),
          ),
          const SizedBox(width: 8),

          // Slide hint
          Expanded(
            child: Row(
              children: [
                const Icon(Icons.keyboard_arrow_left,
                    color: Colors.grey, size: 18),
                Text(
                  'Slide to cancel',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              ],
            ),
          ),

          // Send button
          GestureDetector(
            onTap: _stopRecording,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                  color: AppTheme.primary, shape: BoxShape.circle),
              child:
                  const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNormalBar(bool isDark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Text field
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 6)
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Emoji button
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: IconButton(
                    icon: Icon(
                        widget.showEmoji
                            ? Icons.keyboard_rounded
                            : Icons.emoji_emotions_outlined,
                        color: Colors.grey.shade500,
                        size: 24),
                    onPressed: widget.onEmojiToggle,
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                  ),
                ),

                // Text input
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    onChanged: widget.onTyping,
                    maxLines: 6,
                    minLines: 1,
                    onTap: () {
                      if (widget.showEmoji) widget.onEmojiToggle();
                    },
                    decoration: const InputDecoration(
                      hintText: 'Message',
                      border: InputBorder.none,
                      contentPadding:
                          EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                    ),
                    style: const TextStyle(fontSize: 15),
                  ),
                ),

                // Attach + camera
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.attach_file_rounded,
                          color: Colors.grey.shade500, size: 22),
                      onPressed: widget.onAttach,
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    ),
                    if (!_hasText)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: IconButton(
                          icon: Icon(Icons.camera_alt_rounded,
                              color: Colors.grey.shade500, size: 22),
                          onPressed: widget.onCameraImage,
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Send / Mic FAB
        GestureDetector(
          onTap: _hasText ? widget.onSend : null,
          onLongPress: _hasText ? null : _startRecording,
          onLongPressEnd: _hasText ? null : (_) => _stopRecording(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: widget.sending
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Icon(
                    _hasText ? Icons.send_rounded : Icons.mic_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
          ),
        ),
      ],
    );
  }
}

// ── Attachment Sheet ──────────────────────────────────────────────────────

class _AttachmentSheet extends StatelessWidget {
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback onVideo;
  final VoidCallback onDocument;

  const _AttachmentSheet({
    required this.onCamera,
    required this.onGallery,
    required this.onVideo,
    required this.onDocument,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Share',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _AttachOption(
                icon: Icons.camera_alt_rounded,
                label: 'Camera',
                color: const Color(0xFFFF6584),
                onTap: onCamera,
              ),
              _AttachOption(
                icon: Icons.photo_library_rounded,
                label: 'Gallery',
                color: const Color(0xFF7C4DFF),
                onTap: onGallery,
              ),
              _AttachOption(
                icon: Icons.videocam_rounded,
                label: 'Video',
                color: const Color(0xFF00B0FF),
                onTap: onVideo,
              ),
              _AttachOption(
                icon: Icons.insert_drive_file_rounded,
                label: 'Document',
                color: const Color(0xFF00C853),
                onTap: onDocument,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.3), width: 1.5),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Wallpaper Sheet ───────────────────────────────────────────────────────

class _WallpaperSheet extends StatelessWidget {
  final Function(String) onSelect;
  final String currentId;

  const _WallpaperSheet({
    required this.onSelect,
    required this.currentId,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      margin: const EdgeInsets.only(top: 60),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Text(
            'Chat Wallpaper',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.65,
              ),
              itemCount: ChatThemeProvider.backgrounds.length,
              itemBuilder: (_, i) {
                final bg = ChatThemeProvider.backgrounds[i];
                final selected = bg.id == currentId;
                return GestureDetector(
                  onTap: () => onSelect(bg.id),
                  child: Stack(
                    children: [
                      // Preview
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: bg.solidColor,
                          gradient: bg.gradientColors != null
                              ? LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: bg.gradientColors!,
                                )
                              : null,
                          border: selected
                              ? Border.all(color: AppTheme.primary, width: 3)
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            // Simulated chat bubbles
                            Positioned(
                              right: 12,
                              top: 20,
                              child:
                                  _MiniChatBubble(isMe: true, text: 'Hey! 👋'),
                            ),
                            Positioned(
                              left: 12,
                              top: 58,
                              child: _MiniChatBubble(
                                  isMe: false, text: 'Hi there!'),
                            ),
                            Positioned(
                              right: 12,
                              top: 96,
                              child: _MiniChatBubble(
                                  isMe: true, text: 'How are you?'),
                            ),
                          ],
                        ),
                      ),
                      // Label
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: const BorderRadius.only(
                              bottomLeft: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                          ),
                          child: Text(
                            bg.label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      // Selected checkmark
                      if (selected)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: const BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_rounded,
                                color: Colors.white, size: 14),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _MiniChatBubble extends StatelessWidget {
  final bool isMe;
  final String text;
  const _MiniChatBubble({required this.isMe, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      constraints: const BoxConstraints(maxWidth: 80),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFFD9FDD3) : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(8),
          topRight: const Radius.circular(8),
          bottomLeft: Radius.circular(isMe ? 8 : 2),
          bottomRight: Radius.circular(isMe ? 2 : 8),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 7, color: Colors.black87),
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
