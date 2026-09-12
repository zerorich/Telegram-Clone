import 'package:flutter/material.dart';
import 'package:telegramclone/core/format_utils.dart';
import 'package:telegramclone/core/theme_extensions.dart';
import 'package:telegramclone/data/models/message.dart';

class ChatSearchBar extends StatelessWidget {
  const ChatSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClose,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: context.tileHighlight,
        border: Border(bottom: BorderSide(color: context.dividerColor, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: context.inputFill,
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: controller,
                autofocus: true,
                onChanged: onChanged,
                style: TextStyle(color: context.primaryText, fontSize: 15),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.search_rounded, color: context.subtitleColor, size: 20),
                  hintText: 'Поиск в чате',
                  hintStyle: TextStyle(color: context.subtitleColor),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          Semantics(
            label: 'Закрыть поиск',
            button: true,
            child: IconButton(
              icon: Icon(Icons.close_rounded, color: context.subtitleColor, size: 20),
              onPressed: onClose,
              splashRadius: 18,
            ),
          ),
        ],
      ),
    );
  }
}

class ChatSearchResultsOverlay extends StatelessWidget {
  const ChatSearchResultsOverlay({
    super.key,
    required this.searching,
    required this.results,
    required this.onTapResult,
    required this.typeLabel,
  });

  final bool searching;
  final List<MessageModel> results;
  final ValueChanged<MessageModel> onTapResult;
  final String Function(MessageType) typeLabel;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Material(
        color: context.scaffoldBg,
        elevation: 4,
        child: Column(
          children: [
            if (searching)
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
                itemCount: results.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: context.dividerColor),
                itemBuilder: (_, i) {
                  final m = results[i];
                  final preview = m.content ?? typeLabel(m.type);
                  return ListTile(
                    title: Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.primaryText),
                    ),
                    subtitle: Text(
                      formatChatDateSeparator(m.createdAt),
                      style: TextStyle(color: context.subtitleColor),
                    ),
                    onTap: () => onTapResult(m),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
