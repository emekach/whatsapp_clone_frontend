// lib/screens/home/calls_tab.dart

import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

// ── Mock call history model ───────────────────────────────────────────────

enum _CallType { incoming, outgoing, missed, video }

class _CallEntry {
  final String name;
  final String initial;
  final Color color;
  final _CallType type;
  final DateTime time;
  final int count;

  const _CallEntry({
    required this.name,
    required this.initial,
    required this.color,
    required this.type,
    required this.time,
    this.count = 1,
  });
}

class CallsTab extends StatefulWidget {
  const CallsTab({super.key});

  @override
  State<CallsTab> createState() => _CallsTabState();
}

class _CallsTabState extends State<CallsTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // Sample recent calls for UI demo
  final List<_CallEntry> _recent = [
    _CallEntry(
      name: 'John Doe',
      initial: 'J',
      color: const Color(0xFF1565C0),
      type: _CallType.incoming,
      time: DateTime.now().subtract(const Duration(minutes: 12)),
    ),
    _CallEntry(
      name: 'Jane Smith',
      initial: 'S',
      color: const Color(0xFF6A1B9A),
      type: _CallType.missed,
      time: DateTime.now().subtract(const Duration(hours: 1)),
      count: 3,
    ),
    _CallEntry(
      name: 'Test User',
      initial: 'T',
      color: AppTheme.primary,
      type: _CallType.outgoing,
      time: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    _CallEntry(
      name: 'Jane Smith',
      initial: 'S',
      color: const Color(0xFF6A1B9A),
      type: _CallType.video,
      time: DateTime.now().subtract(const Duration(days: 1)),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // ── Sub tab bar ───────────────────────────────────────────
        Container(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCard : const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TabBar(
              controller: _tabCtrl,
              indicator: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor:
                  isDark ? Colors.white54 : Colors.grey.shade600,
              labelStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              padding: const EdgeInsets.all(3),
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Missed'),
              ],
            ),
          ),
        ),

        Expanded(
          child: TabBarView(
            controller: _tabCtrl,
            children: [
              _buildAllCalls(isDark),
              _buildMissedCalls(isDark),
            ],
          ),
        ),
      ],
    );
  }

  // ── All calls tab ─────────────────────────────────────────────────

  Widget _buildAllCalls(bool isDark) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Create call link card
        _CallLinkCard(isDark: isDark),

        // Recent section
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(children: [
            Text(
              'RECENT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: Colors.grey.shade500,
              ),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () {},
              child: const Text(
                'Clear all',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ]),
        ),

        // Call entries
        ..._recent.map((c) => _CallTile(entry: c, isDark: isDark)),

        // E2E notice
        _E2ENotice(isDark: isDark),
        const SizedBox(height: 80),
      ],
    );
  }

  // ── Missed calls tab ──────────────────────────────────────────────

  Widget _buildMissedCalls(bool isDark) {
    final missed = _recent.where((c) => c.type == _CallType.missed).toList();

    if (missed.isEmpty) {
      return _EmptyState(
        icon: Icons.call_missed_rounded,
        color: Colors.red,
        title: 'No missed calls',
        sub: 'You\'re all caught up!',
        isDark: isDark,
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 8),
      children: [
        ..._recent
            .where((c) => c.type == _CallType.missed)
            .map((c) => _CallTile(entry: c, isDark: isDark)),
        _E2ENotice(isDark: isDark),
        const SizedBox(height: 80),
      ],
    );
  }
}

// ── Call Link Card ────────────────────────────────────────────────────────

class _CallLinkCard extends StatelessWidget {
  final bool isDark;
  const _CallLinkCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(children: [
        // Icon
        Container(
          width: 50,
          height: 50,
          decoration: const BoxDecoration(
              color: AppTheme.primary, shape: BoxShape.circle),
          child:
              const Icon(Icons.add_link_rounded, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),

        // Text
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Create call link',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 3),
            Text(
              'Share a link for your WhatsApp call',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ],
        )),

        // Arrow
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.arrow_forward_ios_rounded,
              color: AppTheme.primary, size: 16),
        ),
      ]),
    );
  }
}

// ── Call Tile ─────────────────────────────────────────────────────────────

class _CallTile extends StatelessWidget {
  final _CallEntry entry;
  final bool isDark;
  const _CallTile({required this.entry, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isMissed = entry.type == _CallType.missed;
    final isVideo = entry.type == _CallType.video;
    final isOutgoing = entry.type == _CallType.outgoing;

    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          // Avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: entry.color,
            child: Text(
              entry.initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // Name + call info
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15.5,
                  color: isMissed ? Colors.red : null,
                ),
              ),
              const SizedBox(height: 3),
              Row(children: [
                // Direction icon
                Icon(
                  isOutgoing
                      ? Icons.call_made_rounded
                      : isMissed
                          ? Icons.call_missed_rounded
                          : isVideo
                              ? Icons.videocam_rounded
                              : Icons.call_received_rounded,
                  size: 14,
                  color: isMissed ? Colors.red : Colors.grey.shade500,
                ),
                const SizedBox(width: 4),
                Text(
                  _callLabel(),
                  style: TextStyle(
                    color: isMissed ? Colors.red : Colors.grey.shade500,
                    fontSize: 13,
                  ),
                ),
                if (entry.count > 1) ...[
                  Text(
                    ' (${entry.count})',
                    style: TextStyle(
                      color: isMissed ? Colors.red : Colors.grey.shade500,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                Text(
                  '· ${_formatTime(entry.time)}',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
              ]),
            ],
          )),

          // Call back button
          GestureDetector(
            onTap: () {},
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                color: AppTheme.primary,
                size: 20,
              ),
            ),
          ),
        ]),
      ),
    );
  }

  String _callLabel() {
    switch (entry.type) {
      case _CallType.incoming:
        return 'Incoming';
      case _CallType.outgoing:
        return 'Outgoing';
      case _CallType.missed:
        return 'Missed';
      case _CallType.video:
        return 'Video call';
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ── Empty State ───────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String sub;
  final bool isDark;

  const _EmptyState({
    required this.icon,
    required this.color,
    required this.title,
    required this.sub,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 40),
            ),
            const SizedBox(height: 20),
            Text(title,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(sub,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

// ── E2E Notice ────────────────────────────────────────────────────────────

class _E2ENotice extends StatelessWidget {
  final bool isDark;
  const _E2ENotice({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 13,
            color: isDark ? AppTheme.darkTextSub : AppTheme.lightTextSub,
          ),
          const SizedBox(width: 5),
          Text(
            'Your calls are ',
            style: TextStyle(
              color: isDark ? AppTheme.darkTextSub : AppTheme.lightTextSub,
              fontSize: 12,
            ),
          ),
          const Text(
            'end-to-end encrypted',
            style: TextStyle(
              color: AppTheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
