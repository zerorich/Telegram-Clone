import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:telegramclone/core/theme.dart';
import 'package:telegramclone/data/models/user.dart';
import 'package:telegramclone/providers/auth_provider.dart';
import 'package:telegramclone/providers/theme_provider.dart';
import 'package:telegramclone/ui/widgets/avatar_widget.dart';

class AppDrawer extends ConsumerStatefulWidget {
  const AppDrawer({super.key});

  @override
  ConsumerState<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends ConsumerState<AppDrawer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animCtrl;
  late final List<Animation<double>> _itemAnims;

  static const _items = [
    _DrawerItemData(
      icon: Icons.person_rounded,
      label: 'Мой профиль',
      route: '/profile',
      color: Color(0xFF2AABEE),
    ),
    _DrawerItemData(
      icon: Icons.person_add_rounded,
      label: 'Новый чат',
      route: '/new-chat',
      color: Color(0xFF4CAF50),
    ),
    _DrawerItemData(
      icon: Icons.group_add_rounded,
      label: 'Создать группу',
      route: '/new-group',
      color: Color(0xFFFF9800),
    ),
    _DrawerItemData(
      icon: Icons.contacts_rounded,
      label: 'Контакты',
      route: '/new-chat',
      color: Color(0xFF9C27B0),
    ),
    _DrawerItemData(
      icon: Icons.settings_rounded,
      label: 'Настройки',
      route: '/settings',
      color: Color(0xFF607D8B),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _itemAnims = List.generate(_items.length, (i) {
      final start = i * 0.12;
      final end = (start + 0.5).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _animCtrl,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );
    });

    // Start animation after drawer opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _animCtrl.forward();
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final isDark = ref.watch(themeModeProvider);

    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.84,
      backgroundColor: AppColors.darkDrawer,
      child: Column(
        children: [
          // ── Header ───────────────────────────────────────────
          _DrawerHeader(
            user: user,
            isDark: isDark,
            onToggleTheme: () => ref.read(themeModeProvider.notifier).toggle(),
            onTap: () {
              Navigator.pop(context);
              context.push('/profile');
            },
          ),

          // ── Menu items ───────────────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _items.length,
              itemBuilder: (_, i) {
                final item = _items[i];
                return AnimatedBuilder(
                  animation: _itemAnims[i],
                  builder: (context, child) => FadeTransition(
                    opacity: _itemAnims[i],
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(-0.15, 0),
                        end: Offset.zero,
                      ).animate(_itemAnims[i]),
                      child: child,
                    ),
                  ),
                  child: _DrawerItem(
                    data: item,
                    onTap: () {
                      Navigator.pop(context);
                      context.push(item.route);
                    },
                  ),
                );
              },
            ),
          ),

          // ── Divider ──────────────────────────────────────────
          const Divider(height: 1, color: AppColors.darkDivider),

          // ── Bottom: logout ────────────────────────────────────
          Padding(
            padding: EdgeInsets.only(
              left: 8,
              right: 8,
              top: 4,
              bottom: MediaQuery.paddingOf(context).bottom + 8,
            ),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red.withValues(alpha: 0.12),
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: Colors.redAccent,
                  size: 20,
                ),
              ),
              title: const Text(
                'Выйти',
                style: TextStyle(color: Colors.redAccent, fontSize: 15),
              ),
              onTap: () async {
                Navigator.pop(context);
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) context.go('/auth/login');
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Data class ────────────────────────────────────────────────────────────────

class _DrawerItemData {
  final IconData icon;
  final String label;
  final String route;
  final Color color;

  const _DrawerItemData({
    required this.icon,
    required this.label,
    required this.route,
    required this.color,
  });
}

// ── Header ────────────────────────────────────────────────────────────────────

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader({
    required this.user,
    required this.isDark,
    required this.onToggleTheme,
    required this.onTap,
  });

  final UserModel? user;
  final bool isDark;
  final VoidCallback onToggleTheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = user?.displayName ?? 'Пользователь';
    final username = user?.username;
    final statusBar = MediaQuery.paddingOf(context).top;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(
          top: statusBar + 20,
          left: 20,
          right: 12,
          bottom: 20,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1C3A5C),
              Color(0xFF17212B),
            ],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar with ring
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.teal.withValues(alpha: 0.5),
                      width: 2.5,
                    ),
                  ),
                  child: AvatarWidget(
                    imageUrl: user?.fullAvatarUrl,
                    name: name,
                    size: 68,
                  ),
                ),
                const Spacer(),
                // Theme toggle
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  child: IconButton(
                    onPressed: onToggleTheme,
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, anim) => RotationTransition(
                        turns: anim,
                        child: FadeTransition(opacity: anim, child: child),
                      ),
                      child: Icon(
                        isDark
                            ? Icons.wb_sunny_rounded
                            : Icons.dark_mode_rounded,
                        key: ValueKey(isDark),
                        color: Colors.white70,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            if (username != null && username.isNotEmpty)
              Text(
                '@$username',
                style: TextStyle(
                  color: AppColors.teal.withValues(alpha: 0.9),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              )
            else
              Text(
                'Нажмите, чтобы открыть профиль',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12.5,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Menu item ─────────────────────────────────────────────────────────────────

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({required this.data, required this.onTap});

  final _DrawerItemData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: data.color.withValues(alpha: 0.15),
          ),
          child: Icon(data.icon, color: data.color, size: 20),
        ),
        title: Text(
          data.label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: onTap,
        horizontalTitleGap: 12,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        splashColor: data.color.withValues(alpha: 0.08),
        hoverColor: data.color.withValues(alpha: 0.05),
      ),
    );
  }
}
