// lib/screens/widgets/message_bubble.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:just_audio/just_audio.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../utils/app_theme.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isGroup;
  final VoidCallback onReply;
  final VoidCallback onDelete;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isGroup,
    required this.onReply,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = context.read<AuthProvider>().user;
    final isMe = currentUser != null
        ? message.sender.id == currentUser.id
        : message.isMe;

    // ── Bubble colors ──────────────────────────────────────────────
    final bool isMediaType =
        ['image', 'audio', 'video', 'document'].contains(message.type);

    final Color bubbleColor;
    final Color textColor;
    final Color subTextColor;

    if (isMe) {
      if (isDark) {
        bubbleColor = const Color(0xFF005C4B);
        textColor = Colors.white;
        subTextColor = Colors.white54;
      } else if (isMediaType) {
        // Rich green for media in light mode
        bubbleColor = const Color(0xFF00A884);
        textColor = Colors.white;
        subTextColor = Colors.white70;
      } else {
        // Pale green for text only
        bubbleColor = const Color(0xFFD9FDD3);
        textColor = const Color(0xFF111B21);
        subTextColor = const Color(0xFF667781);
      }
    } else {
      bubbleColor = isDark ? const Color(0xFF1F2C34) : Colors.white;
      textColor = isDark ? Colors.white : const Color(0xFF111B21);
      subTextColor = isDark ? Colors.white54 : const Color(0xFF667781);
    }

    return GestureDetector(
      onLongPress: () => _showOptions(context, isMe),
      child: Padding(
        padding: EdgeInsets.only(
          left: isMe ? 64 : 8,
          right: isMe ? 8 : 64,
          top: 1,
          bottom: 1,
        ),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Group avatar
            if (!isMe && isGroup)
              Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 2),
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: _senderColor(message.sender.id),
                  backgroundImage: message.sender.avatarUrl != null
                      ? CachedNetworkImageProvider(message.sender.avatarUrl!)
                      : null,
                  child: message.sender.avatarUrl == null
                      ? Text(
                          message.sender.name.isNotEmpty
                              ? message.sender.name[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold))
                      : null,
                ),
              ),

            // Bubble
            Flexible(
              child: Container(
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                // For image messages use tight padding
                padding: EdgeInsets.only(
                  left: message.type == 'image' ? 4 : 10,
                  right: message.type == 'image' ? 4 : 10,
                  top: message.type == 'image' ? 4 : 8,
                  bottom: 4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Group sender name
                    if (!isMe && isGroup)
                      Padding(
                        padding:
                            const EdgeInsets.only(left: 6, top: 2, bottom: 3),
                        child: Text(
                          message.sender.name,
                          style: TextStyle(
                            color: _senderColor(message.sender.id),
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                      ),

                    // Reply preview
                    if (message.replyTo != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 0, 0, 6),
                        child: _ReplyPreview(
                            reply: message.replyTo!, isDark: isDark),
                      ),

                    // Content
                    _buildContent(
                        context, isMe, isDark, textColor, subTextColor),

                    // Time + ticks row
                    Padding(
                      padding: EdgeInsets.only(
                        left: message.type == 'image' ? 6 : 0,
                        right: message.type == 'image' ? 4 : 0,
                        top: 3,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            DateFormat('HH:mm').format(message.createdAt),
                            style: TextStyle(
                              fontSize: 10.5,
                              color: message.type == 'image'
                                  ? Colors.white70
                                  : subTextColor,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 3),
                            _buildTick(message.isRead,
                                isImage: message.type == 'image'),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tick builder ──────────────────────────────────────────────────

  Widget _buildTick(bool isRead, {bool isImage = false}) {
    if (isRead) {
      // Blue double tick — read
      return Icon(
        Icons.done_all_rounded,
        size: 15,
        color: isImage ? Colors.white : const Color(0xFF53BDEB),
      );
    } else {
      // Grey double tick — delivered (we show double by default after send)
      return Icon(
        Icons.done_all_rounded,
        size: 15,
        color: isImage ? Colors.white70 : Colors.grey.shade400,
      );
    }
  }

  // ── Sender color for group ─────────────────────────────────────────

  Color _senderColor(int id) {
    const colors = [
      Color(0xFF25D366),
      Color(0xFF34B7F1),
      Color(0xFFFF6B6B),
      Color(0xFFFFB347),
      Color(0xFFAB83FF),
      Color(0xFF40E0D0),
      Color(0xFFFF85A1),
      Color(0xFF72EFDD),
    ];
    return colors[id % colors.length];
  }

  // ── Content builder ───────────────────────────────────────────────

  Widget _buildContent(BuildContext context, bool isMe, bool isDark,
      Color textColor, Color subTextColor) {
    if (message.isDeleted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block_rounded, size: 14, color: subTextColor),
          const SizedBox(width: 5),
          Text(
            'This message was deleted',
            style: TextStyle(
              color: subTextColor,
              fontStyle: FontStyle.italic,
              fontSize: 13.5,
            ),
          ),
        ],
      );
    }

    switch (message.type) {
      // ── Image ──────────────────────────────────────────────────────
      case 'image':
        return Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CachedNetworkImage(
                imageUrl: message.fileUrl ?? '',
                width: 240,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: 240,
                  height: 200,
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                  child: const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primary, strokeWidth: 2)),
                ),
                errorWidget: (_, __, ___) => Container(
                  width: 240,
                  height: 140,
                  color: isDark ? Colors.white10 : Colors.grey.shade200,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image_outlined,
                          color: Colors.grey.shade400, size: 36),
                      const SizedBox(height: 8),
                      Text('Image unavailable',
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 11)),
                    ],
                  ),
                ),
              ),
            ),
            // Caption overlay at bottom of image
            if (message.content != null && message.content!.isNotEmpty)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 20, 8, 6),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Text(
                    message.content!,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                  ),
                ),
              ),
          ],
        );

      // ── Audio ──────────────────────────────────────────────────────
      case 'audio':
        return _AudioBubble(
          fileUrl: message.fileUrl ?? '',
          duration: message.duration ?? 0,
          isMe: isMe,
          isDark: isDark,
        );

      // ── Video ──────────────────────────────────────────────────────
      case 'video':
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 240,
                height: 160,
                color: Colors.black,
                child: Icon(
                  Icons.movie_rounded,
                  color: Colors.white.withOpacity(0.2),
                  size: 64,
                ),
              ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white70, width: 2),
                ),
                child: const Icon(Icons.play_arrow_rounded,
                    color: Colors.white, size: 34),
              ),
              // Duration badge
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam_rounded,
                          color: Colors.white, size: 12),
                      const SizedBox(width: 3),
                      Text(
                        message.duration != null
                            ? '${message.duration! ~/ 60}:${(message.duration! % 60).toString().padLeft(2, '0')}'
                            : 'Video',
                        style:
                            const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );

      // ── Document ───────────────────────────────────────────────────
      case 'document':
        return _DocumentBubble(
          fileName: message.fileName ?? 'Document',
          fileSize: message.fileSize,
          isMe: isMe,
          isDark: isDark,
          subColor: subTextColor,
        );

      // ── Text ───────────────────────────────────────────────────────
      default:
        return Text(
          message.content ?? '',
          style: TextStyle(
            fontSize: 15,
            height: 1.35,
            color: textColor,
          ),
        );
    }
  }

  void _showOptions(BuildContext context, bool isMe) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Emoji reaction row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: ['❤️', '😂', '😮', '😢', '🙏', '👍']
                    .map((e) => GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.06)
                                  : Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child:
                                  Text(e, style: const TextStyle(fontSize: 24)),
                            ),
                          ),
                        ))
                    .toList(),
              ),
            ),
            const Divider(height: 1),

            // Actions
            _optionTile(context, Icons.reply_rounded, 'Reply', AppTheme.primary,
                () {
              Navigator.pop(context);
              onReply();
            }),
            if (message.type == 'text' || message.type == null)
              _optionTile(context, Icons.copy_rounded, 'Copy',
                  isDark ? Colors.white : Colors.black87, () {
                Navigator.pop(context);
                Clipboard.setData(ClipboardData(text: message.content ?? ''));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied to clipboard'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }),
            _optionTile(
                context,
                Icons.forward_rounded,
                'Forward',
                isDark ? Colors.white : Colors.black87,
                () => Navigator.pop(context)),
            _optionTile(
                context,
                Icons.star_border_rounded,
                'Star message',
                isDark ? Colors.white : Colors.black87,
                () => Navigator.pop(context)),
            if (isMe)
              _optionTile(
                  context, Icons.delete_outline_rounded, 'Delete', Colors.red,
                  () {
                Navigator.pop(context);
                onDelete();
              }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _optionTile(BuildContext context, IconData icon, String label,
      Color color, VoidCallback onTap) {
    return ListTile(
      dense: true,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label,
          style: TextStyle(
              fontWeight: FontWeight.w500, fontSize: 15, color: color)),
      onTap: onTap,
    );
  }
}

// ── Reply Preview ─────────────────────────────────────────────────────────

class _ReplyPreview extends StatelessWidget {
  final ReplyModel reply;
  final bool isDark;
  const _ReplyPreview({required this.reply, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.08)
            : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border:
            const Border(left: BorderSide(color: AppTheme.primary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            reply.sender,
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            reply.content ?? '',
            style: TextStyle(
              fontSize: 12.5,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Document Bubble ───────────────────────────────────────────────────────

class _DocumentBubble extends StatelessWidget {
  final String fileName;
  final int? fileSize;
  final bool isMe;
  final bool isDark;
  final Color subColor;

  const _DocumentBubble({
    required this.fileName,
    this.fileSize,
    required this.isMe,
    required this.isDark,
    required this.subColor,
  });

  Color _extColor(String ext) {
    switch (ext) {
      case 'PDF':
        return const Color(0xFFE53935);
      case 'DOC':
      case 'DOCX':
        return const Color(0xFF1565C0);
      case 'XLS':
      case 'XLSX':
        return const Color(0xFF2E7D32);
      case 'PPT':
      case 'PPTX':
        return const Color(0xFFE65100);
      case 'ZIP':
      case 'RAR':
      case '7Z':
        return const Color(0xFF6A1B9A);
      case 'MP3':
      case 'AAC':
      case 'WAV':
        return const Color(0xFF00838F);
      case 'TXT':
        return const Color(0xFF546E7A);
      default:
        return AppTheme.primary;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toUpperCase()
        : 'FILE';
    final extColor = _extColor(ext);

    return Container(
      width: 240,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        // NEW
        color: isMe
            ? Colors.white.withOpacity(0.18)
            : (isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade100),
        border: Border.all(
          color: isMe
              ? Colors.white.withOpacity(0.25)
              : Colors.grey.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // File type icon
          Container(
            width: 46,
            height: 54,
            decoration: BoxDecoration(
              color: extColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: extColor.withOpacity(0.25), width: 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.insert_drive_file_rounded,
                    color: extColor, size: 22),
                const SizedBox(height: 2),
                Text(
                  ext.length > 4 ? ext.substring(0, 4) : ext,
                  style: TextStyle(
                    color: extColor,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // File info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isMe
                        ? Colors.white
                        : (isDark ? Colors.white : Colors.black87),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
                const SizedBox(height: 3),
                if (fileSize != null)
                  Text(
                    _formatSize(fileSize!),
                    style: TextStyle(
                      fontSize: 11,
                      color: subColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Download icon
          Icon(
            Icons.download_rounded,
            size: 22,
            color: isMe ? Colors.white60 : AppTheme.primary,
          ),
        ],
      ),
    );
  }
}

// ── Audio Bubble ──────────────────────────────────────────────────────────

class _AudioBubble extends StatefulWidget {
  final String fileUrl;
  final int duration;
  final bool isMe;
  final bool isDark;

  const _AudioBubble({
    required this.fileUrl,
    required this.duration,
    required this.isMe,
    required this.isDark,
  });

  @override
  State<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<_AudioBubble> {
  final _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  bool _isLoaded = false;
  Duration _position = Duration.zero;
  Duration _total = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (widget.duration > 0) {
      _total = Duration(seconds: widget.duration);
    }

    _player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state.playing;
        _isLoading = state.processingState == ProcessingState.loading ||
            state.processingState == ProcessingState.buffering;
      });
      if (state.processingState == ProcessingState.completed) {
        _player.seek(Duration.zero);
        _player.stop();
        if (mounted) {
          setState(() {
            _isPlaying = false;
            _position = Duration.zero;
          });
        }
      }
    });

    _player.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });

    _player.durationStream.listen((dur) {
      if (mounted && dur != null && dur.inSeconds > 0) {
        setState(() => _total = dur);
      }
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
      return;
    }
    try {
      if (!_isLoaded) {
        setState(() => _isLoading = true);
        await _player.setUrl(widget.fileUrl);
        setState(() {
          _isLoaded = true;
          _isLoading = false;
        });
      }
      await _player.play();
    } catch (_) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not play audio')));
      }
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final isMe = widget.isMe;
    final isDark = widget.isDark;

    // NEW — also works on light green sent bubble
    final activeColor =
        isMe ? (isDark ? Colors.white : Colors.white) : AppTheme.primary;
    final inactiveColor = isMe
        ? Colors.white.withOpacity(0.35)
        : (isDark ? Colors.white24 : Colors.grey.shade300);

    final progress = _total.inMilliseconds > 0
        ? (_position.inMilliseconds / _total.inMilliseconds)
            .clamp(0.0, 1.0)
            .toDouble()
        : 0.0;

    return Container(
      width: 230,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Play button
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isMe
                    ? Colors.white.withOpacity(0.2)
                    : AppTheme.primary.withOpacity(0.12),
                border: Border.all(
                  color: isMe
                      ? Colors.white.withOpacity(0.3)
                      : AppTheme.primary.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: _isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: activeColor))
                  : Icon(
                      _isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: activeColor,
                      size: 28,
                    ),
            ),
          ),
          const SizedBox(width: 10),

          // Waveform + time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Waveform
                Row(
                  children: List.generate(24, (i) {
                    final heights = [
                      5.0,
                      10.0,
                      7.0,
                      16.0,
                      9.0,
                      13.0,
                      5.0,
                      18.0,
                      7.0,
                      14.0,
                      9.0,
                      16.0,
                      5.0,
                      12.0,
                      7.0,
                      18.0,
                      9.0,
                      11.0,
                      5.0,
                      16.0,
                      7.0,
                      9.0,
                      5.0,
                      13.0,
                    ];
                    final filled = i / 24 <= progress;
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 0.8),
                        height: heights[i],
                        decoration: BoxDecoration(
                          color: filled ? activeColor : inactiveColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isPlaying || _position.inSeconds > 0
                          ? _fmt(_position)
                          : _fmt(_total),
                      style: TextStyle(
                        fontSize: 11,
                        color: isMe ? Colors.white60 : Colors.grey.shade500,
                      ),
                    ),
                    Icon(
                      Icons.mic_rounded,
                      size: 14,
                      color: isMe ? Colors.white38 : Colors.grey.shade400,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
