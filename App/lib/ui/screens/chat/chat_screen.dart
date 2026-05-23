import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:telegramclone/core/constants.dart';
import 'package:telegramclone/core/format_utils.dart';
import 'package:telegramclone/data/models/chat.dart';
import 'package:telegramclone/data/models/chat_member.dart';
import 'package:telegramclone/data/models/message.dart';
import 'package:telegramclone/providers/active_chat_provider.dart';
import 'package:telegramclone/providers/auth_provider.dart';
import 'package:telegramclone/providers/chats_provider.dart';
import 'package:telegramclone/providers/messages_provider.dart';
import 'package:telegramclone/core/theme.dart';
import 'package:telegramclone/providers/ws_provider.dart';
import 'package:telegramclone/ui/widgets/avatar_widget.dart';
import 'package:telegramclone/ui/widgets/chat_header_menu.dart';
import 'package:telegramclone/ui/widgets/chat_input_bar.dart';
import 'package:telegramclone/ui/widgets/date_separator.dart';
import 'package:telegramclone/ui/widgets/forward_picker_sheet.dart';
import 'package:telegramclone/ui/widgets/message_action_menu.dart';
import 'package:telegramclone/ui/widgets/message_bubble.dart';
import 'package:telegramclone/ui/widgets/pinned_banner.dart';
import 'package:telegramclone/ui/widgets/swipe_back_detector.dart';
import 'package:telegramclone/ui/widgets/typing_indicator.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;

  const ChatScreen({super.key, required this.chatId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _record = AudioRecorder();
  final _moreBtnKey = GlobalKey();
  final _searchCtrl = TextEditingController();
  bool _recording = false;
  DateTime? _recordStartedAt;
  Timer? _typingTimer;
  Timer? _searchDebounce;
  bool _typingSent = false;
  bool _searchOpen = false;
  List<MessageModel> _searchResults = const [];
  bool _searching = false;
  ProviderContainer? _container;

  void _onChatOpened() {
    if (!mounted) return;
    _container ??= ProviderScope.containerOf(context);
    _container!.read(activeChatIdProvider.notifier).state = widget.chatId;
    _container!.read(chatsListProvider.notifier).clearUnread(widget.chatId);
    final uid = _container!.read(authProvider).user?.id;
    if (uid != null) {
      _container!.read(messagesProvider(widget.chatId).notifier).markReadUpTo(uid);
    }
  }

  void _clearActiveChat() {
    final container = _container;
    if (container == null) return;
    if (container.read(activeChatIdProvider) == widget.chatId) {
      container.read(activeChatIdProvider.notifier).state = null;
    }
  }

  void _leaveChat() {
    _clearActiveChat();
    if (context.canPop()) context.pop();
  }

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onChatOpened());
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _typingTimer?.cancel();
    _searchDebounce?.cancel();
    _record.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 80) {
      ref.read(messagesProvider(widget.chatId).notifier).loadMore();
    }
  }

  void _onTextChanged(String v) {
    if (v.isNotEmpty && !_typingSent) {
      _typingSent = true;
      ref.read(wsServiceProvider).sendTyping(widget.chatId, true);
    }
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted || !_typingSent) return;
      ref.read(wsServiceProvider).sendTyping(widget.chatId, false);
      _typingSent = false;
    });
  }

  Future<void> _sendText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    final reply = ref.read(replyToProvider(widget.chatId));
    _textCtrl.clear();
    ref.read(replyToProvider(widget.chatId).notifier).state = null;
    await ref.read(messagesProvider(widget.chatId).notifier).sendText(
          text,
          replyToId: reply?.id,
        );
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final reply = ref.read(replyToProvider(widget.chatId));
    await ref.read(messagesProvider(widget.chatId).notifier).sendMedia(
          type: 'image',
          path: file.path,
          replyToId: reply?.id,
        );
    _scrollToBottom();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) return;
    final reply = ref.read(replyToProvider(widget.chatId));
    await ref.read(messagesProvider(widget.chatId).notifier).sendMedia(
          type: 'file',
          path: result.files.single.path!,
          replyToId: reply?.id,
        );
    _scrollToBottom();
  }

  Future<void> _startRecording() async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нужен доступ к микрофону')),
        );
      }
      return;
    }
    final dir = Directory.systemTemp;
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _record.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        sampleRate: 44100,
        numChannels: 1,
        bitRate: 128000,
        autoGain: true,
      ),
      path: path,
    );
    _recordStartedAt = DateTime.now();
    setState(() => _recording = true);
  }

  Future<void> _stopRecording({bool cancel = false}) async {
    final started = _recordStartedAt;
    _recordStartedAt = null;
    final path = await _record.stop();
    setState(() => _recording = false);
    if (cancel || path == null) return;

    final file = File(path);
    if (!await file.exists() || await file.length() < 512) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Запись слишком короткая')),
        );
      }
      return;
    }

    var durationSec = 1;
    if (started != null) {
      durationSec = DateTime.now().difference(started).inSeconds;
      if (durationSec < 1) durationSec = 1;
    }

    final reply = ref.read(replyToProvider(widget.chatId));
    final sent = await ref.read(messagesProvider(widget.chatId).notifier).sendMedia(
          type: 'voice',
          path: path,
          durationSec: durationSec,
          replyToId: reply?.id,
        );
    if (sent == null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось отправить голосовое')),
      );
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authProvider).user?.id ?? '';
    final messagesState = ref.watch(messagesProvider(widget.chatId));
    final typingUserId = ref.watch(typingProvider(widget.chatId));
    final replyTo = ref.watch(replyToProvider(widget.chatId));
    final pinned = ref.watch(pinnedMessagesProvider(widget.chatId));

    ChatModel? listChat;
    for (final c in ref.watch(chatsListProvider).valueOrNull ?? const <ChatModel>[]) {
      if (c.id == widget.chatId) {
        listChat = c;
        break;
      }
    }

    // If the chat is removed server-side while we're looking at it, pop home.
    ref.listen(chatsListProvider, (prev, next) {
      final list = next.valueOrNull;
      if (list == null) return;
      if (!list.any((c) => c.id == widget.chatId)) {
        if (mounted && context.canPop()) {
          _leaveChat();
        }
      }
    });

    final isSaved = listChat?.isSaved ?? false;
    final needsChatDetail = !isSaved &&
        (listChat == null ||
            (listChat.type == ChatType.direct &&
                (listChat.members.isEmpty ||
                    listChat.peerMember(userId)?.user == null)));
    final chatDetail = needsChatDetail
        ? ref.watch(chatDetailProvider(widget.chatId))
        : null;

    final chat = chatDetail?.valueOrNull?.chat ?? listChat;
    final title = chat?.displayTitle(userId) ?? 'Chat';
    final isGroup = chat?.type == ChatType.group;
    final avatarPath = chat?.peerAvatarUrl(userId);
    final peerId = chat?.peerMember(userId)?.userId;
    final isOnline = peerId != null &&
        (ref.watch(onlineUsersProvider)[peerId] ?? false);
    final isMuted = chat?.isMuted ?? false;

    ref.listen(messagesProvider(widget.chatId), (prev, next) {
      if (prev == null) return;
      if (prev.messages.length < next.messages.length) {
        _scrollToBottom();
        if (userId.isNotEmpty) {
          ref.read(messagesProvider(widget.chatId).notifier).markReadUpTo(userId);
        }
      }
    });

    final pinnedToShow = pinned.where((m) => m.isPinned && !m.isDeleted).toList();

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _clearActiveChat();
      },
      child: SwipeBackDetector(
      onBack: _leaveChat,
      child: Scaffold(
      backgroundColor: AppColors.darkBg,
      appBar: AppBar(
        backgroundColor: AppColors.darkAppBar,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: _leaveChat,
          splashRadius: 22,
        ),
        titleSpacing: 0,
        title: InkWell(
          onTap: isSaved
              ? null
              : isGroup
                  ? () => context.push('/group/${widget.chatId}')
                  : (peerId != null
                      ? () => context.push('/user/$peerId')
                      : null),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              children: [
                AvatarWidget(
                  imageUrl: avatarPath != null && avatarPath.isNotEmpty
                      ? AppConstants.mediaUrl(avatarPath)
                      : null,
                  name: title,
                  size: 38,
                  isSaved: isSaved,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white),
                            ),
                          ),
                          if (isMuted)
                            const Padding(
                              padding: EdgeInsets.only(left: 5),
                              child: Icon(
                                Icons.notifications_off_rounded,
                                color: AppColors.darkSubtitle,
                                size: 15,
                              ),
                            ),
                        ],
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: isSaved
                            ? const SizedBox.shrink()
                            : typingUserId != null && typingUserId != userId
                                ? const Text(
                                    key: ValueKey('typing'),
                                    'печатает...',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: AppColors.teal,
                                    ),
                                  )
                                : !isGroup && isOnline
                                    ? const Text(
                                        key: ValueKey('online'),
                                        'в сети',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          color: AppColors.teal,
                                        ),
                                      )
                                    : !isGroup && chat?.lastMessage != null
                                        ? Text(
                                            key: const ValueKey('offline'),
                                            'был(а) недавно',
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              color: Colors.white.withValues(alpha: 0.45),
                                            ),
                                          )
                                        : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            key: _moreBtnKey,
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () => _openHeaderMenu(isSaved: isSaved, isMuted: isMuted),
            splashRadius: 22,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(
            height: 0.5,
            color: AppColors.darkDivider,
          ),
        ),
      ),
      body: Column(
        children: [
          if (_searchOpen) _buildSearchBar(),
          if (pinnedToShow.isNotEmpty && !_searchOpen)
            PinnedBanner(
              message: pinnedToShow.first,
              totalPinned: pinnedToShow.length,
              onTap: () => _jumpToMessage(pinnedToShow.first.id),
            ),
          Expanded(
            child: Stack(
              children: [
                ColoredBox(
                  color: AppColors.darkChatBg,
                  child: messagesState.messages.isEmpty
                      ? _buildEmpty(isSaved: isSaved)
                      : _buildMessageList(
                          userId: userId,
                          messagesState: messagesState,
                          isGroup: isGroup,
                          isSaved: isSaved,
                          chatDetailMembers: chatDetail?.valueOrNull?.members,
                          listChatMembers: listChat?.members,
                        ),
                ),
                if (_searchOpen && _searchResults.isNotEmpty)
                  _buildSearchResultsOverlay(userId),
              ],
            ),
          ),
          if (typingUserId != null && typingUserId != userId)
            const TypingIndicator(),
          // Animated reply bar
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            child: replyTo != null
                ? Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                    decoration: const BoxDecoration(
                      color: AppColors.darkTileHighlight,
                      border: Border(
                        top: BorderSide(
                          color: AppColors.darkDivider,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 3,
                          height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.teal,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Ответить',
                                style: TextStyle(
                                  color: AppColors.teal,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                replyTo.content ?? 'медиа',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 20,
                            color: AppColors.darkSubtitle,
                          ),
                          onPressed: () =>
                              ref.read(replyToProvider(widget.chatId).notifier).state =
                                  null,
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _textCtrl,
            builder: (_, value, __) => ChatInputBar(
            controller: _textCtrl,
            onChanged: _onTextChanged,
            hasText: value.text.trim().isNotEmpty,
            isRecording: _recording,
            onAttach: _showAttachmentSheet,
            onSend: _sendText,
            onRecordStart: _startRecording,
            onRecordEnd: () => _stopRecording(),
            onRecordCancel: () => _stopRecording(cancel: true),
          ),
          ),
        ],
      ),
      ),
      ),
    );
  }

  Widget _buildEmpty({required bool isSaved}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.teal.withValues(alpha: 0.1),
              ),
              child: Icon(
                isSaved
                    ? Icons.bookmark_rounded
                    : Icons.chat_bubble_outline_rounded,
                size: 40,
                color: AppColors.teal,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isSaved ? 'Сохранённые сообщения' : 'Нет сообщений',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSaved
                  ? 'Пересылайте сюда важные сообщения, чтобы не потерять'
                  : 'Будьте первым, кто напишет!\nНачните общение прямо сейчас.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.darkSubtitle,
                fontSize: 14.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList({
    required String userId,
    required MessagesState messagesState,
    required bool isGroup,
    required bool isSaved,
    required List<dynamic>? chatDetailMembers,
    required List<dynamic>? listChatMembers,
  }) {
    return ListView.builder(
      controller: _scrollCtrl,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: messagesState.messages.length +
          (messagesState.isLoadingMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (messagesState.isLoadingMore &&
            i == messagesState.messages.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(8),
              child: CircularProgressIndicator(),
            ),
          );
        }
        final idx = messagesState.messages.length - 1 - i;
        final msg = messagesState.messages[idx];
        final showDate = idx == 0 ||
            !_sameDay(
              messagesState.messages[idx - 1].createdAt,
              msg.createdAt,
            );
        // In Saved Messages every message is "mine" (right-aligned).
        final isMine = isSaved || msg.senderId == userId;
        MessageModel? reply;
        if (msg.replyToId != null) {
          final replies = messagesState.messages
              .where((m) => m.id == msg.replyToId);
          reply = replies.isEmpty ? null : replies.first;
        }
        String? senderName;
        if (isGroup && !isMine) {
          final members =
              (chatDetailMembers ?? listChatMembers ?? const [])
                  .where((m) => m.userId == msg.senderId);
          final member = members.isEmpty ? null : members.first;
          senderName = member?.user?.displayName;
        }
        return Column(
          children: [
            if (showDate)
              DateSeparator(
                label: formatChatDateSeparator(msg.createdAt),
              ),
            MessageBubble(
              message: msg,
              isMine: isMine,
              senderName: senderName,
              replyTo: reply,
              onReply: () {
                ref.read(replyToProvider(widget.chatId).notifier).state = msg;
              },
              onLongPress: () => _showMessageActions(
                context,
                msg: msg,
                isMine: isMine,
                isGroup: isGroup,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: const BoxDecoration(
        color: AppColors.darkTileHighlight,
        border: Border(
          bottom: BorderSide(color: AppColors.darkDivider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.darkInput,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                onChanged: _onSearchChanged,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                decoration: const InputDecoration(
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: AppColors.darkSubtitle,
                    size: 20,
                  ),
                  hintText: 'Поиск в чате',
                  hintStyle: TextStyle(color: AppColors.darkSubtitle),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
            onPressed: _closeSearch,
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsOverlay(String userId) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: AppColors.darkBg,
        elevation: 4,
        child: Column(
          children: [
            if (_searching)
              const Padding(
                padding: EdgeInsets.all(8),
                child: LinearProgressIndicator(),
              ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  color: AppColors.darkDivider,
                ),
                itemBuilder: (_, i) {
                  final m = _searchResults[i];
                  final preview = m.content ?? _typeLabel(m.type);
                  return ListTile(
                    title: Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      formatChatDateSeparator(m.createdAt),
                      style:
                          const TextStyle(color: AppColors.darkSubtitle),
                    ),
                    onTap: () => _jumpToMessage(m.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(MessageType t) {
    switch (t) {
      case MessageType.image:
        return 'Фото';
      case MessageType.video:
        return 'Видео';
      case MessageType.voice:
        return 'Голосовое';
      case MessageType.file:
        return 'Файл';
      default:
        return '';
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final q = value.trim();
    if (q.isEmpty) {
      setState(() => _searchResults = const []);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      setState(() => _searching = true);
      final results = await ref
          .read(messagesProvider(widget.chatId).notifier)
          .search(q);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _searching = false;
      });
    });
  }

  void _closeSearch() {
    _searchDebounce?.cancel();
    _searchCtrl.clear();
    setState(() {
      _searchOpen = false;
      _searchResults = const [];
      _searching = false;
    });
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkTileHighlight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.darkSubtitle.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.blue.withValues(alpha: 0.2),
                ),
                child: const Icon(Icons.image_rounded, color: Colors.blue),
              ),
              title: const Text('Фото',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
              subtitle: const Text('Выбрать из галереи',
                  style: TextStyle(color: AppColors.darkSubtitle, fontSize: 13)),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.withValues(alpha: 0.2),
                ),
                child: const Icon(Icons.insert_drive_file_rounded,
                    color: Colors.orange),
              ),
              title: const Text('Файл',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
              subtitle: const Text('Выбрать файл',
                  style: TextStyle(color: AppColors.darkSubtitle, fontSize: 13)),
              onTap: () {
                Navigator.pop(context);
                _pickFile();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showMessageActions(
    BuildContext context, {
    required MessageModel msg,
    required bool isMine,
    required bool isGroup,
  }) {
    final canEdit = isMine && !msg.isDeleted && msg.type == MessageType.text;

    final myMember = _myMember();
    final canDelete = isMine ||
        (isGroup &&
            myMember != null &&
            (memberRoleToString(myMember.role as MemberRole) == 'admin' ||
                memberRoleToString(myMember.role as MemberRole) == 'owner'));

    showMessageActionMenu(
      context,
      message: msg,
      isMine: isMine,
      isGroup: isGroup,
      canDelete: canDelete,
      canEdit: canEdit,
      actions: MessageActions(
        onReply: () {
          ref.read(replyToProvider(widget.chatId).notifier).state = msg;
        },
        onForward: () => _forwardMessage(msg),
        onSaveToFavorites: () => _saveToFavorites(msg),
        onTogglePin: () => _togglePin(msg),
        onCopy: () => _copyMessage(msg),
        onEdit: canEdit ? () => _editMessage(msg) : null,
        onDelete: canDelete ? () => _deleteMessage(msg) : null,
      ),
    );
  }

  dynamic _myMember() {
    final myId = ref.read(authProvider).user?.id;
    if (myId == null) return null;
    final list = ref.read(chatsListProvider).valueOrNull ?? const [];
    for (final c in list) {
      if (c.id != widget.chatId) continue;
      for (final m in c.members) {
        if (m.userId == myId) return m;
      }
    }
    return null;
  }

  Future<void> _forwardMessage(MessageModel msg) async {
    final target = await showForwardPicker(context);
    if (target == null || !mounted) return;
    final sent = await ref
        .read(messagesProvider(widget.chatId).notifier)
        .forwardTo(targetChatId: target.id, messageId: msg.id);
    if (!mounted) return;
    if (sent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось переслать сообщение')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Переслано в ${target.displayTitle(_currentUserId())}')),
      );
    }
  }

  Future<void> _saveToFavorites(MessageModel msg) async {
    final chats = ref.read(chatsListProvider).valueOrNull ?? const [];
    final saved =
        chats.where((c) => c.isSaved).cast<ChatModel?>().firstOrNull;
    if (saved == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('«Избранное» пока недоступно')),
      );
      return;
    }
    final sent = await ref
        .read(messagesProvider(widget.chatId).notifier)
        .forwardTo(targetChatId: saved.id, messageId: msg.id);
    if (!mounted) return;
    if (sent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить сообщение')),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Сохранено в Избранное'),
        action: SnackBarAction(
          label: 'Открыть',
          onPressed: () => context.push('/chat/${saved.id}'),
        ),
      ),
    );
  }

  Future<void> _togglePin(MessageModel msg) async {
    final ok = await ref
        .read(messagesProvider(widget.chatId).notifier)
        .togglePin(msg);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg.isPinned
              ? 'Не удалось открепить'
              : 'Не удалось закрепить'),
        ),
      );
    }
  }

  Future<void> _copyMessage(MessageModel msg) async {
    if ((msg.content ?? '').isEmpty) return;
    await copyMessageText(msg);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Скопировано')),
    );
  }

  Future<void> _deleteMessage(MessageModel msg) async {
    await ref
        .read(messagesProvider(widget.chatId).notifier)
        .deleteMessage(msg.id);
  }

  String _currentUserId() => ref.read(authProvider).user?.id ?? '';

  Future<void> _editMessage(MessageModel msg) async {
    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => _EditMessageDialog(initialText: msg.content ?? ''),
    );
    if (newText == null || newText.isEmpty) return;
    if (!mounted) return;
    await ref
        .read(messagesProvider(widget.chatId).notifier)
        .editText(msg.id, newText);
  }

  bool _sameDay(DateTime a, DateTime b) {
    final al = a.toLocal();
    final bl = b.toLocal();
    return al.year == bl.year && al.month == bl.month && al.day == bl.day;
  }

  Future<void> _openHeaderMenu({
    required bool isSaved,
    required bool isMuted,
  }) async {
    await showChatHeaderMenu(
      context,
      anchorKey: _moreBtnKey,
      isSaved: isSaved,
      isMuted: isMuted,
      onAction: _handleHeaderAction,
    );
  }

  Future<void> _handleHeaderAction(ChatHeaderAction action) async {
    switch (action) {
      case ChatHeaderAction.call:
        await showComingSoonDialog(context);
        break;
      case ChatHeaderAction.search:
        setState(() {
          _searchOpen = true;
          _searchResults = const [];
        });
        break;
      case ChatHeaderAction.scrollToStart:
        await _scrollToStart();
        break;
      case ChatHeaderAction.clearHistory:
        await _confirmClearHistory();
        break;
      case ChatHeaderAction.deleteChat:
        await _confirmDeleteChat();
        break;
      case ChatHeaderAction.notificationsOn:
        await ref.read(chatsListProvider.notifier).unmute(widget.chatId);
        break;
      case ChatHeaderAction.notificationsOffForever:
        await ref.read(chatsListProvider.notifier).mute(widget.chatId);
        break;
      case ChatHeaderAction.notificationsOff1h:
        await ref.read(chatsListProvider.notifier).mute(
              widget.chatId,
              until: DateTime.now().add(const Duration(hours: 1)),
            );
        break;
      case ChatHeaderAction.notificationsOff1d:
        await ref.read(chatsListProvider.notifier).mute(
              widget.chatId,
              until: DateTime.now().add(const Duration(days: 1)),
            );
        break;
      case ChatHeaderAction.notifications:
        break;
    }
  }

  Future<void> _scrollToStart() async {
    await ref
        .read(messagesProvider(widget.chatId).notifier)
        .loadAllHistory(maxBatches: 10);
    if (!mounted || !_scrollCtrl.hasClients) return;
    await _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  Future<void> _confirmClearHistory() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkTileHighlight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Очистить историю',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        content: const Text(
          'Очистить всю историю сообщений? Это действие нельзя отменить.',
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
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final success = await ref
        .read(messagesProvider(widget.chatId).notifier)
        .clearHistory();
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось очистить историю')),
      );
    }
  }

  Future<void> _confirmDeleteChat() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkTileHighlight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Удалить чат',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        content: const Text(
          'Удалить чат? Сообщения будут удалены.',
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
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final success =
        await ref.read(chatsListProvider.notifier).deleteChat(widget.chatId);
    if (!mounted) return;
    if (success) {
      _leaveChat();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось удалить чат')),
      );
    }
  }

  Future<void> _jumpToMessage(String messageId) async {
    final list = ref.read(messagesProvider(widget.chatId)).messages;
    final idxFromOldest = list.indexWhere((m) => m.id == messageId);
    _closeSearch();
    if (idxFromOldest < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сообщение не в загруженной истории')),
      );
      return;
    }
    // List is reverse:true; visual top = oldest = highest scroll offset.
    // i = list.length - 1 - idxFromOldest, scroll position correlates with i.
    if (!_scrollCtrl.hasClients) return;
    final visualIndex = list.length - 1 - idxFromOldest;
    final approxOffset =
        (visualIndex * 60.0).clamp(0.0, _scrollCtrl.position.maxScrollExtent);
    await _scrollCtrl.animateTo(
      approxOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }
}

class _EditMessageDialog extends StatefulWidget {
  final String initialText;

  const _EditMessageDialog({required this.initialText});

  @override
  State<_EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends State<_EditMessageDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.darkTileHighlight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Row(
        children: [
          Icon(Icons.edit_rounded, color: AppColors.teal, size: 20),
          SizedBox(width: 10),
          Text(
            'Изменить сообщение',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        maxLines: 4,
        style: const TextStyle(color: Colors.white, fontSize: 15.5),
        decoration: InputDecoration(
          hintText: 'Текст сообщения',
          hintStyle: const TextStyle(color: AppColors.darkSubtitle),
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
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена',
              style: TextStyle(color: AppColors.darkSubtitle)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.teal,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            final t = _ctrl.text.trim();
            if (t.isNotEmpty) Navigator.pop(context, t);
          },
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    if (it.moveNext()) return it.current;
    return null;
  }
}
