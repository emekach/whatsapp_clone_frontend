// lib/screens/group/create_group_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/api_service.dart';
import '../../utils/app_theme.dart';
import '../../providers/chat_provider.dart';

// ── Unified member model ──────────────────────────────────────────────────

class _Member {
  final int id;
  final String name;
  final String? avatarUrl;
  final String? phone;
  final String? about;
  final bool isOnline;
  final Uint8List? devicePhoto; // explicitly Uint8List

  const _Member({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.phone,
    this.about,
    this.isOnline = false,
    this.devicePhoto,
  });
}

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _api = ApiService();
  final _nameCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _picker = ImagePicker();

  List<_Member> _allMembers = [];
  List<_Member> _selected = [];
  bool _loading = true;
  bool _creating = false;
  String _query = '';
  String? _groupIconPath;
  int _step = 0; // 0 = pick members, 1 = set name

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Load contacts ─────────────────────────────────────────────────

  Future<void> _loadContacts() async {
    setState(() => _loading = true);
    try {
      List<Contact> phoneContacts = [];
      final status = await Permission.contacts.status;
      if (status.isGranted) {
        phoneContacts = await FlutterContacts.getContacts(
            withProperties: true, withPhoto: true);
      }

      List<dynamic> appUsers = [];
      if (phoneContacts.isNotEmpty) {
        final phones = phoneContacts
            .where((c) => c.phones.isNotEmpty)
            .expand((c) => c.phones
                .map((p) => p.number.replaceAll(RegExp(r'\s+|-|\(|\)'), '')))
            .where((p) => p.isNotEmpty)
            .toList();

        if (phones.isNotEmpty) {
          for (int i = 0; i < phones.length; i += 100) {
            final batch = phones.sublist(
                i, i + 100 > phones.length ? phones.length : i + 100);
            final data = await _api.syncContacts(batch);
            appUsers.addAll(data['data'] as List? ?? []);
          }
        }
      } else {
        final data = await _api.getContacts();
        appUsers = data['data'] ?? [];
      }

      // Deduplicate
      final seen = <int>{};
      final unique = appUsers.where((u) => seen.add(u['id'] as int)).toList();

      // Build _Member list
      final members = unique.map<_Member>((u) {
        final phone = (u['phone'] as String? ?? '')
            .replaceAll(RegExp(r'\s+|-|\(|\)'), '');

        Uint8List? photo;
        String? displayName;

        if (phoneContacts.isNotEmpty) {
          final match = phoneContacts
              .where((c) => c.phones.any((p) {
                    final cp = p.number.replaceAll(RegExp(r'\s+|-|\(|\)'), '');
                    final minLen = cp.length > 9 ? 9 : cp.length;
                    return cp.endsWith(phone.substring(phone.length > minLen
                            ? phone.length - minLen
                            : 0)) ||
                        phone.endsWith(cp.substring(
                            cp.length > minLen ? cp.length - minLen : 0));
                  }))
              .firstOrNull;

          if (match != null) {
            displayName = match.displayName;
            if (match.photo != null) {
              photo = Uint8List.fromList(match.photo!);
            }
          }
        }

        return _Member(
          id: u['id'] as int,
          name: displayName ?? (u['name'] as String? ?? ''),
          avatarUrl: u['avatar_url'] as String?,
          phone: u['phone'] as String?,
          about: u['about'] as String?,
          isOnline: u['is_online'] == true || u['is_online'] == 1,
          devicePhoto: photo,
        );
      }).toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      if (mounted)
        setState(() {
          _allMembers = members;
          _loading = false;
        });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Create group ──────────────────────────────────────────────────

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Please enter a group name');
      return;
    }
    if (_selected.isEmpty) {
      _snack('Please select at least one participant');
      return;
    }
    setState(() => _creating = true);
    try {
      final data = await _api.createGroup({
        'name': name,
        'participant_ids': _selected.map((m) => m.id).toList(),
      });
      if (mounted) {
        final conv = data['conversation'];
        await context.read<ChatProvider>().loadConversations();
        context.pushReplacement('/chat/${conv['id']}', extra: conv['name']);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _creating = false);
        _snack('Failed to create group. Try again.');
      }
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppTheme.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(12),
    ));
  }

  List<_Member> get _filtered {
    if (_query.isEmpty) return _allMembers;
    final q = _query.toLowerCase();
    return _allMembers
        .where((m) =>
            m.name.toLowerCase().contains(q) || (m.phone ?? '').contains(q))
        .toList();
  }

  Map<String, List<_Member>> get _grouped {
    final map = <String, List<_Member>>{};
    for (final m in _filtered) {
      final l = m.name.isNotEmpty ? m.name[0].toUpperCase() : '#';
      map.putIfAbsent(l, () => []).add(m);
    }
    return Map.fromEntries(
        map.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.primaryDark,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New group',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(
              _step == 0 ? 'Add participants' : 'Add group subject',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          if (_step == 0 && _selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _step = 1),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                      color: AppTheme.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
            )
          else if (_step == 1)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _creating
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white)))
                  : GestureDetector(
                      onTap: _create,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                            color: AppTheme.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.check_rounded,
                            color: Colors.white, size: 22),
                      ),
                    ),
            ),
        ],
      ),
      body: _step == 0 ? _buildMembersStep(isDark) : _buildNameStep(isDark),
    );
  }

  // ── Step 1: Pick members ──────────────────────────────────────────

  Widget _buildMembersStep(bool isDark) {
    return Column(children: [
      // Search bar
      Container(
        color: isDark ? AppTheme.darkSurface : AppTheme.primaryDark,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchCtrl,
            style: const TextStyle(color: Colors.white),
            cursorColor: Colors.white,
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: 'Search contacts...',
              hintStyle: TextStyle(color: Colors.white60),
              prefixIcon: Icon(Icons.search_rounded, color: Colors.white60),
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
        ),
      ),

      // Selected chips
      if (_selected.isNotEmpty) _buildSelectedChips(isDark),

      // Count bar
      Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
        child: Row(children: [
          Text('${_filtered.length} contact${_filtered.length != 1 ? 's' : ''}',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: Colors.grey.shade500)),
          if (_selected.isNotEmpty) ...[
            const Spacer(),
            Text('${_selected.length} selected',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppTheme.primary)),
          ],
        ]),
      ),

      Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary))
              : _allMembers.isEmpty
                  ? _buildEmptyState()
                  : _buildContactsList(isDark)),
    ]);
  }

  Widget _buildSelectedChips(bool isDark) {
    return Container(
      height: 92,
      color: isDark ? AppTheme.darkSurface : Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _selected.length,
        itemBuilder: (_, i) {
          final m = _selected[i];
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: _colorFor(m.name),
                    // ── FIX: explicit cast ──────────────────────
                    backgroundImage: m.devicePhoto != null
                        ? MemoryImage(m.devicePhoto!) as ImageProvider
                        : m.avatarUrl != null
                            ? CachedNetworkImageProvider(m.avatarUrl!)
                            : null,
                    child: (m.devicePhoto == null && m.avatarUrl == null)
                        ? Text(
                            m.name.isNotEmpty ? m.name[0].toUpperCase() : '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold))
                        : null,
                  ),
                  Positioned(
                    right: -2,
                    top: -2,
                    child: GestureDetector(
                      onTap: () => setState(
                          () => _selected.removeWhere((s) => s.id == m.id)),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.grey.shade700
                              : Colors.grey.shade400,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color:
                                  isDark ? AppTheme.darkSurface : Colors.white,
                              width: 2),
                        ),
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 12),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 4),
                SizedBox(
                  width: 56,
                  child: Text(
                    m.name.split(' ').first,
                    style: const TextStyle(fontSize: 11),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildContactsList(bool isDark) {
    final grouped = _grouped;
    final letters = grouped.keys.toList();
    return ListView.builder(
      itemCount: letters.length,
      itemBuilder: (_, i) {
        final letter = letters[i];
        final members = grouped[letter]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Text(letter,
                  style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
            ...members.map((m) {
              final isSel = _selected.any((s) => s.id == m.id);
              return _MemberTile(
                member: m,
                isSelected: isSel,
                onTap: () => setState(() {
                  if (isSel) {
                    _selected.removeWhere((s) => s.id == m.id);
                  } else {
                    _selected.add(m);
                  }
                }),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
        child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.people_outline_rounded,
            size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 16),
        const Text('No contacts found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('Contacts on WhatsApp Clone will appear here',
            style: TextStyle(color: Colors.grey.shade500)),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _loadContacts,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Refresh'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.primary,
            side: const BorderSide(color: AppTheme.primary),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
        ),
      ],
    ));
  }

  // ── Step 2: Group name ────────────────────────────────────────────

  Widget _buildNameStep(bool isDark) {
    return SingleChildScrollView(
      child: Column(children: [
        // Group icon + name
        Container(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () async {
                  final f = await _picker.pickImage(
                      source: ImageSource.gallery, imageQuality: 80);
                  if (f != null) {
                    setState(() => _groupIconPath = f.path);
                  }
                },
                child: Stack(children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor:
                        isDark ? AppTheme.darkCard : Colors.grey.shade200,
                    child: Icon(Icons.group_rounded,
                        color: Colors.grey.shade400, size: 36),
                  ),
                  Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: const BoxDecoration(
                            color: AppTheme.primary, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt_rounded,
                            color: Colors.white, size: 14),
                      )),
                ]),
              ),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameCtrl,
                    autofocus: true,
                    maxLength: 50,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'Group name',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      border: const UnderlineInputBorder(
                          borderSide: BorderSide(color: AppTheme.primary)),
                      focusedBorder: const UnderlineInputBorder(
                          borderSide:
                              BorderSide(color: AppTheme.primary, width: 2)),
                      counterStyle:
                          TextStyle(color: Colors.grey.shade400, fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text('Provide a group name and optional icon',
                      style:
                          TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ],
              )),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Participants summary
        Container(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(children: [
            const Icon(Icons.people_rounded, color: AppTheme.primary, size: 18),
            const SizedBox(width: 8),
            Text(
                '${_selected.length} participant${_selected.length != 1 ? 's' : ''}',
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                    fontSize: 14)),
          ]),
        ),

        // Chips
        Container(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selected
                .map((m) => Chip(
                      avatar: CircleAvatar(
                        backgroundColor: _colorFor(m.name),
                        // ── FIX: explicit cast ──────────────────────────
                        backgroundImage: m.devicePhoto != null
                            ? MemoryImage(m.devicePhoto!) as ImageProvider
                            : m.avatarUrl != null
                                ? CachedNetworkImageProvider(m.avatarUrl!)
                                : null,
                        child: (m.devicePhoto == null && m.avatarUrl == null)
                            ? Text(
                                m.name.isNotEmpty
                                    ? m.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 11))
                            : null,
                      ),
                      label: Text(m.name.split(' ').first,
                          style: const TextStyle(fontSize: 13)),
                      deleteIcon: const Icon(Icons.close_rounded, size: 16),
                      onDeleted: () => setState(
                          () => _selected.removeWhere((s) => s.id == m.id)),
                      backgroundColor:
                          isDark ? AppTheme.darkCard : Colors.grey.shade100,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                    ))
                .toList(),
          ),
        ),

        const SizedBox(height: 12),

        // Create button
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _creating ? null : _create,
              icon: _creating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded),
              label: Text(
                _creating ? 'Creating...' : 'Create Group',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 40),
      ]),
    );
  }

  Color _colorFor(String name) {
    final colors = [
      AppTheme.primary,
      Colors.blue,
      Colors.purple,
      Colors.orange,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];
    if (name.isEmpty) return AppTheme.primary;
    return colors[name.codeUnitAt(0) % colors.length];
  }
}

// ── Member Tile ───────────────────────────────────────────────────────────

class _MemberTile extends StatelessWidget {
  final _Member member;
  final bool isSelected;
  final VoidCallback onTap;

  const _MemberTile({
    required this.member,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Stack(children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: _colorFor(member.name),
              // ── FIX: explicit cast ──────────────────────────────
              backgroundImage: member.devicePhoto != null
                  ? MemoryImage(member.devicePhoto!) as ImageProvider
                  : member.avatarUrl != null
                      ? CachedNetworkImageProvider(member.avatarUrl!)
                      : null,
              child: (member.devicePhoto == null && member.avatarUrl == null)
                  ? Text(
                      member.name.isNotEmpty
                          ? member.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18))
                  : null,
            ),
            if (isSelected)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.85),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 22),
                ),
              ),
          ]),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(member.name,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15.5,
                      color: isSelected ? AppTheme.primary : null)),
              const SizedBox(height: 2),
              Text(
                member.about ?? member.phone ?? 'Available',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          )),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primary : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? AppTheme.primary : Colors.grey.shade400,
                width: 2,
              ),
            ),
            child: isSelected
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                : null,
          ),
        ]),
      ),
    );
  }

  Color _colorFor(String name) {
    final colors = [
      AppTheme.primary,
      Colors.blue,
      Colors.purple,
      Colors.orange,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
    ];
    if (name.isEmpty) return AppTheme.primary;
    return colors[name.codeUnitAt(0) % colors.length];
  }
}
