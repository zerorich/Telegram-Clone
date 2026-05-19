import 'package:flutter/material.dart';

class TypingIndicator extends StatelessWidget {
  final String? userName;

  const TypingIndicator({super.key, this.userName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Text(
        userName != null ? '$userName is typing...' : 'typing...',
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontStyle: FontStyle.italic,
          fontSize: 13,
        ),
      ),
    );
  }
}
