import 'package:telegramclone/core/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:telegramclone/core/constants.dart';
import 'package:telegramclone/core/di.dart';
import 'package:telegramclone/core/theme.dart';
import 'package:telegramclone/core/theme_extensions.dart';
import 'package:telegramclone/data/models/user.dart';
import 'package:telegramclone/providers/ws_provider.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen>
    with SingleTickerProviderStateMixin {
  UserModel? _user;
  bool _loading = true;
  String? _error;
  bool _startingChat = false;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _load();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
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
      _animCtrl.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _startChat() async {
    if (_startingChat) return;
    setState(() => _startingChat = true);
    try {
      final chat =
          await ref.read(chatRepositoryProvider).createDirect(widget.userId);
      if (mounted) context.pushReplacement('/chat/${chat.id}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _startingChat = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: context.scaffoldBg,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.teal),
        ),
      );
    }

    final user = _user;
    if (user == null) {
      return Scaffold(
        backgroundColor: context.scaffoldBg,
        appBar: AppBar(
          backgroundColor: context.appBarBg,
          leading: const BackButton(),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_off_rounded,
                    size: 64, color: context.subtitleColor,),
                const SizedBox(height: 16),
                Text(
                  _error ?? 'Пользователь не найден',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Повторить'),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.teal,),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isOnline =
        ref.watch(onlineUsersProvider)[widget.userId] ?? false;

    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          slivers: [
            // ── Hero AppBar ─────────────────────────────────────
            SliverAppBar(
              expandedHeight: 280,
              pinned: true,
              backgroundColor: context.appBarBg,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                ),
                onPressed: () => context.pop(),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: _ProfileHeroHeader(
                  user: user,
                  isOnline: isOnline,
                ),
                collapseMode: CollapseMode.pin,
              ),
            ),

            // ── Info cards ──────────────────────────────────────
            SliverToBoxAdapter(
              child: SlideTransition(
                position: _slideAnim,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Info card
                      _InfoCard(user: user),
                      const SizedBox(height: 12),

                      // Write button
                      SizedBox(
                        height: 52,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.teal,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _startingChat ? null : _startChat,
                          icon: _startingChat
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.message_rounded, size: 20),
                          label: Text(
                            _startingChat ? 'Открываем чат...' : 'Написать',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hero header ───────────────────────────────────────────────────────────────

class _ProfileHeroHeader extends StatelessWidget {
  final UserModel user;
  final bool isOnline;

  const _ProfileHeroHeader({required this.user, required this.isOnline});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user.avatarUrl != null && user.avatarUrl!.isNotEmpty
        ? AppConstants.mediaUrl(user.avatarUrl)
        : null;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Background: avatar or gradient
        if (avatarUrl != null)
          Image.network(
            avatarUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _gradientBg(user.displayName),
          )
        else
          _gradientBg(user.displayName),

        // Gradient overlay for readability
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black87],
              stops: [0.4, 1.0],
            ),
          ),
        ),

        // Name + status at bottom
        Positioned(
          left: 20,
          right: 20,
          bottom: 20,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                user.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  shadows: [
                    Shadow(blurRadius: 8, color: Colors.black54),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          isOnline ? const Color(0xFF4CAF50) : Colors.white38,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isOnline ? 'в сети' : 'не в сети',
                    style: TextStyle(
                      color: isOnline
                          ? const Color(0xFF81C784)
                          : Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _gradientBg(String name) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1C3A5C), Color(0xFF17212B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 100,
            fontWeight: FontWeight.w300,
          ),
        ),
      ),
    );
  }
}

// ── Info card ─────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final UserModel user;

  const _InfoCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final items = <_InfoRow>[
      if (user.username != null && user.username!.isNotEmpty)
        _InfoRow(
          icon: Icons.alternate_email_rounded,
          label: 'Имя пользователя',
          value: '@${user.username}',
          canCopy: true,
        ),
      _InfoRow(
        icon: Icons.person_rounded,
        label: 'Имя',
        value: user.displayName,
        canCopy: false,
      ),
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: context.tileHighlight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (int i = 0; i < items.length; i++) ...[
            _InfoRowTile(row: items[i]),
            if (i < items.length - 1)
              Divider(
                height: 1,
                indent: 56,
                color: context.dividerColor,
              ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow {
  final IconData icon;
  final String label;
  final String value;
  final bool canCopy;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.canCopy,
  });
}

class _InfoRowTile extends StatelessWidget {
  final _InfoRow row;

  const _InfoRowTile({required this.row});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${row.label}: ${row.value}',
      child: ListTile(
      leading: Icon(row.icon, color: AppColors.teal, size: 22),
      title: Text(
        row.value,
        style: TextStyle(color: context.primaryText, fontSize: 15.5),
      ),
      subtitle: Text(
        row.label,
        style: TextStyle(color: context.subtitleColor, fontSize: 12.5),
      ),
      trailing: row.canCopy
          ? Semantics(
              label: 'Скопировать ${row.label}',
              button: true,
              child: IconButton(
              icon: Icon(Icons.copy_rounded,
                  size: 18, color: context.subtitleColor,),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: row.value));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Скопировано')),
                );
              },
            ),
            )
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    );
  }
}
