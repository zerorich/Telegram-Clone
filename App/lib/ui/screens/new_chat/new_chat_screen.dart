import 'package:telegramclone/core/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:telegramclone/core/di.dart';
import 'package:telegramclone/data/models/user.dart';
import 'package:telegramclone/ui/widgets/avatar_widget.dart';

class NewChatScreen extends ConsumerStatefulWidget {
  const NewChatScreen({super.key});

  @override
  ConsumerState<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends ConsumerState<NewChatScreen> {
  final _searchCtrl = TextEditingController();
  List<UserModel> _users = [];
  bool _loading = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    if (q.length < 2) {
      setState(() => _users = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final users = await ref.read(usersApiProvider).search(q);
      setState(() => _users = users);
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

  Future<void> _openChat(UserModel user) async {
    setState(() => _loading = true);
    try {
      final chat = await ref.read(chatRepositoryProvider).createDirect(user.id);
      if (mounted) {
        context.go('/chat/${chat.id}');
      }
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
      appBar: AppBar(title: const Text('New message')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search by username or phone',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _search,
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: _users.isEmpty
                ? const Center(child: Text('Search for users'))
                : ListView.builder(
                    itemCount: _users.length,
                    itemBuilder: (_, i) {
                      final u = _users[i];
                      return ListTile(
                        leading: AvatarWidget(
                          imageUrl: u.fullAvatarUrl,
                          name: u.displayName,
                        ),
                        title: Text(u.displayName),
                        subtitle: Text(u.username ?? u.phone),
                        onTap: () => _openChat(u),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
