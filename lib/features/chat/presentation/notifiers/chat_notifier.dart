// lib/features/chat/presentation/notifiers/chat_notifier.dart — Chat state management via ChangeNotifier
import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import '../../../../shared/models/user_profile.dart';

class ChatNotifier extends ChangeNotifier {
  final String groupId;
  final UserProfile? localProfile;
  final List<ChatMessage> _messages = [];
  bool showFab = false;

  ChatNotifier({required this.groupId, this.localProfile}) {
    _loadMockMessages();
  }

  List<ChatMessage> get messages => List.unmodifiable(_messages);

  void _loadMockMessages() {
    // DECISION: Using UserProfile.create to generate mock senders with stable deviceIds
    final captain = UserProfile(
      deviceId: 'mock-device-captain-00000000',
      nickname: 'Captain',
      avatarIconIndex: 0, // airplanemode_active
    );
    final passenger2 = UserProfile(
      deviceId: 'mock-device-passenger-00000002',
      nickname: 'Passenger-2',
      avatarIconIndex: 1, // person
    );

    for (int i = 0; i < 15; i++) {
      final sender = i % 2 == 0 ? captain : passenger2;
      _messages.add(
        ChatMessage(
          messageId: 'mock-msg-$i',
          senderId: sender.deviceId,
          senderName: sender.nickname,
          senderAvatarIconIndex: sender.avatarIconIndex,
          senderDeviceId: sender.deviceId,
          content: "This is a mock message $i from the mesh network.",
          timeDelta: i * 60,
          isMine: i % 3 == 0,
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
        timeDelta: _messages.last.timeDelta + 10,
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
