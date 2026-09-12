import 'package:flutter/material.dart';
import 'package:telegramclone/core/theme.dart';
import 'package:telegramclone/core/theme_extensions.dart';

class EditMessageDialog extends StatefulWidget {
  const EditMessageDialog({super.key, required this.initialText});

  final String initialText;

  @override
  State<EditMessageDialog> createState() => _EditMessageDialogState();
}

class _EditMessageDialogState extends State<EditMessageDialog> {
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
      backgroundColor: context.tileHighlight,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          const Icon(Icons.edit_rounded, color: AppColors.teal, size: 20),
          const SizedBox(width: 10),
          Text(
            'Изменить сообщение',
            style: TextStyle(color: context.primaryText, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        maxLines: 4,
        style: TextStyle(color: context.primaryText, fontSize: 15.5),
        decoration: InputDecoration(
          hintText: 'Текст сообщения',
          hintStyle: TextStyle(color: context.subtitleColor),
          filled: true,
          fillColor: context.inputFill,
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
          child: Text('Отмена', style: TextStyle(color: context.subtitleColor)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.teal,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
