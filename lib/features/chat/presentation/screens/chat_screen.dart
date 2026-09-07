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

  /// Nome scelto dal Capitano. Null per chi entra scansionando il QR: il payload
  /// {g,k,t0} non lo trasporta, quindi l'AppBar cade sul nome dell'app.
  final String? groupName;

  const ChatScreen({super.key, required this.groupId, this.groupName});

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

  void _handleSend(String text) {
    context.read<ChatNotifier>().sendMessage(text);
    _scrollToBottom();
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
        // Il titolo e' il nome gruppo; la status bar mesh sta in `bottom` e non
        // nel Column del titolo, che a text scale alto sfondava i 56dp dell'AppBar.
        title: Text(
          widget.groupName ?? l10n.appTitle,
          style: const TextStyle(fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(32),
          child: Center(child: MeshStatusBar(connectedNodes: 4)),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: MessageList(
              messages: notifier.messages,
              scrollController: _scrollController,
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
