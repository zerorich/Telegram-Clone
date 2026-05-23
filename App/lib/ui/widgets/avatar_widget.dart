import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:telegramclone/core/avatar_colors.dart';
import 'package:telegramclone/core/theme.dart';

class AvatarWidget extends StatelessWidget {
  final String? imageUrl;
  final String name;
  final double size;

  /// When true, render the Saved Messages avatar (bookmark on a teal circle)
  /// regardless of [imageUrl] / [name].
  final bool isSaved;

  const AvatarWidget({
    super.key,
    this.imageUrl,
    required this.name,
    this.size = 48,
    this.isSaved = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isSaved) {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [AppColors.teal, AppColors.tealDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.bookmark,
          color: Colors.white,
          size: size * 0.5,
        ),
      );
    }

    final initials = name.isNotEmpty
        ? name.trim().split(RegExp(r'\s+')).map((w) => w[0]).take(2).join().toUpperCase()
        : '?';
    final bg = avatarColorFor(name);

    return CircleAvatar(
      radius: size / 2,
      backgroundColor: bg,
      backgroundImage: imageUrl != null && imageUrl!.isNotEmpty
          ? CachedNetworkImageProvider(imageUrl!)
          : null,
      child: imageUrl == null || imageUrl!.isEmpty
          ? Text(
              initials,
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.35,
                fontWeight: FontWeight.w600,
              ),
            )
          : null,
    );
  }
}
