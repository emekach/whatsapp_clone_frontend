// lib/screens/chat/media_preview_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../utils/app_theme.dart';

enum MediaPreviewType { image, video, document }

class MediaPreviewScreen extends StatefulWidget {
  final String filePath;
  final MediaPreviewType type;
  final String fileName;
  final int? fileSize;
  final String contactName;

  const MediaPreviewScreen({
    super.key,
    required this.filePath,
    required this.type,
    required this.fileName,
    required this.contactName,
    this.fileSize,
  });

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  final _captionCtrl = TextEditingController();
  bool _captionFocused = false;

  @override
  void dispose() {
    _captionCtrl.dispose();
    super.dispose();
  }

  void _send() {
    Navigator.of(context).pop({
      'path': widget.filePath,
      'caption': _captionCtrl.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.contactName,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (widget.type == MediaPreviewType.image) ...[
            IconButton(
              icon: const Icon(Icons.crop_rotate_rounded),
              onPressed: () {},
              tooltip: 'Crop',
            ),
            IconButton(
              icon: const Icon(Icons.text_fields_rounded),
              onPressed: () {},
              tooltip: 'Add text',
            ),
            IconButton(
              icon: const Icon(Icons.draw_rounded),
              onPressed: () {},
              tooltip: 'Draw',
            ),
            IconButton(
              icon: const Icon(Icons.emoji_emotions_outlined),
              onPressed: () {},
              tooltip: 'Sticker',
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // ── Media preview ─────────────────────────────────────────
          Expanded(
            child: widget.type == MediaPreviewType.image
                ? _ImagePreview(filePath: widget.filePath)
                : widget.type == MediaPreviewType.video
                    ? _VideoPreview(filePath: widget.filePath)
                    : _DocumentPreview(
                        fileName: widget.fileName,
                        fileSize: widget.fileSize,
                      ),
          ),

          // ── Caption bar ───────────────────────────────────────────
          _CaptionBar(
            controller: _captionCtrl,
            type: widget.type,
            onFocusChange: (f) => setState(() => _captionFocused = f),
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

// ── Image Preview ─────────────────────────────────────────────────────────

class _ImagePreview extends StatefulWidget {
  final String filePath;
  const _ImagePreview({required this.filePath});

  @override
  State<_ImagePreview> createState() => _ImagePreviewState();
}

class _ImagePreviewState extends State<_ImagePreview> {
  final _transform = TransformationController();

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _transform,
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: widget.filePath.startsWith('http')
            ? CachedNetworkImage(
                imageUrl: widget.filePath,
                fit: BoxFit.contain,
              )
            : Image.file(
                File(widget.filePath),
                fit: BoxFit.contain,
              ),
      ),
    );
  }
}

// ── Video Preview ─────────────────────────────────────────────────────────

class _VideoPreview extends StatelessWidget {
  final String filePath;
  const _VideoPreview({required this.filePath});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: double.infinity,
            height: 300,
            color: Colors.black,
            child: const Icon(Icons.video_file_rounded,
                color: Colors.white24, size: 80),
          ),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white54, width: 2),
            ),
            child: const Icon(Icons.play_arrow_rounded,
                color: Colors.white, size: 44),
          ),
          Positioned(
            bottom: 12,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_rounded, color: Colors.white, size: 14),
                  SizedBox(width: 4),
                  Text('Video',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Document Preview ──────────────────────────────────────────────────────

class _DocumentPreview extends StatelessWidget {
  final String fileName;
  final int? fileSize;
  const _DocumentPreview({required this.fileName, this.fileSize});

  @override
  Widget build(BuildContext context) {
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toUpperCase()
        : 'FILE';
    final extColor = _extColor(ext);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 120,
            height: 140,
            decoration: BoxDecoration(
              color: extColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: extColor.withOpacity(0.3), width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.insert_drive_file_rounded,
                    color: extColor, size: 56),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: extColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(ext,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      )),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              fileName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (fileSize != null) ...[
            const SizedBox(height: 6),
            Text(
              _fmtSize(fileSize!),
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

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
        return const Color(0xFF6A1B9A);
      default:
        return AppTheme.primary;
    }
  }

  String _fmtSize(int b) {
    if (b < 1024) return '$b B';
    if (b < 1048576) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / 1048576).toStringAsFixed(1)} MB';
  }
}

// ── Caption Bar ───────────────────────────────────────────────────────────

class _CaptionBar extends StatefulWidget {
  final TextEditingController controller;
  final MediaPreviewType type;
  final ValueChanged<bool> onFocusChange;
  final VoidCallback onSend;

  const _CaptionBar({
    required this.controller,
    required this.type,
    required this.onFocusChange,
    required this.onSend,
  });

  @override
  State<_CaptionBar> createState() => _CaptionBarState();
}

class _CaptionBarState extends State<_CaptionBar> {
  final _focus = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => widget.onFocusChange(_focus.hasFocus));
    widget.controller.addListener(() {
      final has = widget.controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      padding: EdgeInsets.fromLTRB(
          12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 12),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Caption input
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const SizedBox(width: 14),
                    Expanded(
                      child: TextField(
                        controller: widget.controller,
                        focusNode: _focus,
                        maxLines: 5,
                        minLines: 1,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: widget.type == MediaPreviewType.document
                              ? 'Add a message...'
                              : 'Add a caption...',
                          hintStyle: const TextStyle(
                              color: Colors.white38, fontSize: 15),
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    // Emoji button
                    Padding(
                      padding: const EdgeInsets.only(right: 6, bottom: 4),
                      child: IconButton(
                        icon: const Icon(Icons.emoji_emotions_outlined,
                            color: Colors.white54),
                        onPressed: () {},
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Send button
            GestureDetector(
              onTap: widget.onSend,
              child: Container(
                width: 54,
                height: 54,
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Multi-media picker preview (multiple images) ──────────────────────────

class MultiMediaPreviewScreen extends StatefulWidget {
  final List<_MediaItem> items;
  final String contactName;

  const MultiMediaPreviewScreen({
    super.key,
    required this.items,
    required this.contactName,
  });

  @override
  State<MultiMediaPreviewScreen> createState() =>
      _MultiMediaPreviewScreenState();
}

class _MediaItem {
  final String filePath;
  final String fileName;
  final MediaPreviewType type;
  final TextEditingController captionCtrl;

  _MediaItem({
    required this.filePath,
    required this.fileName,
    required this.type,
  }) : captionCtrl = TextEditingController();

  void dispose() => captionCtrl.dispose();
}

class _MultiMediaPreviewScreenState extends State<MultiMediaPreviewScreen> {
  int _current = 0;
  final _pageCtrl = PageController();

  @override
  void dispose() {
    _pageCtrl.dispose();
    for (final item in widget.items) item.dispose();
    super.dispose();
  }

  void _removeItem(int index) {
    if (widget.items.length == 1) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      widget.items[index].dispose();
      widget.items.removeAt(index);
      if (_current >= widget.items.length) {
        _current = widget.items.length - 1;
      }
    });
  }

  void _sendAll() {
    final result = widget.items
        .map((item) => {
              'path': item.filePath,
              'caption': item.captionCtrl.text.trim(),
              'type': item.type == MediaPreviewType.image
                  ? 'image'
                  : item.type == MediaPreviewType.video
                      ? 'video'
                      : 'document',
              'name': item.fileName,
            })
        .toList();
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.items[_current];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.contactName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        actions: [
          // Delete current
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            onPressed: () => _removeItem(_current),
            tooltip: 'Remove',
          ),
          if (item.type == MediaPreviewType.image) ...[
            IconButton(icon: const Icon(Icons.crop_rounded), onPressed: () {}),
            IconButton(icon: const Icon(Icons.draw_rounded), onPressed: () {}),
          ],
        ],
      ),
      body: Column(
        children: [
          // Main preview
          Expanded(
            child: PageView.builder(
              controller: _pageCtrl,
              itemCount: widget.items.length,
              onPageChanged: (i) => setState(() => _current = i),
              itemBuilder: (_, i) {
                final it = widget.items[i];
                return it.type == MediaPreviewType.image
                    ? _ImagePreview(filePath: it.filePath)
                    : it.type == MediaPreviewType.video
                        ? _VideoPreview(filePath: it.filePath)
                        : _DocumentPreview(fileName: it.fileName);
              },
            ),
          ),

          // Thumbnail strip
          if (widget.items.length > 1)
            Container(
              height: 84,
              color: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Thumbnails
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.items.length,
                      itemBuilder: (_, i) {
                        final it = widget.items[i];
                        final sel = i == _current;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _current = i);
                            _pageCtrl.animateToPage(i,
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut);
                          },
                          child: Container(
                            width: 64,
                            height: 64,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: sel
                                  ? Border.all(
                                      color: AppTheme.primary, width: 2.5)
                                  : null,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(sel ? 8 : 10),
                              child: it.type == MediaPreviewType.image
                                  ? Image.file(File(it.filePath),
                                      fit: BoxFit.cover)
                                  : Container(
                                      color: Colors.white12,
                                      child: const Icon(
                                          Icons.insert_drive_file_rounded,
                                          color: Colors.white54)),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

          // Caption
          _CaptionBar(
            controller: item.captionCtrl,
            type: item.type,
            onFocusChange: (_) {},
            onSend: _sendAll,
          ),
        ],
      ),
    );
  }
}
