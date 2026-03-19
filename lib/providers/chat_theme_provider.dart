// lib/providers/chat_theme_provider.dart

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ChatBackground {
  final String id;
  final String label;
  final Color? solidColor;
  final List<Color>? gradientColors;
  final String? patternAsset;

  const ChatBackground({
    required this.id,
    required this.label,
    this.solidColor,
    this.gradientColors,
    this.patternAsset,
  });
}

class ChatThemeProvider extends ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  String _selectedBgId = 'default';

  String get selectedBgId => _selectedBgId;

  static const List<ChatBackground> backgrounds = [
    ChatBackground(
      id: 'default',
      label: 'Default',
      gradientColors: [Color(0xFFEFE7DE), Color(0xFFE5DDD5)],
    ),
    ChatBackground(
      id: 'dark',
      label: 'Dark',
      solidColor: Color(0xFF111B21),
    ),
    ChatBackground(
      id: 'midnight',
      label: 'Midnight',
      gradientColors: [Color(0xFF0D1117), Color(0xFF161B22)],
    ),
    ChatBackground(
      id: 'ocean',
      label: 'Ocean',
      gradientColors: [Color(0xFF0077B6), Color(0xFF023E8A)],
    ),
    ChatBackground(
      id: 'forest',
      label: 'Forest',
      gradientColors: [Color(0xFF1B4332), Color(0xFF2D6A4F)],
    ),
    ChatBackground(
      id: 'sunset',
      label: 'Sunset',
      gradientColors: [Color(0xFFFF6B35), Color(0xFFFF8C00)],
    ),
    ChatBackground(
      id: 'purple',
      label: 'Purple',
      gradientColors: [Color(0xFF5B2C8D), Color(0xFF7B2FBE)],
    ),
    ChatBackground(
      id: 'rose',
      label: 'Rose',
      gradientColors: [Color(0xFFFF4E7E), Color(0xFFFF8FAB)],
    ),
    ChatBackground(
      id: 'mint',
      label: 'Mint',
      gradientColors: [Color(0xFF00B4D8), Color(0xFF90E0EF)],
    ),
    ChatBackground(
      id: 'sand',
      label: 'Sand',
      gradientColors: [Color(0xFFF4A261), Color(0xFFE9C46A)],
    ),
    ChatBackground(
      id: 'slate',
      label: 'Slate',
      gradientColors: [Color(0xFF334155), Color(0xFF475569)],
    ),
    ChatBackground(
      id: 'white',
      label: 'White',
      solidColor: Color(0xFFFFFFFF),
    ),
  ];

  ChatThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final saved = await _storage.read(key: 'chat_bg');
    if (saved != null) {
      _selectedBgId = saved;
      notifyListeners();
    }
  }

  Future<void> setBackground(String id) async {
    _selectedBgId = id;
    await _storage.write(key: 'chat_bg', value: id);
    notifyListeners();
  }

  ChatBackground get currentBackground =>
      backgrounds.firstWhere((b) => b.id == _selectedBgId,
          orElse: () => backgrounds.first);

  Widget buildBackground(BuildContext context) {
    final bg = currentBackground;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (bg.solidColor != null) {
      return Container(color: bg.solidColor);
    }

    if (bg.gradientColors != null) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark && bg.id == 'default'
                ? [const Color(0xFF111B21), const Color(0xFF1A2530)]
                : bg.gradientColors!,
          ),
        ),
      );
    }

    return Container(
        color: isDark ? const Color(0xFF111B21) : const Color(0xFFEFE7DE));
  }
}
