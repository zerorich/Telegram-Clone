import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:telegramclone/core/constants.dart';
import 'package:telegramclone/core/error_utils.dart';
import 'package:telegramclone/core/theme.dart';
import 'package:telegramclone/core/theme_extensions.dart';
import 'package:telegramclone/data/models/chat.dart';
import 'package:telegramclone/data/models/message.dart';
import 'package:telegramclone/providers/active_chat_provider.dart';
import 'package:telegramclone/providers/auth_provider.dart';
import 'package:telegramclone/providers/call_provider.dart';
import 'package:telegramclone/providers/chat_favorites_provider.dart';
import 'package:telegramclone/providers/chat_member_provider.dart';
import 'package:telegramclone/providers/chat_recording_provider.dart';
import 'package:telegramclone/providers/chats_provider.dart';
import 'package:telegramclone/providers/messages_provider.dart';
import 'package:telegramclone/providers/ws_provider.dart';
import 'package:telegramclone/ui/screens/chat/widgets/chat_attachment_sheet.dart';
import 'package:telegramclone/ui/screens/chat/widgets/chat_call_picker.dart';
import 'package:telegramclone/ui/screens/chat/widgets/chat_confirm_dialogs.dart';
import 'package:telegramclone/ui/screens/chat/widgets/chat_empty_view.dart';
import 'package:telegramclone/ui/screens/chat/widgets/chat_message_list.dart';
import 'package:telegramclone/ui/screens/chat/widgets/chat_reply_bar.dart';
import 'package:telegramclone/ui/screens/chat/widgets/chat_search_panel.dart';
import 'package:telegramclone/ui/screens/chat/widgets/edit_message_dialog.dart';
import 'package:telegramclone/ui/widgets/avatar_widget.dart';
import 'package:telegramclone/ui/widgets/chat_header_menu.dart';
import 'package:telegramclone/ui/widgets/chat_input_bar.dart';
import 'package:telegramclone/ui/widgets/forward_picker_sheet.dart';
import 'package:telegramclone/ui/widgets/message_action_menu.dart';
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
  final _moreBtnKey = GlobalKey();
  final _searchCtrl = TextEditingController();
  Timer? _typingTimer;
  Timer? _searchDebounce;
  bool _typingSent = false;
  bool _searchOpen = false;
  List<MessageModel> _searchResults = const [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onChatOpened());
  }

  void _onChatOpened() {
    if (!mounted) return;
    ref.read(activeChatIdProvider.notifier).state = widget.chatId;
    ref.read(chatsListProvider.notifier).clearUnread(widget.chatId);
    final uid = ref.read(authProvider).user?.id;
    if (uid != null) {
      ref.read(messagesProvider(widget.chatId).notifier).markReadUpTo(uid);
    }
  }

  void _clearActiveChat() {
    if (ref.read(activeChatIdProvider) == widget.chatId) {
      ref.read(activeChatIdProvider.notifier).state = null;
    }
  }

  void _leaveChat() {
    _clearActiveChat();
    if (context.canPop()) context.pop();
  }

  @override
  void dispose() {
    _clearActiveChat();
    _textCtrl.dispose();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _typingTimer?.cancel();
    _searchDebounce?.cancel();
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
    try {
      await ref.read(messagesProvider(widget.chatId).notifier).sendText(
            text,
            replyToId: reply?.id,
          );
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
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
    final file = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (file == null) return;
    await _sendMedia(type: 'image', path: file.path);
  }

  Future<void> _pickVideo() async {
    final file = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (file == null) return;
    await _sendMedia(type: 'video', path: file.path);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.single.path == null) return;
    await _sendMedia(type: 'file', path: result.files.single.path!);
  }

  Future<void> _sendMedia({required String type, required String path}) async {
    final reply = ref.read(replyToProvider(widget.chatId));
    try {
      await ref.read(messagesProvider(widget.chatId).notifier).sendMedia(
            type: type,
            path: path,
            replyToId: reply?.id,
          );
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    }
  }

  Future<void> _startRecording() async {
    final err = await ref.read(chatRecordingProvider(widget.chatId).notifier).start();
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _stopRecording({bool cancel = false}) async {
    final reply = ref.read(replyToProvider(widget.chatId));
    final err = await ref
        .read(chatRecordingProvider(widget.chatId).notifier)
        .stopAndSend(replyToId: reply?.id, cancel: cancel);
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      _scrollToBottom();
    }
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

  @override
  Widget build(BuildContext context) {
    final userId = ref.watch(authProvider).user?.id ?? '';
    final messagesState = ref.watch(messagesProvider(widget.chatId));
    final typingUserId = ref.watch(typingProvider(widget.chatId));
    final replyTo = ref.watch(replyToProvider(widget.chatId));
    final pinned = ref.watch(pinnedMessagesProvider(widget.chatId));
    final recording = ref.watch(chatRecordingProvider(widget.chatId)).isRecording;

    ChatModel? listChat;
    for (final c in ref.watch(chatsListProvider).valueOrNull ?? const <ChatModel>[]) {
      if (c.id == widget.chatId) {
        listChat = c;
        break;
      }
    }

    ref.listen(chatsListProvider, (prev, next) {
      final list = next.valueOrNull;
      if (list == null) return;
      if (!list.any((c) => c.id == widget.chatId)) {
        if (mounted && context.canPop()) _leaveChat();
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
    final title = chat?.displayTitle(userId) ?? 'Чат';
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
          backgroundColor: context.scaffoldBg,
          appBar: AppBar(
            backgroundColor: context.appBarBg,
            elevation: 0,
            leading: Semantics(
              label: 'Назад',
              button: true,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: _leaveChat,
                splashRadius: 22,
              ),
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
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: context.primaryText,
                                  ),
                                ),
                              ),
                              if (isMuted)
                                Padding(
                                  padding: const EdgeInsets.only(left: 5),
                                  child: Icon(
                                    Icons.notifications_off_rounded,
                                    color: context.subtitleColor,
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
                                                  color: context.subtitleColor,
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
              Semantics(
                label: 'Меню чата',
                button: true,
                child: IconButton(
                  key: _moreBtnKey,
                  icon: const Icon(Icons.more_vert_rounded),
                  onPressed: () => _openHeaderMenu(isSaved: isSaved, isMuted: isMuted, peerId: peerId),
                  splashRadius: 22,
                ),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(0.5),
              child: Container(height: 0.5, color: context.dividerColor),
            ),
          ),
          body: Column(
            children: [
              if (_searchOpen)
                ChatSearchBar(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  onClose: _closeSearch,
                ),
              if (pinnedToShow.isNotEmpty && !_searchOpen)
                PinnedBanner(
                  message: pinnedToShow.first,
                  totalPinned: pinnedToShow.length,
                  onTap: () => _jumpToMessage(pinnedToShow.first.id),
                ),
              if (messagesState.loadError != null && messagesState.messages.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(friendlyError(messagesState.loadError!)),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => ref
                              .read(messagesProvider(widget.chatId).notifier)
                              .loadInitial(),
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: Stack(
                    children: [
                      ColoredBox(
                        color: context.chatBg,
                        child: messagesState.messages.isEmpty
                            ? ChatEmptyView(isSaved: isSaved)
                            : ChatMessageList(
                                scrollController: _scrollCtrl,
                                messagesState: messagesState,
                                userId: userId,
                                isGroup: isGroup,
                                isSaved: isSaved,
                                chatDetailMembers: chatDetail?.valueOrNull?.members,
                                listChatMembers: listChat?.members,
                                onReply: (msg) =>
                                    ref.read(replyToProvider(widget.chatId).notifier).state = msg,
                                onLongPress: _showMessageActions,
                              ),
                      ),
                      if (_searchOpen && _searchResults.isNotEmpty)
                        ChatSearchResultsOverlay(
                          searching: _searching,
                          results: _searchResults,
                          typeLabel: _typeLabel,
                          onTapResult: (m) => _jumpToMessage(m.id),
                        ),
                    ],
                  ),
                ),
              if (typingUserId != null && typingUserId != userId)
                const TypingIndicator(),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: replyTo != null
                    ? ChatReplyBar(
                        replyTo: replyTo,
                        onClear: () =>
                            ref.read(replyToProvider(widget.chatId).notifier).state = null,
                      )
                    : const SizedBox.shrink(),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _textCtrl,
                builder: (_, value, __) => ChatInputBar(
                  controller: _textCtrl,
                  onChanged: _onTextChanged,
                  hasText: value.text.trim().isNotEmpty,
                  isRecording: recording,
                  onAttach: () => showChatAttachmentSheet(
                    context,
                    onPhoto: _pickImage,
                    onVideo: _pickVideo,
                    onFile: _pickFile,
                  ),
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
      try {
        final results = await ref
            .read(messagesProvider(widget.chatId).notifier)
            .search(q);
        if (!mounted) return;
        setState(() {
          _searchResults = results;
          _searching = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() => _searching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyError(e))),
        );
      }
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

  void _showMessageActions(
    MessageModel msg, {
    required bool isMine,
    required bool isGroup,
  }) {
    final canEdit = isMine && !msg.isDeleted && msg.type == MessageType.text;
    final myMember = ref.read(myChatMemberProvider(widget.chatId));
    final canDelete = isMine || (isGroup && isAdminOrOwner(myMember));

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
    final sent = await saveMessageToFavorites(
      ref,
      sourceChatId: widget.chatId,
      message: msg,
    );
    if (!mounted) return;
    if (sent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить сообщение')),
      );
      return;
    }
    final chats = ref.read(chatsListProvider).valueOrNull ?? const [];
    ChatModel? saved;
    for (final c in chats) {
      if (c.isSaved) {
        saved = c;
        break;
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Сохранено в Избранное'),
        action: saved != null
            ? SnackBarAction(
                label: 'Открыть',
                onPressed: () => context.push('/chat/${saved!.id}'),
              )
            : null,
      ),
    );
  }

  Future<void> _togglePin(MessageModel msg) async {
    final ok = await ref.read(messagesProvider(widget.chatId).notifier).togglePin(msg);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg.isPinned ? 'Не удалось открепить' : 'Не удалось закрепить'),
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
    await ref.read(messagesProvider(widget.chatId).notifier).deleteMessage(msg.id);
  }

  String _currentUserId() => ref.read(authProvider).user?.id ?? '';

  Future<void> _editMessage(MessageModel msg) async {
    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => EditMessageDialog(initialText: msg.content ?? ''),
    );
    if (newText == null || newText.isEmpty || !mounted) return;
    await ref.read(messagesProvider(widget.chatId).notifier).editText(msg.id, newText);
  }

  Future<void> _openHeaderMenu({
    required bool isSaved,
    required bool isMuted,
    required String? peerId,
  }) async {
    await showChatHeaderMenu(
      context,
      anchorKey: _moreBtnKey,
      isSaved: isSaved,
      isMuted: isMuted,
      onAction: (action) => _handleHeaderAction(action, peerId: peerId),
    );
  }

  Future<void> _handleHeaderAction(ChatHeaderAction action, {String? peerId}) async {
    switch (action) {
      case ChatHeaderAction.call:
        if (peerId == null) return;
        final media = await showCallMediaPicker(context);
        if (media == null) return;
        try {
          await startCall(ref, peerUserId: peerId, media: media);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(friendlyError(e))),
          );
        }
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
        try {
          await ref.read(chatsListProvider.notifier).unmute(widget.chatId);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(friendlyError(e))),
            );
          }
        }
        break;
      case ChatHeaderAction.notificationsOffForever:
      case ChatHeaderAction.notificationsOff1h:
      case ChatHeaderAction.notificationsOff1d:
        try {
          final until = switch (action) {
            ChatHeaderAction.notificationsOffForever => null,
            ChatHeaderAction.notificationsOff1h =>
              DateTime.now().add(const Duration(hours: 1)),
            ChatHeaderAction.notificationsOff1d =>
              DateTime.now().add(const Duration(days: 1)),
            _ => null,
          };
          await ref.read(chatsListProvider.notifier).mute(widget.chatId, until: until);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(friendlyError(e))),
            );
          }
        }
        break;
      case ChatHeaderAction.notifications:
        break;
    }
  }

  Future<void> _scrollToStart() async {
    await ref.read(messagesProvider(widget.chatId).notifier).loadAllHistory(maxBatches: 10);
    if (!mounted || !_scrollCtrl.hasClients) return;
    await _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  Future<void> _confirmClearHistory() async {
    final ok = await confirmClearHistory(context);
    if (!ok || !mounted) return;
    final success =
        await ref.read(messagesProvider(widget.chatId).notifier).clearHistory();
    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось очистить историю')),
      );
    }
  }

  Future<void> _confirmDeleteChat() async {
    final ok = await confirmDeleteChat(context);
    if (!ok || !mounted) return;
    try {
      await ref.read(chatsListProvider.notifier).deleteChat(widget.chatId);
      _leaveChat();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
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
