import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:telegramclone/data/models/message.dart';
import 'package:telegramclone/ui/screens/chat/media_viewer_screen.dart';

class MediaMessage extends StatelessWidget {
  final MessageModel message;
  final bool isMine;

  const MediaMessage({super.key, required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    switch (message.type) {
      case MessageType.image:
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MediaViewerScreen(
                url: message.fullMediaUrl,
                type: MediaViewerType.image,
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: message.fullMediaUrl,
              width: 220,
              fit: BoxFit.cover,
              placeholder: (_, __) => const SizedBox(
                width: 220,
                height: 160,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
        );
      case MessageType.video:
        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => MediaViewerScreen(
                url: message.fullMediaUrl,
                type: MediaViewerType.video,
              ),
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 220,
                height: 140,
                color: Colors.black26,
                child: const Icon(Icons.videocam, size: 48),
              ),
              const Icon(Icons.play_circle_fill, size: 48, color: Colors.white),
            ],
          ),
        );
      case MessageType.file:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file,
                color: isMine ? Colors.white : null,),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                message.content ?? 'Файл',
                style: TextStyle(color: isMine ? Colors.white : null),
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
