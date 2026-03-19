// lib/screens/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../utils/app_theme.dart';
import 'chats_tab.dart';
import 'status_tab.dart';
import 'communities_tab.dart';
import 'calls_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _fabAnim;
  bool _isSearching = false;
  final _searchCtrl = TextEditingController();

  final List<Widget> _pages = const [
    ChatsTab(),
    StatusTab(),
    CommunitiesTab(),
    CallsTab(),
  ];

  @override
  void initState() {
    super.initState();
    _fabAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadConversations();
    });
  }

  @override
  void dispose() {
    _fabAnim.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    setState(() => _selectedIndex = index);
    _fabAnim.reset();
    _fabAnim.forward();
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final chat = context.watch<ChatProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final me = auth.user;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : const Color(0xFFF8F9FA),
      appBar: _isSearching
          ? _buildSearchBar(isDark)
          : _buildMainAppBar(isDark, me, chat),
      body: _pages[_selectedIndex],
      bottomNavigationBar: _buildBottomNav(isDark, chat),
      floatingActionButton: _buildFab(),
    );
  }

  // ── Main App Bar ──────────────────────────────────────────────────

  PreferredSizeWidget _buildMainAppBar(
      bool isDark, dynamic me, ChatProvider chat) {
    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.primaryDark,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      titleSpacing: 16,
      title: Row(
        children: [
          // App name with gradient text
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Colors.white, Color(0xFFB2DFDB)],
            ).createShader(bounds),
            child: Text(
              _getTitle(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 22,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
      actions: [
        // Camera
        _AppBarButton(
          icon: Icons.camera_alt_outlined,
          onTap: () {},
          tooltip: 'Camera',
        ),

        // Search
        _AppBarButton(
          icon: Icons.search_rounded,
          onTap: () => setState(() => _isSearching = true),
          tooltip: 'Search',
        ),

        // Profile avatar + menu
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => _showProfileMenu(context),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white24,
              backgroundImage: me?.avatarUrl != null
                  ? CachedNetworkImageProvider(me!.avatarUrl!)
                  : null,
              child: me?.avatarUrl == null
                  ? Text(
                      me?.name.isNotEmpty == true
                          ? me!.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14))
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  // ── Search Bar ────────────────────────────────────────────────────

  PreferredSizeWidget _buildSearchBar(bool isDark) {
    return AppBar(
      backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.primaryDark,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => setState(() {
          _isSearching = false;
          _searchCtrl.clear();
        }),
      ),
      title: TextField(
        controller: _searchCtrl,
        autofocus: true,
        style: const TextStyle(color: Colors.white, fontSize: 16),
        cursorColor: Colors.white,
        decoration: const InputDecoration(
          hintText: 'Search...',
          hintStyle: TextStyle(color: Colors.white60),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
      actions: [
        if (_searchCtrl.text.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => setState(() => _searchCtrl.clear()),
          ),
      ],
    );
  }

  // ── Bottom Navigation ─────────────────────────────────────────────

  Widget _buildBottomNav(bool isDark, ChatProvider chat) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.chat_bubble_outline_rounded,
                activeIcon: Icons.chat_bubble_rounded,
                label: 'Chats',
                index: 0,
                selected: _selectedIndex == 0,
                badgeCount: chat.totalUnread,
                onTap: () => _onTabChanged(0),
                isDark: isDark,
              ),
              _NavItem(
                icon: Icons.circle_outlined,
                activeIcon: Icons.circle,
                label: 'Updates',
                index: 1,
                selected: _selectedIndex == 1,
                badgeCount: 0,
                onTap: () => _onTabChanged(1),
                isDark: isDark,
              ),
              _NavItem(
                icon: Icons.people_outline_rounded,
                activeIcon: Icons.people_rounded,
                label: 'Communities',
                index: 2,
                selected: _selectedIndex == 2,
                badgeCount: 0,
                onTap: () => _onTabChanged(2),
                isDark: isDark,
              ),
              _NavItem(
                icon: Icons.call_outlined,
                activeIcon: Icons.call_rounded,
                label: 'Calls',
                index: 3,
                selected: _selectedIndex == 3,
                badgeCount: 0,
                onTap: () => _onTabChanged(3),
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── FAB ───────────────────────────────────────────────────────────

  Widget? _buildFab() {
    if (_selectedIndex == 0) {
      return ScaleTransition(
        scale: CurvedAnimation(
          parent: _fabAnim,
          curve: Curves.elasticOut,
        ),
        child: FloatingActionButton.extended(
          onPressed: () => context.push('/new-chat'),
          backgroundColor: AppTheme.primary,
          foregroundColor: Colors.white,
          elevation: 4,
          icon: const Icon(Icons.add_comment_rounded),
          label: const Text(
            'New chat',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    if (_selectedIndex == 3) {
      return ScaleTransition(
        scale: CurvedAnimation(parent: _fabAnim, curve: Curves.elasticOut),
        child: FloatingActionButton(
          onPressed: () {},
          backgroundColor: AppTheme.primary,
          child: const Icon(Icons.add_call, color: Colors.white),
        ),
      );
    }

    if (_selectedIndex == 1) {
      return ScaleTransition(
        scale: CurvedAnimation(parent: _fabAnim, curve: Curves.elasticOut),
        child: FloatingActionButton(
          onPressed: () {},
          backgroundColor: AppTheme.primary,
          child: const Icon(Icons.edit_rounded, color: Colors.white),
        ),
      );
    }

    return null;
  }

  // ── Profile Menu ──────────────────────────────────────────────────

  void _showProfileMenu(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.read<AuthProvider>();
    final me = auth.user;

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

            // User info header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.primary,
                    backgroundImage: me?.avatarUrl != null
                        ? CachedNetworkImageProvider(me!.avatarUrl!)
                        : null,
                    child: me?.avatarUrl == null
                        ? Text(
                            me?.name.isNotEmpty == true
                                ? me!.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold))
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          me?.name ?? '',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          me?.phone ?? '',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon:
                        const Icon(Icons.edit_rounded, color: AppTheme.primary),
                    onPressed: () {
                      Navigator.pop(context);
                      context.push('/profile');
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Menu items
            _menuItem(
                context, Icons.person_outline_rounded, 'Profile', Colors.blue,
                () {
              Navigator.pop(context);
              context.push('/profile');
            }),
            _menuItem(context, Icons.group_outlined, 'New group', Colors.green,
                () {
              Navigator.pop(context);
              context.push('/new-group');
            }),
            _menuItem(context, Icons.star_border_rounded, 'Starred messages',
                Colors.amber, () {
              Navigator.pop(context);
            }),
            _menuItem(context, Icons.settings_outlined, 'Settings', Colors.grey,
                () {
              Navigator.pop(context);
            }),
            _menuItem(context, Icons.logout_rounded, 'Logout', Colors.red, () {
              Navigator.pop(context);
              auth.logout();
            }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _menuItem(BuildContext context, IconData icon, String label,
      Color color, VoidCallback onTap) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
      onTap: onTap,
      dense: true,
    );
  }

  String _getTitle() {
    switch (_selectedIndex) {
      case 1:
        return 'Updates';
      case 2:
        return 'Communities';
      case 3:
        return 'Calls';
      default:
        return 'WhatsApp';
    }
  }
}

// ── App Bar Button ────────────────────────────────────────────────────────

class _AppBarButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _AppBarButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

// ── Custom Nav Item ───────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;
  final bool isDark;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.index,
    required this.selected,
    required this.badgeCount,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    selected ? activeIcon : icon,
                    key: ValueKey(selected),
                    color: selected
                        ? AppTheme.primary
                        : (isDark ? Colors.white54 : Colors.grey.shade600),
                    size: 24,
                  ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: -6,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark ? AppTheme.darkBg : Colors.white,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? AppTheme.primary
                    : (isDark ? Colors.white54 : Colors.grey.shade600),
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
