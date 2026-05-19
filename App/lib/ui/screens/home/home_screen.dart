import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:telegramclone/core/theme.dart';
import 'package:telegramclone/providers/auth_provider.dart';
import 'package:telegramclone/providers/chats_provider.dart';
import 'package:telegramclone/ui/widgets/app_drawer.dart';
import 'package:telegramclone/ui/widgets/chat_tile.dart';
import 'package:telegramclone/ui/widgets/telegram_fabs.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authProvider).user?.id ?? '';
    final chatsAsync = ref.watch(chatsListProvider);

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.darkList,
      drawer: const AppDrawer(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _HomeAppBar(
              onMenu: () => _scaffoldKey.currentState?.openDrawer(),
              onSearch: () async {
                final q = await showSearch<String?>(
                  context: context,
                  delegate: _ChatSearchDelegate(ref, userId),
                );
                if (q != null) setState(() => _query = q);
              },
            ),
            Expanded(
              child: chatsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.teal),
                ),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Ошибка: $e', style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () =>
                            ref.read(chatsListProvider.notifier).load(refresh: true),
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                ),
                data: (chats) {
                  final filtered = _query.isEmpty
                      ? chats
                      : chats
                          .where((c) => c
                              .displayTitle(userId)
                              .toLowerCase()
                              .contains(_query.toLowerCase()))
                          .toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text(
                        'Нет чатов. Начните переписку!',
                        style: TextStyle(color: AppColors.darkSubtitle),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    color: AppColors.teal,
                    onRefresh: () =>
                        ref.read(chatsListProvider.notifier).load(refresh: true),
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const Divider(
                        height: 1,
                        indent: 78,
                        color: AppColors.darkDivider,
                      ),
                      itemBuilder: (_, i) => ChatTile(
                        chat: filtered[i],
                        currentUserId: userId,
                        onTap: () => context.push('/chat/${filtered[i].id}'),
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
        onCamera: () => context.push('/new-chat'),
      ),
    );
  }

  void _showNewChatOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkTileHighlight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add_outlined, color: AppColors.teal),
              title: const Text('Новое сообщение'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/new-chat');
              },
            ),
            ListTile(
              leading: const Icon(Icons.group_add_outlined, color: AppColors.teal),
              title: const Text('Новая группа'),
              onTap: () {
                Navigator.pop(ctx);
                context.push('/new-group');
              },
            ),
          ],
        ),
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1A1A2E), AppColors.darkAppBar],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: onMenu,
          ),
          const Expanded(
            child: Text(
              'Telegram',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: onSearch,
          ),
        ],
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
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkAppBar,
        foregroundColor: Colors.white,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        hintStyle: TextStyle(color: AppColors.darkSubtitle),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
      ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
        icon: const Icon(Icons.arrow_back),
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
            c.displayTitle(_userId).toLowerCase().contains(query.toLowerCase()))
        .toList();
    return ColoredBox(
      color: AppColors.darkBg,
      child: ListView.builder(
        itemCount: filtered.length,
        itemBuilder: (_, i) => ListTile(
          title: Text(
            filtered[i].displayTitle(_userId),
            style: const TextStyle(color: Colors.white),
          ),
          onTap: () => close(context, filtered[i].displayTitle(_userId)),
        ),
      ),
    );
  }
}
