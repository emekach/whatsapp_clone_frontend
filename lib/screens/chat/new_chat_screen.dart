// lib/screens/chat/new_chat_screen.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/api_service.dart';
import '../../utils/app_theme.dart';
import '../../providers/chat_provider.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen>
    with SingleTickerProviderStateMixin {
  final _api = ApiService();
  final _searchCtrl = TextEditingController();

  List<dynamic> _appUsers = [];
  bool _loadingSync = false;
  bool _syncDone = false;

  List<Contact> _phoneContacts = [];
  bool _loadingPhone = false;
  bool _phoneDenied = false;

  String _query = '';
  bool _searching = false;
  dynamic _searchResult;

  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadPhoneContactsAndSync();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPhoneContactsAndSync() async {
    setState(() {
      _loadingPhone = true;
      _loadingSync = true;
    });
    try {
      final status = await Permission.contacts.request();
      if (!status.isGranted) {
        if (mounted)
          setState(() {
            _phoneDenied = true;
            _loadingPhone = false;
            _loadingSync = false;
          });
        return;
      }

      final contacts = await FlutterContacts.getContacts(
          withProperties: true, withPhoto: true);
      final valid = contacts.where((c) => c.phones.isNotEmpty).toList()
        ..sort((a, b) => a.displayName.compareTo(b.displayName));

      if (mounted)
        setState(() {
          _phoneContacts = valid;
          _loadingPhone = false;
        });

      await _syncWithBackend(valid);
    } catch (_) {
      if (mounted)
        setState(() {
          _loadingPhone = false;
          _loadingSync = false;
        });
    }
  }

  Future<void> _syncWithBackend(List<Contact> contacts) async {
    if (!mounted) return;
    setState(() => _loadingSync = true);
    try {
      final phones = contacts
          .expand((c) => c.phones
              .map((p) => p.number.replaceAll(RegExp(r'\s+|-|\(|\)'), '')))
          .where((p) => p.isNotEmpty)
          .toList();

      if (phones.isEmpty) {
        setState(() {
          _loadingSync = false;
          _syncDone = true;
        });
        return;
      }

      final allUsers = <dynamic>[];
      for (int i = 0; i < phones.length; i += 100) {
        final batch = phones.sublist(
            i, i + 100 > phones.length ? phones.length : i + 100);
        final data = await _api.syncContacts(batch);
        allUsers.addAll(data['data'] as List? ?? []);
      }

      final seen = <int>{};
      final unique = allUsers.where((u) => seen.add(u['id'] as int)).toList();

      // Enrich with device contact data
      for (final user in unique) {
        final phone = (user['phone'] as String? ?? '')
            .replaceAll(RegExp(r'\s+|-|\(|\)'), '');
        final match = contacts
            .where((c) => c.phones.any((p) {
                  final cp = p.number.replaceAll(RegExp(r'\s+|-|\(|\)'), '');
                  final minLen = cp.length > 9 ? 9 : cp.length;
                  return cp.endsWith(phone.substring(
                          phone.length > minLen ? phone.length - minLen : 0)) ||
                      phone.endsWith(cp.substring(
                          cp.length > minLen ? cp.length - minLen : 0));
                }))
            .firstOrNull;

        if (match != null) {
          user['display_name'] = match.displayName;
          if (match.photo != null) {
            // ── store as Uint8List explicitly ─────────────────────
            user['device_photo'] = Uint8List.fromList(match.photo!);
          }
        }
      }

      if (mounted)
        setState(() {
          _appUsers = unique;
          _loadingSync = false;
          _syncDone = true;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          _loadingSync = false;
          _syncDone = true;
        });
    }
  }

  Future<void> _onSearch(String val) async {
    setState(() {
      _query = val;
      _searchResult = null;
    });
    if (val.trim().length < 3) return;
    setState(() => _searching = true);
    try {
      final data = await _api.searchByPhone(val.trim());
      if (mounted)
        setState(() {
          _searchResult = data['user'];
          _searching = false;
        });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _startChat(int userId, String name) async {
    try {
      final data = await _api.startPrivateConversation(userId);
      final conv = data['conversation'];
      if (mounted) {
        context.read<ChatProvider>().loadConversations();
        context.pushReplacement('/chat/${conv['id']}', extra: name);
      }
    } catch (_) {}
  }

  List<dynamic> get _filteredAppUsers {
    if (_query.isEmpty) return _appUsers;
    final q = _query.toLowerCase();
    return _appUsers.where((u) {
      final name = ((u['display_name'] ?? u['name']) as String).toLowerCase();
      final phone = (u['phone'] as String? ?? '').toLowerCase();
      return name.contains(q) || phone.contains(q);
    }).toList();
  }

  List<Contact> get _filteredPhone {
    if (_query.isEmpty) return _phoneContacts;
    final q = _query.toLowerCase();
    return _phoneContacts
        .where((c) =>
            c.displayName.toLowerCase().contains(q) ||
            c.phones.any((p) => p.number.contains(q)))
        .toList();
  }

  Map<String, List<Contact>> get _groupedPhone {
    final grouped = <String, List<Contact>>{};
    for (final c in _filteredPhone) {
      final l = c.displayName.isNotEmpty ? c.displayName[0].toUpperCase() : '#';
      grouped.putIfAbsent(l, () => []).add(c);
    }
    return Map.fromEntries(
        grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.primaryDark,
        foregroundColor: Colors.white,
        title: const Text('New chat',
            style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorWeight: 3,
          tabs: [
            Tab(
                child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('ON APP'),
                if (_appUsers.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${_appUsers.length}',
                        style: const TextStyle(fontSize: 11)),
                  ),
                ],
              ],
            )),
            Tab(
                child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('ALL CONTACTS'),
                if (_phoneContacts.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${_phoneContacts.length}',
                        style: const TextStyle(fontSize: 11)),
                  ),
                ],
              ],
            )),
          ],
        ),
      ),
      body: Column(children: [
        Container(
          color: isDark ? AppTheme.darkSurface : AppTheme.primaryDark,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Container(
            decoration: BoxDecoration(
              color:
                  isDark ? AppTheme.darkCard : Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              style: const TextStyle(color: Colors.white),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                hintText: 'Search name or phone...',
                hintStyle: const TextStyle(color: Colors.white60),
                prefixIcon:
                    const Icon(Icons.search_rounded, color: Colors.white60),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white60),
                        onPressed: () {
                          _searchCtrl.clear();
                          _onSearch('');
                        })
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ),
        Expanded(
            child: TabBarView(
          controller: _tabCtrl,
          children: [
            _buildAppTab(isDark),
            _buildPhoneTab(isDark),
          ],
        )),
      ]),
    );
  }

  Widget _buildAppTab(bool isDark) {
    return ListView(children: [
      _QuickAction(
        icon: Icons.group_rounded,
        label: 'New group',
        sub: 'Create a group chat',
        color: AppTheme.primary,
        onTap: () => context.push('/new-group'),
      ),
      _QuickAction(
        icon: Icons.people_rounded,
        label: 'New community',
        sub: 'Groups with a common interest',
        color: Colors.purple,
        onTap: () {},
      ),
      if (_loadingSync) ...[
        const SizedBox(height: 20),
        const Center(
            child: Column(children: [
          CircularProgressIndicator(color: AppTheme.primary),
          SizedBox(height: 12),
          Text('Finding contacts on the app...',
              style: TextStyle(color: Colors.grey)),
        ])),
        const SizedBox(height: 20),
      ],
      if (_searchResult != null && _query.isNotEmpty) ...[
        _SectionHeader('Search result'),
        _AppUserTile(
          user: _searchResult,
          onTap: () => _startChat(_searchResult['id'],
              _searchResult['display_name'] ?? _searchResult['name']),
        ),
      ],
      if (_syncDone &&
          _filteredAppUsers.isEmpty &&
          _searchResult == null &&
          _query.isEmpty)
        _EmptyAppState(
            phoneCount: _phoneContacts.length,
            onRefresh: _loadPhoneContactsAndSync)
      else if (_filteredAppUsers.isNotEmpty) ...[
        _SectionHeader(
            '${_filteredAppUsers.length} contact${_filteredAppUsers.length != 1 ? 's' : ''} on WhatsApp Clone'),
        ..._filteredAppUsers.map((u) => _AppUserTile(
              user: u,
              onTap: () => _startChat(u['id'], u['display_name'] ?? u['name']),
            )),
      ],
      if (_query.isNotEmpty &&
          _filteredAppUsers.isEmpty &&
          _searchResult == null &&
          !_searching &&
          !_loadingSync)
        _EmptySearch(query: _query),
      const SizedBox(height: 80),
    ]);
  }

  Widget _buildPhoneTab(bool isDark) {
    if (_phoneDenied) {
      return _PermissionDenied(onRetry: _loadPhoneContactsAndSync);
    }
    if (_loadingPhone) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primary));
    }
    if (_phoneContacts.isEmpty) {
      return Center(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.contacts_outlined, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No contacts found',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ));
    }

    final grouped = _groupedPhone;
    return ListView.builder(
      itemCount: grouped.keys.length,
      itemBuilder: (_, i) {
        final letter = grouped.keys.elementAt(i);
        final contacts = grouped[letter]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(letter,
                  style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13)),
            ),
            ...contacts.map((c) {
              final phone =
                  c.phones.first.number.replaceAll(RegExp(r'\s+|-|\(|\)'), '');
              final appUser = _appUsers.where((u) {
                final up = (u['phone'] as String? ?? '')
                    .replaceAll(RegExp(r'\s+|-|\(|\)'), '');
                final minLen = phone.length > 9 ? 9 : phone.length;
                return up.endsWith(phone.substring(phone.length - minLen)) ||
                    phone.endsWith(up.substring(
                        up.length > minLen ? up.length - minLen : 0));
              }).firstOrNull;

              return _PhoneContactTile(
                contact: c,
                appUser: appUser,
                onTapChat: appUser != null
                    ? () => _startChat(appUser['id'], c.displayName)
                    : null,
                onInvite: () => _showInviteSheet(c),
              );
            }),
          ],
        );
      },
    );
  }

  void _showInviteSheet(Contact contact) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final phone = contact.phones.isNotEmpty ? contact.phones.first.number : '';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
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
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: _colorForName(contact.displayName),
                backgroundImage: contact.photo != null
                    // ── FIX: explicit cast ──────────────────────
                    ? MemoryImage(Uint8List.fromList(contact.photo!))
                        as ImageProvider
                    : null,
                child: contact.photo == null
                    ? Text(
                        contact.displayName.isNotEmpty
                            ? contact.displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20))
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contact.displayName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(phone,
                      style:
                          TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                ],
              )),
            ]),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle),
              child: const Icon(Icons.person_search_rounded,
                  color: AppTheme.primary),
            ),
            title: const Text('Search by phone number',
                style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () {
              Navigator.pop(context);
              _searchCtrl.text = phone;
              _onSearch(phone);
              _tabCtrl.animateTo(0);
            },
          ),
          ListTile(
            leading: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(Icons.share_rounded, color: Colors.green),
            ),
            title: const Text('Invite to WhatsApp Clone',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Send an invitation link'),
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  Color _colorForName(String name) {
    final colors = [
      AppTheme.primary,
      Colors.blue,
      Colors.purple,
      Colors.orange,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink
    ];
    if (name.isEmpty) return AppTheme.primary;
    return colors[name.codeUnitAt(0) % colors.length];
  }
}

// ── App User Tile ─────────────────────────────────────────────────────────

class _AppUserTile extends StatelessWidget {
  final dynamic user;
  final VoidCallback onTap;
  const _AppUserTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOnline = user['is_online'] == true || user['is_online'] == 1;
    final name = (user['display_name'] ?? user['name']) as String;

    // ── Safely get Uint8List photo ────────────────────────────────
    Uint8List? photo;
    final rawPhoto = user['device_photo'];
    if (rawPhoto is Uint8List) {
      photo = rawPhoto;
    } else if (rawPhoto is List) {
      try {
        photo = Uint8List.fromList(rawPhoto.cast<int>());
      } catch (_) {}
    }

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Stack(children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppTheme.primary,
              // ── FIX: explicit cast ──────────────────────────────
              backgroundImage: photo != null
                  ? MemoryImage(photo) as ImageProvider
                  : user['avatar_url'] != null
                      ? CachedNetworkImageProvider(user['avatar_url'])
                      : null,
              child: (photo == null && user['avatar_url'] == null)
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18))
                  : null,
            ),
            if (isOnline)
              Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: isDark ? AppTheme.darkBg : Colors.white,
                          width: 2),
                    ),
                  )),
          ]),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15.5)),
              const SizedBox(height: 2),
              Text(user['about'] ?? user['phone'] ?? '',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          )),
          if (isOnline)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('online',
                  style: TextStyle(
                      color: Color(0xFF25D366),
                      fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ),
        ]),
      ),
    );
  }
}

// ── Phone Contact Tile ────────────────────────────────────────────────────

class _PhoneContactTile extends StatelessWidget {
  final Contact contact;
  final dynamic appUser;
  final VoidCallback? onTapChat;
  final VoidCallback onInvite;

  const _PhoneContactTile({
    required this.contact,
    this.appUser,
    this.onTapChat,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    final phone = contact.phones.isNotEmpty ? contact.phones.first.number : '';
    final isOnApp = appUser != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: isOnApp ? onTapChat : onInvite,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(children: [
          Stack(children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: _colorForName(contact.displayName),
              // ── FIX: explicit cast ──────────────────────────────
              backgroundImage: contact.photo != null
                  ? MemoryImage(Uint8List.fromList(contact.photo!))
                      as ImageProvider
                  : null,
              child: contact.photo == null
                  ? Text(
                      contact.displayName.isNotEmpty
                          ? contact.displayName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18))
                  : null,
            ),
            if (isOnApp)
              Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: isDark ? AppTheme.darkBg : Colors.white,
                          width: 2),
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 8),
                  )),
          ]),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(contact.displayName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15.5)),
              const SizedBox(height: 2),
              Text(
                isOnApp ? 'On WhatsApp Clone' : phone,
                style: TextStyle(
                  color: isOnApp ? AppTheme.primary : Colors.grey.shade500,
                  fontSize: 13,
                  fontWeight: isOnApp ? FontWeight.w500 : FontWeight.normal,
                ),
              ),
            ],
          )),
          isOnApp
              ? Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Chat',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                )
              : Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Invite',
                      style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
        ]),
      ),
    );
  }

  Color _colorForName(String name) {
    final colors = [
      AppTheme.primary,
      Colors.blue,
      Colors.purple,
      Colors.orange,
      Colors.red,
      Colors.teal,
      Colors.indigo,
      Colors.pink
    ];
    if (name.isEmpty) return AppTheme.primary;
    return colors[name.codeUnitAt(0) % colors.length];
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label, sub;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction(
      {required this.icon,
      required this.label,
      required this.sub,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        title: Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(sub,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
      );
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Text(text,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: Colors.grey.shade500)),
      );
}

class _EmptySearch extends StatelessWidget {
  final String query;
  const _EmptySearch({required this.query});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(children: [
          Icon(Icons.search_off_rounded, size: 56, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text('No results for "$query"',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text('Try the full phone number with country code',
              style: TextStyle(color: Colors.grey.shade500),
              textAlign: TextAlign.center),
        ]),
      );
}

class _EmptyAppState extends StatelessWidget {
  final int phoneCount;
  final VoidCallback onRefresh;
  const _EmptyAppState({required this.phoneCount, required this.onRefresh});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(children: [
          Icon(Icons.people_outline_rounded,
              size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('None of your contacts are on WhatsApp Clone yet',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            phoneCount > 0
                ? 'Checked $phoneCount contacts. Invite them!'
                : 'Search by phone number to find someone.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500, height: 1.5),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ]),
      );
}

class _PermissionDenied extends StatelessWidget {
  final VoidCallback onRetry;
  const _PermissionDenied({required this.onRetry});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.contacts_rounded,
                color: Colors.orange, size: 40),
          ),
          const SizedBox(height: 20),
          const Text('Contacts permission required',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 10),
          Text('Grant contacts permission to find your contacts.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500, height: 1.5)),
          const SizedBox(height: 24),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            OutlinedButton(
              onPressed: openAppSettings,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('Open Settings'),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              child: const Text('Try Again'),
            ),
          ]),
        ]),
      );
}
