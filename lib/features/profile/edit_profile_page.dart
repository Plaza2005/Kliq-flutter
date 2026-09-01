import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/session.dart';
import '../../core/theme.dart';
import '../discover/discover_common.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _displayName;
  late final TextEditingController _username;
  late final TextEditingController _bio;
  String? _avatarUrl;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final u = context.read<Session>().user ?? {};
    _displayName =
        TextEditingController(text: u['displayName']?.toString() ?? '');
    _username = TextEditingController(text: u['username']?.toString() ?? '');
    _bio = TextEditingController(text: u['bio']?.toString() ?? '');
    _avatarUrl = u['avatarUrl']?.toString();
  }

  @override
  void dispose() {
    _displayName.dispose();
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    try {
      final picked = await ImagePicker()
          .pickImage(source: ImageSource.gallery, maxWidth: 800);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final res = await Api.instance.upload(
          '/upload', MultipartFile.fromBytes(bytes, filename: picked.name));
      if (res is Map && res['url'] != null && mounted) {
        setState(() => _avatarUrl = res['url'].toString());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final session = context.read<Session>();
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final patch = {
      'displayName': _displayName.text.trim(),
      'username': _username.text.trim().toLowerCase(),
      'bio': _bio.text.trim(),
      if (_avatarUrl != null) 'avatarUrl': _avatarUrl,
    };
    try {
      await Api.instance.patch('/auth/me', body: patch);
      session.updateUser(patch);
      messenger.showSnackBar(
          const SnackBar(content: Text('Profile updated')));
      router.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Save failed: $e')));
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save',
                    style: TextStyle(
                        color: KliqColors.cyan, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: GestureDetector(
              onTap: _pickAvatar,
              child: Column(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: KliqColors.storyRing),
                    padding: const EdgeInsets.all(2.5),
                    child: ClipOval(
                      child: SizedBox(
                          width: 96, height: 96, child: NetImg(_avatarUrl)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Change photo',
                      style: TextStyle(
                          color: KliqColors.cyan,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _field('Display name', _displayName),
          _field('Username', _username),
          _field('Bio', _bio, maxLines: 4, maxLength: 160),
        ],
      ),
    );
  }

  Widget _field(String label, TextEditingController controller,
      {int maxLines = 1, int? maxLength}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: KliqColors.textSecondary, fontSize: 12.5)),
          const SizedBox(height: 6),
          TextField(
              controller: controller,
              maxLines: maxLines,
              maxLength: maxLength),
        ],
      ),
    );
  }
}
