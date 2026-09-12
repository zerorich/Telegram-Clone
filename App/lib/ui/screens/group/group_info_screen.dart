import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:telegramclone/core/di.dart';
import 'package:telegramclone/core/theme_extensions.dart';
import 'package:telegramclone/data/models/chat_member.dart';
import 'package:telegramclone/providers/auth_provider.dart';
import 'package:telegramclone/providers/chats_provider.dart';
import 'package:telegramclone/ui/widgets/avatar_widget.dart';

class GroupInfoScreen extends ConsumerStatefulWidget {
  final String chatId;

  const GroupInfoScreen({super.key, required this.chatId});

  @override
  ConsumerState<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends ConsumerState<GroupInfoScreen> {
  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(chatDetailProvider(widget.chatId));
    final userId = ref.watch(authProvider).user?.id ?? '';

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      appBar: AppBar(
        title: const Text('Информация о группе'),
        backgroundColor: context.appBarBg,
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (d) {
          final chat = d.chat;
          final myRole = d.members
              .where((m) => m.userId == userId)
              .map((m) => m.role)
              .firstOrNull;
          final isAdmin =
              myRole == MemberRole.admin || myRole == MemberRole.owner;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Center(
                child: GestureDetector(
                  onTap: isAdmin ? () => _changeAvatar() : null,
                  child: AvatarWidget(
                    imageUrl: chat.fullAvatarUrl,
                    name: chat.name ?? 'Группа',
                    size: 96,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(chat.name ?? 'Группа'),
                trailing: isAdmin ? const Icon(Icons.edit) : null,
                onTap: isAdmin ? () => _editName(chat.name ?? '') : null,
              ),
              const Divider(),
              const ListTile(
                title: Text('Участники', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              ...d.members.map((m) => ListTile(
                    leading: AvatarWidget(
                      imageUrl: m.user?.fullAvatarUrl,
                      name: m.user?.displayName ?? '',
                      size: 40,
                    ),
                    title: Text(m.user?.displayName ?? m.userId),
                    subtitle: Text(_roleLabel(m.role)),
                  ),),
              if (isAdmin)
                ListTile(
                  leading: const Icon(Icons.person_add),
                  title: const Text('Добавить участников'),
                  onTap: () => context.push('/new-chat'),
                ),
              ListTile(
                leading: const Icon(Icons.exit_to_app, color: Colors.red),
                title: const Text('Покинуть группу', style: TextStyle(color: Colors.red)),
                onTap: () => _leave(),
              ),
            ],
          );
        },
      ),
    );
  }

  String _roleLabel(MemberRole role) {
    switch (role) {
      case MemberRole.owner:
        return 'Владелец';
      case MemberRole.admin:
        return 'Администратор';
      case MemberRole.member:
        return 'Участник';
    }
  }

  Future<void> _changeAvatar() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    await ref.read(chatRepositoryProvider).updateGroup(
          widget.chatId,
          avatarPath: file.path,
        );
    ref.invalidate(chatDetailProvider(widget.chatId));
  }

  Future<void> _editName(String current) async {
    final ctrl = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Изменить название'),
        content: TextField(controller: ctrl),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(chatRepositoryProvider).updateGroup(widget.chatId, name: name);
      ref.invalidate(chatDetailProvider(widget.chatId));
    }
  }

  Future<void> _leave() async {
    await ref.read(chatRepositoryProvider).leaveGroup(widget.chatId);
    ref.read(chatsListProvider.notifier).load(refresh: true);
    if (mounted) context.go('/home');
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    if (it.moveNext()) return it.current;
    return null;
  }
}
