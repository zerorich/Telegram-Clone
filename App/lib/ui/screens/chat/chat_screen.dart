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
import 'package:telegramclone/data/models/message.dart';
import 'package:telegramclone/providers/active_chat_provider.dart';
import 'package:telegramclone/providers/auth_provider.dart';
import 'package:telegramclone/providers/chats_provider.dart';
import 'package:telegramclone/providers/messages_provider.dart';
import 'package:telegramclone/core/theme.dart';
import 'package:telegramclone/providers/ws_provider.dart';
import 'package:telegramclone/ui/widgets/avatar_widget.dart';
import 'package:telegramclone/ui/widgets/chat_input_bar.dart';
import 'package:telegramclone/ui/widgets/date_separator.dart';
import 'package:telegramclone/ui/widgets/message_bubble.dart';
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
  bool _recording = false;
  DateTime? _recordStartedAt;
  Timer? _typingTimer;
  bool _typingSent = false;
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
    _scrollCtrl.dispose();
    _typingTimer?.cancel();
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

    ChatModel? listChat;
    for (final c in ref.watch(chatsListProvider).valueOrNull ?? const <ChatModel>[]) {
      if (c.id == widget.chatId) {
        listChat = c;
        break;
      }
    }

    final needsChatDetail = listChat == null ||
        (listChat.type == ChatType.direct &&
            (listChat.members.isEmpty ||
                listChat.peerMember(userId)?.user == null));
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

    ref.listen(messagesProvider(widget.chatId), (prev, next) {
      if (prev == null) return;
      if (prev.messages.length < next.messages.length) {
        _scrollToBottom();
        if (userId.isNotEmpty) {
          ref.read(messagesProvider(widget.chatId).notifier).markReadUpTo(userId);
        }
      }
    });

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _leaveChat,
        ),
        title: InkWell(
          onTap: isGroup ? () => context.push('/group/${widget.chatId}') : null,
          child: Row(
            children: [
              AvatarWidget(
                imageUrl: avatarPath != null && avatarPath.isNotEmpty
                    ? AppConstants.mediaUrl(avatarPath)
                    : null,
                name: title,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    if (typingUserId != null && typingUserId != userId)
                      const Text(
                        'печатает...',
                        style: TextStyle(fontSize: 13, color: AppColors.teal),
                      )
                    else if (!isGroup && isOnline)
                      const Text(
                        'в сети',
                        style: TextStyle(fontSize: 13, color: AppColors.teal),
                      )
                    else if (!isGroup && chat?.lastMessage != null)
                      Text(
                        'был(а) недавно',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.45),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            color: AppColors.darkTileHighlight,
            onSelected: (v) {
              switch (v) {
                case 'info':
                  if (isGroup) {
                    context.push('/group/${widget.chatId}');
                  } else if (peerId != null) {
                    context.push('/user/$peerId');
                  }
                  break;
                case 'profile':
                  if (peerId != null) context.push('/user/$peerId');
                  break;
              }
            },
            itemBuilder: (_) => [
              if (isGroup)
                const PopupMenuItem(
                  value: 'info',
                  child: Text('Информация о группе', style: TextStyle(color: Colors.white)),
                )
              else if (peerId != null)
                const PopupMenuItem(
                  value: 'profile',
                  child: Text('Профиль', style: TextStyle(color: Colors.white)),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ColoredBox(
              color: AppColors.darkChatBg,
              child: messagesState.messages.isEmpty
                ? const Center(
                    child: Text(
                      'Нет сообщений. Напишите первым!',
                      style: TextStyle(color: AppColors.darkSubtitle),
                    ),
                  )
                : ListView.builder(
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
                      final isMine = msg.senderId == userId;
                      MessageModel? reply;
                      if (msg.replyToId != null) {
                        final replies = messagesState.messages
                            .where((m) => m.id == msg.replyToId);
                        reply = replies.isEmpty ? null : replies.first;
                      }
                      String? senderName;
                      if (isGroup && !isMine) {
                        final members = (chatDetail?.valueOrNull?.members ??
                                listChat?.members ??
                                [])
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
                              ref.read(replyToProvider(widget.chatId).notifier).state =
                                  msg;
                            },
                            onLongPress: () => _showMessageActions(
                              context,
                              msg: msg,
                              isMine: isMine,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
            ),
          ),
          if (typingUserId != null && typingUserId != userId)
            const TypingIndicator(),
          if (replyTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: AppColors.darkTileHighlight,
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 36,
                    color: AppColors.teal,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      replyTo.content ?? 'медиа',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () =>
                        ref.read(replyToProvider(widget.chatId).notifier).state =
                            null,
                  ),
                ],
              ),
            ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _textCtrl,
            builder: (_, value, __) => ChatInputBar(
            controller: _textCtrl,
            onChanged: _onTextChanged,
            hasText: value.text.trim().isNotEmpty,
            isRecording: _recording,
            onAttach: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: AppColors.darkTileHighlight,
                builder: (_) => SafeArea(
                  child: Wrap(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.image, color: AppColors.teal),
                        title: const Text('Фото'),
                        onTap: () {
                          Navigator.pop(context);
                          _pickImage();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.insert_drive_file, color: AppColors.teal),
                        title: const Text('Файл'),
                        onTap: () {
                          Navigator.pop(context);
                          _pickFile();
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
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

  void _showMessageActions(
    BuildContext context, {
    required MessageModel msg,
    required bool isMine,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkTileHighlight,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.reply, color: AppColors.teal),
              title: const Text('Ответить', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(ctx);
                ref.read(replyToProvider(widget.chatId).notifier).state = msg;
              },
            ),
            if (isMine && !msg.isDeleted && msg.type == MessageType.text)
              ListTile(
                leading: const Icon(Icons.edit_outlined, color: AppColors.teal),
                title: const Text('Изменить', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(ctx);
                  _editMessage(msg);
                },
              ),
            if (isMine && !msg.isDeleted)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
                title: const Text('Удалить', style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref
                      .read(messagesProvider(widget.chatId).notifier)
                      .deleteMessage(msg.id);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editMessage(MessageModel msg) async {
    final ctrl = TextEditingController(text: msg.content ?? '');
    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkTileHighlight,
        title: const Text('Изменить сообщение', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Текст сообщения',
            hintStyle: TextStyle(color: AppColors.darkSubtitle),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final t = ctrl.text.trim();
              if (t.isNotEmpty) Navigator.pop(ctx, t);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (newText == null || newText.isEmpty) {
      ctrl.dispose();
      return;
    }
    if (!mounted) {
      ctrl.dispose();
      return;
    }
    await Future<void>.delayed(Duration.zero);
    ctrl.dispose();
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
}
