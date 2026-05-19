import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Chat screen currently open; read receipts are sent only for this chat.
final activeChatIdProvider = StateProvider<String?>((ref) => null);
