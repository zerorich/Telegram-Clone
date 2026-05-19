import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:telegramclone/core/di.dart';
import 'package:telegramclone/core/theme.dart';
import 'package:telegramclone/data/models/user.dart';
import 'package:telegramclone/ui/widgets/avatar_widget.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  UserModel? _user;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = await ref.read(usersApiProvider).getUser(widget.userId);
      if (!mounted) return;
      setState(() {
        _user = user;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _startChat() async {
    final chat =
        await ref.read(chatRepositoryProvider).createDirect(widget.userId);
    if (mounted) context.push('/chat/${chat.id}');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.darkBg,
        body: Center(child: CircularProgressIndicator(color: AppColors.teal)),
      );
    }
    final user = _user;
    if (user == null) {
      return Scaffold(
        backgroundColor: AppColors.darkBg,
        appBar: AppBar(backgroundColor: AppColors.darkAppBar),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _error ?? 'Пользователь не найден',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const Text('Повторить')),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkAppBar,
        title: const Text('Профиль'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            AvatarWidget(
              imageUrl: user.fullAvatarUrl,
              name: user.displayName,
              size: 96,
            ),
            const SizedBox(height: 16),
            Text(
              user.displayName,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                  ),
            ),
            if (user.username != null && user.username!.isNotEmpty)
              Text(
                '@${user.username}',
                style: const TextStyle(color: AppColors.darkSubtitle),
              ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _startChat,
              icon: const Icon(Icons.message),
              label: const Text('Написать'),
            ),
          ],
        ),
      ),
    );
  }
}
