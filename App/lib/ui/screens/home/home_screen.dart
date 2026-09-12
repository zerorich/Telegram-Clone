import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:telegramclone/core/error_utils.dart';
import 'package:telegramclone/core/theme.dart';
import 'package:telegramclone/core/theme_extensions.dart';
import 'package:telegramclone/providers/auth_provider.dart';
import 'package:telegramclone/providers/chats_provider.dart';
import 'package:telegramclone/ui/widgets/app_drawer.dart';
import 'package:telegramclone/ui/widgets/chat_tile.dart';
import 'package:telegramclone/ui/widgets/send_to_chat_sheet.dart';
import 'package:telegramclone/ui/widgets/telegram_fabs.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  String _query = '';
  late final AnimationController _appBarCtrl;
  late final Animation<double> _appBarFade;

  @override
  void initState() {
    super.initState();
    _appBarCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _appBarFade = CurvedAnimation(parent: _appBarCtrl, curve: Curves.easeOut);
    _appBarCtrl.forward();
  }

  @override
  void dispose() {
    _appBarCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authProvider).user?.id ?? '';
    final chatsAsync = ref.watch(chatsListProvider);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: context.scaffoldBg,
      drawer: const AppDrawer(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            FadeTransition(
              opacity: _appBarFade,
              child: _HomeAppBar(
                onMenu: () => _scaffoldKey.currentState?.openDrawer(),
                onSearch: () async {
                  final q = await showSearch<String?>(
                    context: context,
                    delegate: _ChatSearchDelegate(ref, userId),
                  );
                  if (q != null) setState(() => _query = q);
                },
              ),
            ),
            Expanded(
              child: chatsAsync.when(
                loading: () => const _LoadingView(),
                error: (e, _) => _ErrorView(
                  error: e,
                  onRetry: () =>
                      ref.read(chatsListProvider.notifier).load(refresh: true),
                ),
                data: (chats) {
                  final filtered = _query.isEmpty
                      ? chats
                      : chats
                          .where((c) => c
                              .displayTitle(userId)
                              .toLowerCase()
                              .contains(_query.toLowerCase()),)
                          .toList();

                  if (filtered.isEmpty) {
                    return _EmptyChatsView(hasQuery: _query.isNotEmpty);
                  }

                  return RefreshIndicator(
                    color: AppColors.teal,
                    backgroundColor: context.tileHighlight,
                    onRefresh: () =>
                        ref.read(chatsListProvider.notifier).load(refresh: true),
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => _AnimatedChatTileWrapper(
                        index: i,
                        child: Column(
                          children: [
                            Semantics(
                              label: 'Чат ${filtered[i].displayTitle(userId)}',
                              button: true,
                              child: ChatTile(
                                chat: filtered[i],
                                currentUserId: userId,
                                onTap: () =>
                                    context.push('/chat/${filtered[i].id}'),
                              ),
                            ),
                            if (i < filtered.length - 1)
                              Divider(
                                height: 1,
                                indent: 78,
                                endIndent: 0,
                                color: context.dividerColor,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: TelegramFabs(
        onEdit: () => _showNewChatOptions(context),
        onCamera: () => _openCameraAndSend(context),
      ),
    );
  }

  Future<void> _openCameraAndSend(BuildContext context) async {
    final cam = await Permission.camera.request();
    if (!mounted) return;
    if (!cam.isGranted) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('Нужен доступ к камере')),
      );
      return;
    }
    final file = await ImagePicker().pickImage(source: ImageSource.camera);
    if (file == null || !mounted) return;
    await showSendCaptureSheet(this.context, ref, filePath: file.path);
  }

  void _showNewChatOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.tileHighlight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.subtitleColor.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.teal,
                ),
                child: const Icon(Icons.person_add_outlined, color: Colors.white),
              ),
              title: const Text('Новое сообщение',
                  style: TextStyle(color: Colors.white, fontSize: 16),),
              subtitle: Text('Написать пользователю',
                  style: TextStyle(color: context.subtitleColor, fontSize: 13),),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/new-chat');
              },
            ),
            ListTile(
              leading: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.tealDark,
                ),
                child: const Icon(Icons.group_add_outlined, color: Colors.white),
              ),
              title: const Text('Новая группа',
                  style: TextStyle(color: Colors.white, fontSize: 16),),
              subtitle: Text('Создать групповой чат',
                  style: TextStyle(color: context.subtitleColor, fontSize: 13),),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/new-group');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// Animated wrapper for each chat tile - staggered fade + slide in
class _AnimatedChatTileWrapper extends StatefulWidget {
  final int index;
  final Widget child;

  const _AnimatedChatTileWrapper({
    required this.index,
    required this.child,
  });

  @override
  State<_AnimatedChatTileWrapper> createState() =>
      _AnimatedChatTileWrapperState();
}

class _AnimatedChatTileWrapperState extends State<_AnimatedChatTileWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    final delay = (widget.index * 35).clamp(0, 350);
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

class _HomeAppBar extends StatelessWidget {
  const _HomeAppBar({
    required this.onMenu,
    required this.onSearch,
  });

  final VoidCallback onMenu;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: context.appBarBg,
        border: Border(
          bottom: BorderSide(color: context.dividerColor, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white),
            onPressed: onMenu,
            splashRadius: 22,
          ),
          const Expanded(
            child: Text(
              'Telegram',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Colors.white),
            onPressed: onSearch,
            splashRadius: 22,
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              color: AppColors.teal,
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Загрузка...',
            style: TextStyle(
              color: context.subtitleColor.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.wifi_off_rounded,
              size: 64,
              color: context.subtitleColor,
            ),
            const SizedBox(height: 16),
            Text(
              'Ошибка загрузки',
              style: TextStyle(color: context.primaryText, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              friendlyError(error),
              textAlign: TextAlign.center,
              style: TextStyle(color: context.subtitleColor, fontSize: 14),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Повторить'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teal,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyChatsView extends StatelessWidget {
  final bool hasQuery;

  const _EmptyChatsView({required this.hasQuery});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.teal.withValues(alpha: 0.1),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 44,
                color: AppColors.teal,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasQuery ? 'Ничего не найдено' : 'Нет чатов',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasQuery
                  ? 'Попробуйте другой запрос'
                  : 'Начните переписку, нажав кнопку ниже',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.subtitleColor,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatSearchDelegate extends SearchDelegate<String?> {
  _ChatSearchDelegate(this._ref, this._userId);
  final WidgetRef _ref;
  final String _userId;

  @override
  ThemeData appBarTheme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: context.appBarBg,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: context.subtitleColor),
        border: InputBorder.none,
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: query.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () => query = '',
                ),
        ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => close(context, null),
      );

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final chats = _ref.read(chatsListProvider).valueOrNull ?? [];
    final filtered = chats
        .where((c) =>
            c.displayTitle(_userId).toLowerCase().contains(query.toLowerCase()),)
        .toList();
    return ColoredBox(
      color: context.scaffoldBg,
      child: filtered.isEmpty
          ? Center(
              child: Text(
                'Ничего не найдено',
                style: TextStyle(color: context.subtitleColor),
              ),
            )
          : ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (_, i) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: context.tileHighlight,
                  child: const Icon(Icons.chat_bubble_outline, color: AppColors.teal),
                ),
                title: Text(
                  filtered[i].displayTitle(_userId),
                  style: TextStyle(color: context.primaryText),
                ),
                onTap: () => close(context, filtered[i].displayTitle(_userId)),
              ),
            ),
    );
  }
}
