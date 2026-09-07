// lib/features/chat/presentation/widgets/message_bubble.dart — Message bubble with entrance slide/fade animation, avatar, timestamp, and delivery status
import 'package:flutter/material.dart';
import 'package:flight_chat/l10n/gen/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../models/chat_message.dart';
import '../../../../shared/models/user_profile.dart';

class MessageBubble extends StatefulWidget {
  final ChatMessage message;

  const MessageBubble({super.key, required this.message});

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _opacityAnimation;
  bool _entranceStarted = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_entranceStarted) return;
    _entranceStarted = true;
    // MediaQuery non è leggibile in initState: l'avvio va qui.
    if (MediaQuery.disableAnimationsOf(context)) {
      _animController.value = 1.0;
    } else {
      _animController.forward();
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final isMe = message.isMine;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    Color avatarColor = AppColors.muted;
    IconData avatarIcon = Icons.person;
    if (!isMe) {
      final mockProfile = UserProfile(
        deviceId: message.senderDeviceId,
        nickname: message.senderName,
        avatarIconIndex: message.senderAvatarIconIndex,
      );
      avatarColor = mockProfile.color;
      avatarIcon = mockProfile.icon;
    }

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe) ...[
                Semantics(
                  label: l10n.senderAvatarLabel(message.senderName),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: avatarColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      avatarIcon,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  decoration: BoxDecoration(
                    color: isMe ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(4),
                      bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(20),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                  child: Column(
                    crossAxisAlignment:
                        isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      if (!isMe)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4.0),
                          child: Text(
                            message.senderName,
                            style: theme.textTheme.bodySmall?.copyWith(
                              // secondary su surface è 4.07:1, sotto AA per 12px
                              color: AppColors.secondaryLight,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      if (message.decryptFailed)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 14,
                              color: isMe
                                  ? AppColors.onPrimary
                                  : AppColors.mutedForeground,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                l10n.undecryptableMessage,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: isMe
                                      ? AppColors.onPrimary
                                      : AppColors.mutedForeground,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Text(
                          message.content,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: isMe ? AppColors.onPrimary : AppColors.foreground,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            message.formattedTime,
                            style: theme.textTheme.labelSmall?.copyWith(
                              // alpha 0.7 su primary dava 3.35:1, opaco dà 5.17:1
                              color: isMe
                                  ? AppColors.onPrimary
                                  : AppColors.mutedForeground,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            Icon(
                              message.status == MessageStatus.delivered
                                  ? Icons.done_all
                                  : Icons.check,
                              size: 14,
                              color: AppColors.onPrimary,
                              semanticLabel:
                                  message.status == MessageStatus.delivered
                                      ? l10n.statusDelivered
                                      : l10n.statusSent,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
