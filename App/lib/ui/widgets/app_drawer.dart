import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:telegramclone/core/theme.dart';
import 'package:telegramclone/data/models/user.dart';
import 'package:telegramclone/providers/auth_provider.dart';
import 'package:telegramclone/providers/theme_provider.dart';
import 'package:telegramclone/ui/widgets/avatar_widget.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final isDark = ref.watch(themeModeProvider);

    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.82,
      child: Column(
        children: [
          _DrawerHeader(user: user, isDark: isDark, onToggleTheme: () {
            ref.read(themeModeProvider.notifier).toggle();
          }),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _DrawerItem(
                  icon: Icons.person_outline,
                  label: 'Мой профиль',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/profile');
                  },
                ),
                const Divider(height: 1),
                _DrawerItem(
                  icon: Icons.group_add_outlined,
                  label: 'Создать группу',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/new-group');
                  },
                ),
                _DrawerItem(
                  icon: Icons.person_search_outlined,
                  label: 'Контакты',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/new-chat');
                  },
                ),
                _DrawerItem(
                  icon: Icons.settings_outlined,
                  label: 'Настройки',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/settings');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({
    required this.user,
    required this.isDark,
    required this.onToggleTheme,
  });

  final UserModel? user;
  final bool isDark;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final name = user?.displayName ?? 'Пользователь';
    final username = user?.username;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 16,
        left: 16,
        right: 12,
        bottom: 20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A1A2E),
            Color(0xFF16213E),
            Color(0xFF0F0F0F),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarWidget(
                imageUrl: user?.fullAvatarUrl,
                name: name,
                size: 64,
              ),
              const Spacer(),
              IconButton(
                onPressed: onToggleTheme,
                icon: Icon(isDark ? Icons.wb_sunny_outlined : Icons.dark_mode_outlined),
                color: Colors.white70,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (username != null && username.isNotEmpty)
            Text(
              '@$username',
              style: const TextStyle(color: AppColors.darkSubtitle, fontSize: 14),
            ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.darkSubtitle, size: 26),
      title: Text(label, style: const TextStyle(fontSize: 16)),
      onTap: onTap,
      horizontalTitleGap: 12,
    );
  }
}
