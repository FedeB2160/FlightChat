// lib/features/chat/presentation/notifiers/chat_notifier.dart — Chat state management via ChangeNotifier
import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import '../../../../shared/models/user_profile.dart';

class ChatNotifier extends ChangeNotifier {
  final String groupId;

  /// Profilo scelto in onboarding, inoltrato dalla rotta via `state.extra`.
  /// Null solo entrando su /chat direttamente, senza passare da create/join.
  final UserProfile? localProfile;

  /// Nomi dei mittenti mock, gia localizzati dal chiamante che ha il BuildContext.
  final String mockCaptainName;
  final String mockPassengerName;

  final List<ChatMessage> _messages = [];
  bool showFab = false;

  ChatNotifier({
    required this.groupId,
    required this.mockCaptainName,
    required this.mockPassengerName,
    this.localProfile,
  }) {
    _loadMockMessages();
  }

  List<ChatMessage> get messages => List.unmodifiable(_messages);

  void _loadMockMessages() {
    final captain = UserProfile(
      deviceId: 'mock-device-captain-00000000',
      nickname: mockCaptainName,
      avatarIconIndex: 0, // airplanemode_active
    );
    final passenger = UserProfile(
      deviceId: 'mock-device-passenger-00000002',
      nickname: mockPassengerName,
      avatarIconIndex: 1, // person
    );
    final me = localProfile;

    for (int i = 0; i < 15; i++) {
      // DECISION: `isMine` deriva dal mittente, non da un modulo indipendente:
      // prima esistevano messaggi con senderName del Capitano e isMine true.
      // Senza profilo locale ogni mock e di un mittente remoto, e coerente comunque.
      final UserProfile sender;
      final bool isMine;
      if (me != null && i % 3 == 0) {
        sender = me;
        isMine = true;
      } else {
        sender = i % 2 == 0 ? captain : passenger;
        isMine = false;
      }

      _messages.add(
        ChatMessage(
          messageId: 'mock-msg-$i',
          senderId: sender.deviceId,
          senderName: sender.nickname,
          senderAvatarIconIndex: sender.avatarIconIndex,
          senderDeviceId: sender.deviceId,
          content: 'This is a mock message $i from the mesh network.',
          timeDelta: i * 60,
          isMine: isMine,
          status: MessageStatus.delivered,
        ),
      );
    }
  }

  void sendMessage(String text) {
    final profile = localProfile;
    _messages.add(
      ChatMessage(
        messageId: 'local-${DateTime.now().millisecondsSinceEpoch}',
        senderId: profile?.deviceId ?? 'local-device',
        senderName: profile?.nickname ?? 'Me',
        senderAvatarIconIndex: profile?.avatarIconIndex ?? 1,
        senderDeviceId: profile?.deviceId ?? 'local-device',
        content: text,
        // ponytail: il time_delta reale si calcola dal t0 del gruppo. La sorgente
        // del t0 e il DB di Fase 2; qui basta un delta monotono sulla lista.
        timeDelta: _messages.isEmpty ? 0 : _messages.last.timeDelta + 10,
        isMine: true,
        status: MessageStatus.sent,
      ),
    );
    notifyListeners();
  }

  void updateFabVisibility(bool visible) {
    if (showFab != visible) {
      showFab = visible;
      notifyListeners();
    }
  }
}
