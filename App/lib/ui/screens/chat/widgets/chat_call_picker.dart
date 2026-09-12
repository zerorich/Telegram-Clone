import 'package:flutter/material.dart';
import 'package:telegramclone/core/theme_extensions.dart';
import 'package:telegramclone/data/webrtc/call_service.dart';

Future<CallMedia?> showCallMediaPicker(BuildContext context) {
  return showModalBottomSheet<CallMedia>(
    context: context,
    backgroundColor: context.tileHighlight,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.call, color: Colors.green),
            title: Text('Голосовой звонок', style: TextStyle(color: ctx.primaryText)),
            onTap: () => Navigator.pop(ctx, CallMedia.audio),
          ),
          ListTile(
            leading: const Icon(Icons.videocam, color: Colors.blue),
            title: Text('Видеозвонок', style: TextStyle(color: ctx.primaryText)),
            onTap: () => Navigator.pop(ctx, CallMedia.video),
          ),
        ],
      ),
    ),
  );
}
