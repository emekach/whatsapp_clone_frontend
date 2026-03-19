// lib/screens/home/status_tab.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import '../../models/models.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/app_theme.dart';

class StatusTab extends StatefulWidget {
  const StatusTab({super.key});
  @override
  State<StatusTab> createState() => _StatusTabState();
}

class _StatusTabState extends State<StatusTab>
    with AutomaticKeepAliveClientMixin {
  final _api = ApiService();
  final _picker = ImagePicker();

  StatusGroupModel? _myStatus;
  List<StatusGroupModel> _others = [];
  bool _loading = true;
  bool _uploading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final me = context.read<AuthProvider>().user;
      final data = await _api.getStatuses();

      final raw = data['data'];
      if (raw == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final all = (raw as List)
          .map((s) => StatusGroupModel.fromJson(s as Map<String, dynamic>))
          .toList();

      StatusGroupModel? mine;
      final others = <StatusGroupModel>[];
      for (final g in all) {
        if (g.user.id == me?.id) {
          mine = g;
        } else {
          others.add(g);
        }
      }

      if (mounted)
        setState(() {
          _myStatus = mine;
          _others = others;
          _loading = false;
        });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _doUpload(Future<dynamic> Function() call) async {
    if (_uploading) return;
    setState(() => _uploading = true);
    try {
      await call();
      if (!mounted) return;
      setState(() => _uploading = false);
      _snack('Status posted!', ok: true);
      await _load();
    } catch (_) {
      if (!mounted) return;
      setState(() => _uploading = false);
      _snack('Failed to post. Try again.');
    }
  }

  void _snack(String msg, {bool ok = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? AppTheme.primary : Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(12),
    ));
  }

  void _openAddSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddSheet(
        isDark: isDark,
        onText: () {
          Navigator.pop(context);
          _openTextComposer();
        },
        onPhoto: () {
          Navigator.pop(context);
          _pick();
        },
        onCamera: () {
          Navigator.pop(context);
          _pick(camera: true);
        },
      ),
    );
  }

  Future<void> _pick({bool camera = false}) async {
    final f = await _picker.pickImage(
        source: camera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 85);
    if (f == null) return;
    await _doUpload(() => _api.postMediaStatus(f.path, 'image'));
  }

  void _openTextComposer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TextComposer(onPost: (text, color) async {
        Navigator.pop(context);
        await _doUpload(() => _api.postTextStatus(text, bgColor: color));
      }),
    );
  }

  void _openViewer(StatusGroupModel group, {int startIndex = 0}) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, __, ___) => _Viewer(
        group: group,
        startIndex: startIndex,
        api: _api,
        onReload: _load,
      ),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final me = context.watch<AuthProvider>().user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(children: [
      RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: _load,
        child: ListView(children: [
          // ── My status ───────────────────────────────────────────
          _MyStatusCard(
            me: me,
            group: _myStatus,
            isDark: isDark,
            onAdd: _openAddSheet,
            onView: _myStatus != null ? () => _openViewer(_myStatus!) : null,
          ),

          // ── Loading ─────────────────────────────────────────────
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(
                  child: CircularProgressIndicator(color: AppTheme.primary)),
            ),

          // ── Recent updates ──────────────────────────────────────
          if (!_loading && _others.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
              child: Text('RECENT UPDATES',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: Colors.grey.shade500)),
            ),
            ..._others.map((g) => _ContactStatusTile(
                  group: g,
                  isDark: isDark,
                  onTap: () => _openViewer(g),
                )),
          ],

          // ── Empty state ─────────────────────────────────────────
          if (!_loading && _others.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              child: Column(children: [
                Icon(Icons.people_outline_rounded,
                    size: 56, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                const Text('No status updates yet',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text(
                  'When your contacts post a status\nit will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade500, height: 1.5),
                ),
              ]),
            ),

          // ── Channels ────────────────────────────────────────────
          _ChannelsCard(isDark: isDark),
          const SizedBox(height: 100),
        ]),
      ),
      if (_uploading)
        Positioned.fill(
            child: Container(
          color: Colors.black54,
          child: Center(
              child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Column(mainAxisSize: MainAxisSize.min, children: [
              CircularProgressIndicator(color: AppTheme.primary),
              SizedBox(height: 16),
              Text('Posting status...',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
            ]),
          )),
        )),
    ]);
  }
}

// ── My Status Card ────────────────────────────────────────────────────────

class _MyStatusCard extends StatelessWidget {
  final dynamic me;
  final StatusGroupModel? group;
  final bool isDark;
  final VoidCallback onAdd;
  final VoidCallback? onView;

  const _MyStatusCard({
    required this.me,
    this.group,
    required this.isDark,
    required this.onAdd,
    this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final has = group != null && group!.statuses.isNotEmpty;
    final total =
        group?.statuses.fold<int>(0, (s, st) => s + st.viewCount) ?? 0;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        GestureDetector(
          onTap: has ? onView : onAdd,
          child: _RingAvatar(
            avatarUrl: me?.avatarUrl,
            name: me?.name ?? '?',
            size: 60,
            count: group?.statuses.length ?? 0,
            showAdd: true,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('My status',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 3),
            Text(
              has
                  ? '${group!.statuses.length} update${group!.statuses.length > 1 ? 's' : ''}${total > 0 ? ' · $total view${total > 1 ? 's' : ''}' : ''}'
                  : 'Tap to add a status update',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ],
        )),
        IconButton(
          icon: const Icon(Icons.edit_rounded, color: Colors.purple),
          onPressed: onAdd,
        ),
        IconButton(
          icon: const Icon(Icons.camera_alt_rounded, color: AppTheme.primary),
          onPressed: onAdd,
        ),
      ]),
    );
  }
}

// ── Contact Status Tile ───────────────────────────────────────────────────

class _ContactStatusTile extends StatelessWidget {
  final StatusGroupModel group;
  final bool isDark;
  final VoidCallback onTap;

  const _ContactStatusTile({
    required this.group,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final diff = DateTime.now().difference(group.statuses.last.createdAt);
    final time = diff.inMinutes < 1
        ? 'Just now'
        : diff.inMinutes < 60
            ? '${diff.inMinutes}m ago'
            : diff.inHours < 24
                ? '${diff.inHours}h ago'
                : '${diff.inDays}d ago';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          _RingAvatar(
            avatarUrl: group.user.avatarUrl,
            name: group.user.name,
            size: 56,
            count: group.statuses.length,
            isDark: isDark,
          ),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(group.user.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15.5),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text(time,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
            ],
          )),
          if (group.statuses.length > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${group.statuses.length}',
                  style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
        ]),
      ),
    );
  }
}

// ── Status Viewer ─────────────────────────────────────────────────────────

class _Viewer extends StatefulWidget {
  final StatusGroupModel group;
  final int startIndex;
  final ApiService api;
  final VoidCallback onReload;

  const _Viewer(
      {required this.group,
      required this.startIndex,
      required this.api,
      required this.onReload});

  @override
  State<_Viewer> createState() => _ViewerState();
}

class _ViewerState extends State<_Viewer> with SingleTickerProviderStateMixin {
  late int _cur;
  late AnimationController _ctrl;
  final _replyCtrl = TextEditingController();
  bool _sendingReply = false;

  @override
  void initState() {
    super.initState();
    _cur = widget.startIndex;
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 5))
          ..addStatusListener((s) {
            if (s == AnimationStatus.completed) _advance();
          });
    _startProgress();
    _markViewed();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _replyCtrl.dispose();
    super.dispose();
  }

  StatusModel get _status => widget.group.statuses[_cur];
  bool get _isMine => _status.isMine;

  void _startProgress() {
    _ctrl.reset();
    _ctrl.forward();
  }

  void _advance() {
    if (_cur < widget.group.statuses.length - 1) {
      setState(() => _cur++);
      _startProgress();
      _markViewed();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _back() {
    if (_cur > 0) {
      setState(() => _cur--);
      _startProgress();
    }
  }

  void _markViewed() {
    if (!_isMine) widget.api.viewStatus(_status.id);
  }

  void _showReactions() {
    _ctrl.stop();
    final emojis = ['❤️', '😂', '😮', '😢', '🙏', '👍', '🔥', '😍'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2C34),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('React to status',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: emojis
                .map((e) => GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        try {
                          await widget.api.reactToStatus(_status.id, e);
                          widget.onReload();
                          if (mounted) _snack('Reacted with $e');
                        } catch (_) {}
                        _ctrl.forward();
                      },
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: _status.myReaction == e
                              ? Border.all(color: AppTheme.primary, width: 2)
                              : null,
                        ),
                        child: Center(
                            child:
                                Text(e, style: const TextStyle(fontSize: 28))),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    ).whenComplete(() => _ctrl.forward());
  }

  void _showReplySheet() {
    _ctrl.stop();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            color: Color(0xFF1F2C34),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(children: [
            Expanded(
                child: TextField(
              controller: _replyCtrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Reply to ${widget.group.user.name}...',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            )),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () async {
                final txt = _replyCtrl.text.trim();
                if (txt.isEmpty) return;
                setState(() => _sendingReply = true);
                try {
                  final data = await widget.api.replyToStatus(_status.id, txt);
                  _replyCtrl.clear();
                  Navigator.pop(context);
                  if (mounted) {
                    _snack('Reply sent ✓');
                    final convId = data['conversation_id'];
                    if (convId != null) {
                      Navigator.of(context).pop();
                      context.push('/chat/$convId',
                          extra: widget.group.user.name);
                    }
                  }
                } catch (_) {
                  if (mounted) setState(() => _sendingReply = false);
                }
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                    color: AppTheme.primary, shape: BoxShape.circle),
                child: _sendingReply
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, color: Colors.white),
              ),
            ),
          ]),
        ),
      ),
    ).whenComplete(() {
      setState(() => _sendingReply = false);
      _ctrl.forward();
    });
  }

  void _showViewersSheet() {
    _ctrl.stop();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.85,
        builder: (_, sc) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1F2C34),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(children: [
                const Icon(Icons.visibility_rounded,
                    color: Colors.white70, size: 18),
                const SizedBox(width: 8),
                Text(
                    '${_status.viewCount} viewer${_status.viewCount != 1 ? 's' : ''}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ]),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
                child: _status.viewers.isEmpty
                    ? const Center(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                            Icon(Icons.visibility_off_outlined,
                                color: Colors.white38, size: 52),
                            SizedBox(height: 12),
                            Text('No views yet',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 15)),
                          ]))
                    : ListView.builder(
                        controller: sc,
                        itemCount: _status.viewers.length,
                        itemBuilder: (_, i) {
                          final v = _status.viewers[i];
                          final diff = DateTime.now().difference(v.viewedAt);
                          final time = diff.inMinutes < 60
                              ? '${diff.inMinutes}m ago'
                              : '${diff.inHours}h ago';
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.primary,
                              backgroundImage: v.avatarUrl != null
                                  ? NetworkImage(v.avatarUrl!)
                                  : null,
                              child: v.avatarUrl == null
                                  ? Text(v.name[0].toUpperCase(),
                                      style:
                                          const TextStyle(color: Colors.white))
                                  : null,
                            ),
                            title: Text(v.name,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(time,
                                style: const TextStyle(color: Colors.white54)),
                            trailing: v.reaction != null
                                ? Text(v.reaction!,
                                    style: const TextStyle(fontSize: 24))
                                : null,
                          );
                        },
                      )),
          ]),
        ),
      ),
    ).whenComplete(() => _ctrl.forward());
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppTheme.primary,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.of(context).size;
    final status = _status;
    final total = widget.group.statuses.length;

    Color? bgColor;
    if (status.backgroundColor != null) {
      try {
        bgColor = Color(
            int.parse('0xFF${status.backgroundColor!.replaceAll('#', '')}'));
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapUp: (d) {
          if (d.localPosition.dx < sz.width / 3)
            _back();
          else if (d.localPosition.dx > sz.width * 2 / 3) _advance();
        },
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) > 300) Navigator.of(context).pop();
        },
        onLongPressStart: (_) => _ctrl.stop(),
        onLongPressEnd: (_) => _ctrl.forward(),
        child: Stack(fit: StackFit.expand, children: [
          // Content
          Container(
            color: bgColor ?? Colors.black,
            child: status.fileUrl != null
                ? Image.network(status.fileUrl!,
                    fit: BoxFit.contain,
                    loadingBuilder: (_, child, progress) => progress == null
                        ? child
                        : const Center(
                            child: CircularProgressIndicator(
                                color: AppTheme.primary)))
                : Center(
                    child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(status.content ?? '',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w500,
                                height: 1.5)))),
          ),

          // Top gradient
          Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 140,
              child: Container(
                  decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.6),
                      Colors.transparent
                    ]),
              ))),

          // Progress bars
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            right: 8,
            child: Row(
                children: List.generate(
                    total,
                    (i) => Expanded(
                        child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: i < _cur
                                    ? Container(height: 3, color: Colors.white)
                                    : i == _cur
                                        ? AnimatedBuilder(
                                            animation: _ctrl,
                                            builder: (_, __) =>
                                                LinearProgressIndicator(
                                                    value: _ctrl.value,
                                                    backgroundColor:
                                                        Colors.white30,
                                                    valueColor:
                                                        const AlwaysStoppedAnimation(
                                                            Colors.white),
                                                    minHeight: 3))
                                        : Container(
                                            height: 3,
                                            color: Colors.white24)))))),
          ),

          // User info bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 18,
            left: 12,
            right: 12,
            child: Row(children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.primary,
                backgroundImage: widget.group.user.avatarUrl != null
                    ? NetworkImage(widget.group.user.avatarUrl!)
                    : null,
                child: widget.group.user.avatarUrl == null
                    ? Text(
                        widget.group.user.name.isNotEmpty
                            ? widget.group.user.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(color: Colors.white))
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.group.user.name,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  Text(_timeAgo(status.createdAt),
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              )),
              if (status.myReaction != null)
                Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(status.myReaction!,
                      style: const TextStyle(fontSize: 18)),
                ),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ]),
          ),

          // Bottom gradient
          Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 120,
              child: Container(
                  decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withOpacity(0.7),
                      Colors.transparent
                    ]),
              ))),

          // Bottom bar
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 12,
            left: 16,
            right: 16,
            child: _isMine
                ? _MyBar(
                    viewCount: status.viewCount,
                    reactionCount: status.reactionCount,
                    onViewers: _showViewersSheet)
                : _OtherBar(
                    myReaction: status.myReaction,
                    onReact: _showReactions,
                    onReply: _showReplySheet),
          ),
        ]),
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}

// ── Bottom bars ───────────────────────────────────────────────────────────

class _MyBar extends StatelessWidget {
  final int viewCount, reactionCount;
  final VoidCallback onViewers;
  const _MyBar(
      {required this.viewCount,
      required this.reactionCount,
      required this.onViewers});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onViewers,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(children: [
            const Icon(Icons.visibility_rounded,
                color: Colors.white70, size: 18),
            const SizedBox(width: 8),
            Text('$viewCount view${viewCount != 1 ? 's' : ''}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600)),
            if (reactionCount > 0) ...[
              const SizedBox(width: 12),
              const Icon(Icons.favorite_rounded, color: Colors.red, size: 16),
              const SizedBox(width: 4),
              Text('$reactionCount',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ],
            const Spacer(),
            const Text('Tap to see viewers',
                style: TextStyle(color: Colors.white54, fontSize: 12)),
            const Icon(Icons.keyboard_arrow_up_rounded,
                color: Colors.white54, size: 18),
          ]),
        ),
      );
}

class _OtherBar extends StatelessWidget {
  final String? myReaction;
  final VoidCallback onReact, onReply;
  const _OtherBar(
      {this.myReaction, required this.onReact, required this.onReply});
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: GestureDetector(
          onTap: onReply,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white54),
              color: Colors.black26,
            ),
            child: const Row(children: [
              SizedBox(width: 16),
              Text('Reply...',
                  style: TextStyle(color: Colors.white54, fontSize: 15)),
            ]),
          ),
        )),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onReact,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: myReaction != null
                  ? AppTheme.primary.withOpacity(0.3)
                  : Colors.black38,
              border: Border.all(
                color: myReaction != null ? AppTheme.primary : Colors.white54,
                width: 1.5,
              ),
            ),
            child: Center(
                child: myReaction != null
                    ? Text(myReaction!, style: const TextStyle(fontSize: 22))
                    : const Icon(Icons.add_reaction_outlined,
                        color: Colors.white, size: 22)),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black38,
              border: Border.all(color: Colors.white54, width: 1.5)),
          child:
              const Icon(Icons.forward_rounded, color: Colors.white, size: 22),
        ),
      ]);
}

// ── Text Composer ─────────────────────────────────────────────────────────

class _TextComposer extends StatefulWidget {
  final Function(String, String) onPost;
  const _TextComposer({required this.onPost});
  @override
  State<_TextComposer> createState() => _TextComposerState();
}

class _TextComposerState extends State<_TextComposer> {
  final _ctrl = TextEditingController();
  final _colors = [
    const Color(0xFF128C7E),
    const Color(0xFF1565C0),
    const Color(0xFF6A1B9A),
    const Color(0xFFE53935),
    const Color(0xFFF57C00),
    const Color(0xFF212121),
    const Color(0xFF37474F),
    const Color(0xFF00695C),
  ];
  int _sel = 0;
  bool _posting = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _hex =>
      '#${_colors[_sel].value.toRadixString(16).substring(2).toUpperCase()}';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
            child: Row(children: [
              const Expanded(
                  child: Text('Text status',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 17))),
              TextButton(
                onPressed: _posting || _ctrl.text.trim().isEmpty
                    ? null
                    : () async {
                        setState(() => _posting = true);
                        await widget.onPost(_ctrl.text.trim(), _hex);
                      },
                style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    disabledForegroundColor: Colors.grey),
                child: _posting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.primary))
                    : const Text('Post',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ]),
          ),
          Expanded(
              child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            decoration: BoxDecoration(
                color: _colors[_sel], borderRadius: BorderRadius.circular(20)),
            child: Center(
                child: Padding(
              padding: const EdgeInsets.all(28),
              child: TextField(
                controller: _ctrl,
                maxLines: null,
                textAlign: TextAlign.center,
                autofocus: true,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    height: 1.5),
                decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Type a status...',
                    hintStyle: TextStyle(color: Colors.white54, fontSize: 22)),
              ),
            )),
          )),
          SizedBox(
              height: 60,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: _colors.length,
                itemBuilder: (_, i) {
                  final sel = i == _sel;
                  return GestureDetector(
                    onTap: () => setState(() => _sel = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 44,
                      height: 44,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: _colors[i],
                        shape: BoxShape.circle,
                        border: sel
                            ? Border.all(color: Colors.white, width: 3)
                            : Border.all(color: Colors.transparent, width: 3),
                        boxShadow: sel
                            ? [
                                BoxShadow(
                                    color: _colors[i].withOpacity(0.5),
                                    blurRadius: 8)
                              ]
                            : null,
                      ),
                      child: sel
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 20)
                          : null,
                    ),
                  );
                },
              )),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

// ── Ring Avatar ───────────────────────────────────────────────────────────

class _RingAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final double size;
  final int count;
  final bool showAdd;
  final bool isDark;

  const _RingAvatar(
      {this.avatarUrl,
      required this.name,
      required this.size,
      required this.count,
      this.showAdd = false,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      CustomPaint(
        painter: _Ring(count: count),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: CircleAvatar(
            radius: size / 2 - 4,
            backgroundColor: AppTheme.primary,
            backgroundImage:
                avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            child: avatarUrl == null
                ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: size * 0.3,
                        fontWeight: FontWeight.bold))
                : null,
          ),
        ),
      ),
      if (showAdd)
        Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
                border: Border.all(
                    color: isDark ? AppTheme.darkBg : Colors.white, width: 2),
              ),
              child:
                  const Icon(Icons.add_rounded, color: Colors.white, size: 12),
            )),
    ]);
  }
}

class _Ring extends CustomPainter {
  final int count;
  _Ring({required this.count});
  @override
  void paint(Canvas canvas, Size size) {
    if (count == 0) return;
    final p = Paint()
      ..color = AppTheme.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 1.5;
    if (count <= 1) {
      canvas.drawCircle(c, r, p);
      return;
    }
    const pi = 3.14159265;
    const gap = 0.12;
    final seg = (2 * pi - count * gap) / count;
    for (int i = 0; i < count; i++) {
      canvas.drawArc(Rect.fromCircle(center: c, radius: r),
          -pi / 2 + i * (seg + gap), seg, false, p);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Add Sheet ─────────────────────────────────────────────────────────────

class _AddSheet extends StatelessWidget {
  final bool isDark;
  final VoidCallback onText, onPhoto, onCamera;
  const _AddSheet(
      {required this.isDark,
      required this.onText,
      required this.onPhoto,
      required this.onCamera});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Text('Add to my status',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          const Divider(height: 1),
          ListTile(
            leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.edit_rounded, color: Colors.purple)),
            title: const Text('Text status',
                style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: onText,
          ),
          ListTile(
            leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.photo_library_rounded,
                    color: Colors.blue)),
            title: const Text('Photo from gallery',
                style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: onPhoto,
          ),
          ListTile(
            leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle),
                child: const Icon(Icons.camera_alt_rounded,
                    color: AppTheme.primary)),
            title: const Text('Camera',
                style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: onCamera,
          ),
          const SizedBox(height: 12),
        ]),
      );
}

// ── Channels Card ─────────────────────────────────────────────────────────

class _ChannelsCard extends StatelessWidget {
  final bool isDark;
  const _ChannelsCard({required this.isDark});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(12, 20, 12, 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Channels',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            TextButton(
                onPressed: () {},
                child: const Text('Find',
                    style: TextStyle(color: AppTheme.primary))),
          ]),
          Text('Stay updated on topics that matter to you.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.explore_rounded, size: 18),
            label: const Text('Explore channels',
                style: TextStyle(fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ]),
      );
}
