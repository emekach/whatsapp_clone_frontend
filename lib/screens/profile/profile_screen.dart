// lib/screens/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _api      = ApiService();
  final _picker   = ImagePicker();
  final _nameCtrl = TextEditingController();
  final _aboutCtrl = TextEditingController();
  bool _editing   = false;
  bool _saving    = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameCtrl.text  = user?.name  ?? '';
    _aboutCtrl.text = user?.about ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _aboutCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final result = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (result == null) return;

    try {
      await _api.updateAvatar(result.path);
      final data = await _api.getMe();
      if (mounted) {
        context.read<AuthProvider>().updateUser(
            context.read<AuthProvider>().user!);
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _api.updateProfile({
        'name':  _nameCtrl.text.trim(),
        'about': _aboutCtrl.text.trim(),
      });
      setState(() { _editing = false; _saving = false; });
    } catch (_) {
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user  = context.watch<AuthProvider>().user;
    final auth  = context.read<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (_editing)
            TextButton(
              onPressed: _saving ? null : _save,
              child: const Text('Save', style: TextStyle(color: Colors.white)),
            )
          else
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() => _editing = true),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 32),
            // Avatar
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 64,
                    backgroundColor: AppTheme.primary,
                    backgroundImage: user?.avatarUrl != null
                        ? CachedNetworkImageProvider(user!.avatarUrl!)
                        : null,
                    child: user?.avatarUrl == null
                        ? Text(user?.name[0].toUpperCase() ?? '?',
                            style: const TextStyle(color: Colors.white, fontSize: 40))
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: GestureDetector(
                      onTap: _pickAvatar,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: const BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // Name
                  _editing
                      ? TextField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(labelText: 'Name'),
                        )
                      : _InfoTile(
                          icon: Icons.person_outline,
                          label: 'Name',
                          value: user?.name ?? '',
                        ),
                  const SizedBox(height: 16),
                  // About
                  _editing
                      ? TextField(
                          controller: _aboutCtrl,
                          maxLines: 3,
                          decoration: const InputDecoration(labelText: 'About'),
                        )
                      : _InfoTile(
                          icon: Icons.info_outline,
                          label: 'About',
                          value: user?.about ?? '',
                        ),
                  const SizedBox(height: 16),
                  _InfoTile(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: user?.phone ?? '',
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => auth.logout(),
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text('Logout',
                          style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;

  const _InfoTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
            Text(value,
                style: const TextStyle(fontSize: 16)),
          ],
        ),
      ],
    );
  }
}
