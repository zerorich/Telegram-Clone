import 'package:telegramclone/core/error_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:telegramclone/core/constants.dart';
import 'package:telegramclone/core/di.dart';
import 'package:telegramclone/core/theme.dart';
import 'package:telegramclone/providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with SingleTickerProviderStateMixin {
  bool _editing = false;
  late TextEditingController _nameCtrl;
  late TextEditingController _surnameCtrl;
  late TextEditingController _usernameCtrl;
  bool _loading = false;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    final u = ref.read(authProvider).user;
    _nameCtrl = TextEditingController(text: u?.name ?? '');
    _surnameCtrl = TextEditingController(text: u?.surname ?? '');
    _usernameCtrl = TextEditingController(text: u?.username ?? '');

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _surnameCtrl.dispose();
    _usernameCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      final user = await ref.read(usersApiProvider).updateMe(
            name: _nameCtrl.text.trim(),
            surname: _surnameCtrl.text.trim().isEmpty
                ? null
                : _surnameCtrl.text.trim(),
            username: _usernameCtrl.text.trim().isEmpty
                ? null
                : _usernameCtrl.text.trim(),
          );
      ref.read(authProvider.notifier).setUser(user);
      if (mounted) setState(() => _editing = false);
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

  Future<void> _changeAvatar() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    setState(() => _loading = true);
    try {
      final user = await ref.read(usersApiProvider).uploadAvatar(file.path);
      ref.read(authProvider.notifier).setUser(user);
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

  Future<void> _confirmLogout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkTileHighlight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Выйти из аккаунта',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        content: const Text(
          'Вы уверены, что хотите выйти?',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена',
                style: TextStyle(color: AppColors.darkSubtitle)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(authProvider.notifier).logout();
    if (mounted) context.go('/auth/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null) {
      return const Scaffold(
        backgroundColor: AppColors.darkBg,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.teal),
        ),
      );
    }

    final avatarUrl = user.avatarUrl != null && user.avatarUrl!.isNotEmpty
        ? AppConstants.mediaUrl(user.avatarUrl)
        : null;

    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          slivers: [
            // ── Hero AppBar ─────────────────────────────────────
            SliverAppBar(
              expandedHeight: 260,
              pinned: true,
              backgroundColor: AppColors.darkAppBar,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                ),
                onPressed: () => context.pop(),
              ),
              actions: [
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )
                else
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: IconButton(
                      key: ValueKey(_editing),
                      icon: Icon(
                        _editing ? Icons.check_rounded : Icons.edit_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        if (_editing) {
                          _save();
                        } else {
                          setState(() => _editing = true);
                        }
                      },
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.settings_rounded, color: Colors.white),
                  onPressed: () => context.push('/settings'),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background
                    if (avatarUrl != null)
                      Image.network(
                        avatarUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _defaultBg(),
                      )
                    else
                      _defaultBg(),

                    // Overlay gradient
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

                    // Avatar + camera overlay
                    Positioned(
                      left: 20,
                      bottom: 16,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          GestureDetector(
                            onTap: _changeAvatar,
                            child: Stack(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white24,
                                      width: 2,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: avatarUrl != null
                                        ? Image.network(
                                            avatarUrl,
                                            width: 72,
                                            height: 72,
                                            fit: BoxFit.cover,
                                          )
                                        : Container(
                                            width: 72,
                                            height: 72,
                                            color: AppColors.tealDark,
                                            alignment: Alignment.center,
                                            child: Text(
                                              user.name.isNotEmpty
                                                  ? user.name[0].toUpperCase()
                                                  : '?',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 30,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 24,
                                    height: 24,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.teal,
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                user.displayName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  shadows: [
                                    Shadow(
                                        blurRadius: 8,
                                        color: Colors.black54),
                                  ],
                                ),
                              ),
                              if (user.username != null &&
                                  user.username!.isNotEmpty)
                                Text(
                                  '@${user.username}',
                                  style: TextStyle(
                                    color: AppColors.teal
                                        .withValues(alpha: 0.9),
                                    fontSize: 13.5,
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Content ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: _editing
                    ? _EditForm(
                        nameCtrl: _nameCtrl,
                        surnameCtrl: _surnameCtrl,
                        usernameCtrl: _usernameCtrl,
                        onSave: _save,
                        onCancel: () => setState(() => _editing = false),
                        loading: _loading,
                      )
                    : _ProfileInfo(user: user),
              ),
            ),

            // ── Danger zone ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.darkTileHighlight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red.withValues(alpha: 0.12),
                      ),
                      child: const Icon(Icons.logout_rounded,
                          color: Colors.redAccent, size: 20),
                    ),
                    title: const Text(
                      'Выйти из аккаунта',
                      style:
                          TextStyle(color: Colors.redAccent, fontSize: 15.5),
                    ),
                    onTap: _confirmLogout,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _defaultBg() {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1C3A5C), Color(0xFF17212B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

// ── Info view ─────────────────────────────────────────────────────────────────

class _ProfileInfo extends StatelessWidget {
  final dynamic user;

  const _ProfileInfo({required this.user});

  @override
  Widget build(BuildContext context) {
    final rows = <_Row>[
      _Row(icon: Icons.person_rounded, label: 'Имя', value: user.displayName),
      if (user.username != null && user.username!.isNotEmpty)
        _Row(
          icon: Icons.alternate_email_rounded,
          label: 'Username',
          value: '@${user.username}',
          canCopy: true,
        ),
      if (user.phone != null && user.phone!.isNotEmpty)
        _Row(
          icon: Icons.phone_rounded,
          label: 'Телефон',
          value: user.phone,
          canCopy: true,
        ),
      _Row(
        icon: Icons.email_rounded,
        label: 'Email',
        value: user.email,
        canCopy: true,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkTileHighlight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            _InfoTile(row: rows[i]),
            if (i < rows.length - 1)
              const Divider(
                  height: 1,
                  indent: 56,
                  color: AppColors.darkDivider),
          ],
        ],
      ),
    );
  }
}

class _Row {
  final IconData icon;
  final String label;
  final String value;
  final bool canCopy;

  const _Row({
    required this.icon,
    required this.label,
    required this.value,
    this.canCopy = false,
  });
}

class _InfoTile extends StatelessWidget {
  final _Row row;

  const _InfoTile({required this.row});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(row.icon, color: AppColors.teal, size: 22),
      title: Text(
        row.value,
        style: const TextStyle(color: Colors.white, fontSize: 15.5),
      ),
      subtitle: Text(
        row.label,
        style: const TextStyle(
            color: AppColors.darkSubtitle, fontSize: 12.5),
      ),
      trailing: row.canCopy
          ? IconButton(
              icon: const Icon(Icons.copy_rounded,
                  size: 18, color: AppColors.darkSubtitle),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: row.value));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Скопировано')),
                );
              },
            )
          : null,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

// ── Edit form ─────────────────────────────────────────────────────────────────

class _EditForm extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController surnameCtrl;
  final TextEditingController usernameCtrl;
  final VoidCallback onSave;
  final VoidCallback onCancel;
  final bool loading;

  const _EditForm({
    required this.nameCtrl,
    required this.surnameCtrl,
    required this.usernameCtrl,
    required this.onSave,
    required this.onCancel,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkTileHighlight,
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field(nameCtrl, 'Имя *', Icons.person_rounded),
          const SizedBox(height: 12),
          _field(surnameCtrl, 'Фамилия', Icons.badge_rounded),
          const SizedBox(height: 12),
          _field(usernameCtrl, 'Username', Icons.alternate_email_rounded),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.darkSubtitle,
                    side: const BorderSide(color: AppColors.darkDivider),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: loading ? null : onCancel,
                  child: const Text('Отмена'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: loading ? null : onSave,
                  child: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Сохранить'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, IconData icon) {
    return TextField(
      controller: ctrl,
      textCapitalization: TextCapitalization.words,
      style: const TextStyle(color: Colors.white, fontSize: 15.5),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.darkSubtitle),
        prefixIcon: Icon(icon, color: AppColors.darkSubtitle, size: 20),
        filled: true,
        fillColor: AppColors.darkInput,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
