// lib/features/chat/presentation/widgets/message_list.dart — Reverse ListView of chat messages with 5-minute interval dividers
import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import 'message_bubble.dart';

class MessageList extends StatelessWidget {
  final List<ChatMessage> messages;
  final ScrollController scrollController;

  const MessageList({
    super.key,
    required this.messages,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      reverse: true,
      padding: const EdgeInsets.only(top: 16.0, bottom: 16.0),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        // With reverse: true, index 0 is the newest message (bottom of screen)
        final chronologicalIndex = messages.length - 1 - index;
        final message = messages[chronologicalIndex];
        bool showDivider = false;

        if (chronologicalIndex > 0) {
          final prevMessage = messages[chronologicalIndex - 1];
          if ((message.timeDelta - prevMessage.timeDelta).abs() > 300) {
            showDivider = true;
          }
        }

        return Column(
          key: ValueKey(message.messageId),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDivider)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      message.formattedTime,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ),
              ),
            MessageBubble(message: message),
          ],
        );
      },
    );
  }
}
