// lib/features/chat/presentation/widgets/message_list.dart — Reverse ListView of chat messages with 5-minute interval dividers
import 'package:flutter/material.dart';
import 'package:flight_chat/l10n/gen/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/chat_message.dart';
import 'message_bubble.dart';

class MessageList extends StatelessWidget {
  final List<ChatMessage> messages;
  final ScrollController scrollController;
  final bool isLoading;

  const MessageList({
    super.key,
    required this.messages,
    required this.scrollController,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (messages.isEmpty) return const _EmptyChat();

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

/// Mostrato per un gruppo senza messaggi: i mock non esistono piu.
class _EmptyChat extends StatelessWidget {
  const _EmptyChat();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.forum_outlined,
              size: 48,
              color: AppColors.border,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.emptyChatTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.emptyChatHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
