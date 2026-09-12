import 'package:telegramclone/core/error_utils.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:telegramclone/core/di.dart';
import 'package:telegramclone/data/models/user.dart';
import 'package:telegramclone/providers/chats_provider.dart';
import 'package:telegramclone/ui/widgets/avatar_widget.dart';

class NewGroupScreen extends ConsumerStatefulWidget {
  const NewGroupScreen({super.key});

  @override
  ConsumerState<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends ConsumerState<NewGroupScreen> {
  final _nameCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  final _selected = <UserModel>[];
  String? _avatarPath;
  bool _loading = false;
  List<UserModel> _searchResults = [];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.length < 2) return;
    final users = await ref.read(usersApiProvider).search(q);
    setState(() => _searchResults = users);
  }

  Future<void> _pickAvatar() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => _avatarPath = file.path);
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty || _selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter group name and select members')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final chat = await ref.read(chatRepositoryProvider).createGroup(
            name: name,
            memberIds: _selected.map((u) => u.id).toList(),
            avatarPath: _avatarPath,
          );
      ref.read(chatsListProvider.notifier).load(refresh: true);
      if (mounted) context.go('/chat/${chat.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New group')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: _pickAvatar,
            child: CircleAvatar(
              radius: 40,
              backgroundImage:
                  _avatarPath != null ? FileImage(File(_avatarPath!)) : null,
              child: _avatarPath == null
                  ? const Icon(Icons.camera_alt, size: 32)
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Group name'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              labelText: 'Add members',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: _search,
          ),
          Wrap(
            spacing: 8,
            children: _selected
                .map((u) => Chip(
                      label: Text(u.displayName),
                      onDeleted: () =>
                          setState(() => _selected.removeWhere((x) => x.id == u.id)),
                    ),)
                .toList(),
          ),
          ..._searchResults.map((u) => ListTile(
                leading: AvatarWidget(imageUrl: u.fullAvatarUrl, name: u.displayName),
                title: Text(u.displayName),
                trailing: _selected.any((s) => s.id == u.id)
                    ? const Icon(Icons.check, color: Colors.green)
                    : null,
                onTap: () {
                  setState(() {
                    if (_selected.any((s) => s.id == u.id)) {
                      _selected.removeWhere((s) => s.id == u.id);
                    } else {
                      _selected.add(u);
                    }
                  });
                },
              ),),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _loading ? null : _create,
            child: _loading
                ? const CircularProgressIndicator()
                : const Text('Create group'),
          ),
        ],
      ),
    );
  }
}
