// lib/features/chat/presentation/widgets/message_input.dart — Chat text input with scale/rotate animated send button
import 'package:flutter/material.dart';
import 'package:flight_chat/l10n/gen/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';

class MessageInput extends StatefulWidget {
  final Function(String) onSend;

  const MessageInput({super.key, required this.onSend});

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  late final AnimationController _animController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: -0.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      if (!MediaQuery.disableAnimationsOf(context)) {
        _animController.forward().then((_) {
          if (mounted) {
            _animController.reverse();
          }
        });
      }
      widget.onSend(text);
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0).copyWith(
        bottom: MediaQuery.of(context).padding.bottom + 8.0,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(
            color: AppColors.border.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 5,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _handleSend(),
              // Il payload deve stare in un pacchetto BLE (Fase 3/5).
              maxLength: AppConstants.bleMtu,
              decoration: InputDecoration(
                hintText: l10n.messageHint,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              // Contatore nascosto finché il limite non è vicino: un muro
              // silenzioso a 512 caratteri sarebbe peggio del rumore visivo.
              buildCounter: (
                context, {
                required int currentLength,
                required bool isFocused,
                int? maxLength,
              }) {
                if (maxLength == null || currentLength < maxLength * 0.9) {
                  return null;
                }
                return Text(
                  '$currentLength/$maxLength',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.mutedForeground,
                      ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          ScaleTransition(
            scale: _scaleAnimation,
            child: RotationTransition(
              turns: _rotationAnimation,
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(Icons.send, color: AppColors.onPrimary),
                  tooltip: l10n.sendMessageLabel,
                  onPressed: _handleSend,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
