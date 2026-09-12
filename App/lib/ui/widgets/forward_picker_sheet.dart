import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telegramclone/core/constants.dart';
import 'package:telegramclone/core/theme.dart';
import 'package:telegramclone/core/theme_extensions.dart';
import 'package:telegramclone/data/models/chat.dart';
import 'package:telegramclone/providers/auth_provider.dart';
import 'package:telegramclone/providers/chats_provider.dart';
import 'package:telegramclone/ui/widgets/avatar_widget.dart';

/// Opens the chat picker used by "Переслать". Returns the picked chat id or
/// null on dismiss.
Future<ChatModel?> showForwardPicker(BuildContext context) {
  return showModalBottomSheet<ChatModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.tileHighlight,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.7,
      child: _ForwardPicker(),
    ),
  );
}

class _ForwardPicker extends ConsumerStatefulWidget {
  const _ForwardPicker();

  @override
  ConsumerState<_ForwardPicker> createState() => _ForwardPickerState();
}

class _ForwardPickerState extends ConsumerState<_ForwardPicker> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authProvider).user?.id ?? '';
    final chatsAsync = ref.watch(chatsListProvider);

    return Column(
      children: [
        const SizedBox(height: 8),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.forward_outlined, color: Colors.white70),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Переслать в…',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: _searchCtrl,
            autofocus: false,
            onChanged: (v) => setState(() => _query = v.trim()),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              prefixIcon: Icon(Icons.search, color: context.subtitleColor),
              hintText: 'Поиск',
              border: const OutlineInputBorder(borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: chatsAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.teal),
            ),
            error: (e, _) => Center(
              child: Text(
                'Не удалось загрузить чаты',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            ),
            data: (chats) {
              final filtered = _filter(chats, userId);
              if (filtered.isEmpty) {
                return Center(
                  child: Text(
                    'Ничего не найдено',
                    style: TextStyle(color: context.subtitleColor),
                  ),
                );
              }
              return ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  indent: 72,
                  color: context.dividerColor,
                ),
                itemBuilder: (_, i) {
                  final chat = filtered[i];
                  final title = chat.displayTitle(userId);
                  final avatarPath = chat.peerAvatarUrl(userId);
                  return ListTile(
                    leading: AvatarWidget(
                      imageUrl: avatarPath != null && avatarPath.isNotEmpty
                          ? AppConstants.mediaUrl(avatarPath)
                          : null,
                      name: title,
                      size: 44,
                      isSaved: chat.isSaved,
                    ),
                    title: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: chat.type == ChatType.group
                        ? Text(
                            '${chat.members.length} участников',
                            style: TextStyle(
                              color: context.subtitleColor,
                              fontSize: 13,
                            ),
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(chat),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  List<ChatModel> _filter(List<ChatModel> chats, String userId) {
    final saved = chats.where((c) => c.isSaved).toList();
    final rest = chats.where((c) => !c.isSaved).toList();
    Iterable<ChatModel> matching(Iterable<ChatModel> src) {
      if (_query.isEmpty) return src;
      final q = _query.toLowerCase();
      return src.where((c) {
        if (c.isSaved && 'избранное'.contains(q)) return true;
        if (c.displayTitle(userId).toLowerCase().contains(q)) return true;
        for (final m in c.members) {
          final u = m.user;
          if (u == null) continue;
          if (u.displayName.toLowerCase().contains(q)) return true;
          if (u.username?.toLowerCase().contains(q) ?? false) return true;
        }
        return false;
      });
    }

    return [...matching(saved), ...matching(rest)];
  }
}
