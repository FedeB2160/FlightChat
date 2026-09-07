// lib/features/chat/models/chat_message.dart — Chat message domain model and mock factory
import 'package:uuid/uuid.dart';

enum MessageStatus { sending, sent, delivered }

class ChatMessage {
  final String messageId;
  final String senderId;
  final String senderName;
  final int senderAvatarIconIndex;
  final String senderDeviceId;
  final String content;
  final int timeDelta; // seconds from t0
  final bool isMine;
  final MessageStatus status;

  ChatMessage({
    required this.messageId,
    required this.senderId,
    required this.senderName,
    required this.senderAvatarIconIndex,
    required this.senderDeviceId,
    required this.content,
    required this.timeDelta,
    required this.isMine,
    required this.status,
  });

  String get formattedTime {
    final duration = Duration(seconds: timeDelta);
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return 'T+$hours:$minutes:$seconds';
  }

  factory ChatMessage.mock({
    required String senderName,
    required String content,
    required int timeDelta,
    required bool isMine,
    MessageStatus status = MessageStatus.delivered,
  }) {
    final cleanName = senderName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return ChatMessage(
      messageId: const Uuid().v4(),
      senderId: 'mock-user-$cleanName',
      senderName: senderName,
      senderAvatarIconIndex: 1, // Default person icon index
      senderDeviceId: 'mock-device-$cleanName',
      content: content,
      timeDelta: timeDelta,
      isMine: isMine,
      status: status,
    );
  }
}
