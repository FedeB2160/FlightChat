// lib/features/chat/presentation/screens/chat_screen.dart — Main chat UI reading state from ChatNotifier
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../notifiers/chat_notifier.dart';
import '../widgets/message_list.dart';
import '../widgets/message_input.dart';
import '../widgets/mesh_status_bar.dart';
import 'package:flight_chat/l10n/gen/app_localizations.dart';

class ChatScreen extends StatefulWidget {
  final String groupId;

  const ChatScreen({super.key, required this.groupId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    final notifier = context.read<ChatNotifier>();
    final visible = _scrollController.hasClients && _scrollController.offset > 100;
    notifier.updateFabVisibility(visible);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handleSend(String text) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await context.read<ChatNotifier>().sendMessage(text);
      _scrollToBottom();
    } catch (e) {
      debugPrint('ChatScreen: invio non riuscito: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.sendFailed),
          backgroundColor: AppColors.destructive,
        ),
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final notifier = context.watch<ChatNotifier>();

    return Scaffold(
      appBar: AppBar(
        // Il titolo è il nome gruppo, che arriva dal database e per chi si
        // unisce risale al campo `n` del QR.
        title: Text(
          notifier.groupName ?? l10n.appTitle,
          style: const TextStyle(fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(32),
          child: Center(child: MeshStatusBar(connectedNodes: 4)),
        ),
      ),
      body: notifier.groupMissing
          ? _GroupMissing(groupId: widget.groupId)
          : Column(
              children: [
                Expanded(
                  child: MessageList(
                    messages: notifier.messages,
                    scrollController: _scrollController,
                    isLoading: notifier.isLoading,
                  ),
                ),
                MessageInput(onSend: _handleSend),
              ],
            ),
      floatingActionButton: notifier.showFab
          ? FloatingActionButton(
              backgroundColor: AppColors.surface,
              tooltip: l10n.scrollToBottomLabel,
              onPressed: _scrollToBottom,
              child: const Icon(Icons.keyboard_arrow_down, color: AppColors.foreground),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}

/// Raggiungibile aprendo /chat/:groupId per un gruppo mai creato né scansionato.
class _GroupMissing extends StatelessWidget {
  final String groupId;

  const _GroupMissing({required this.groupId});

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
            const Icon(Icons.help_outline, size: 48, color: AppColors.border),
            const SizedBox(height: 16),
            Text(
              l10n.groupNotFoundTitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.groupNotFoundHint,
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
