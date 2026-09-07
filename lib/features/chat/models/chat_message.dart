// lib/features/chat/models/chat_message.dart — Chat message domain model
import '../../../core/services/mission_time_service.dart';

enum MessageStatus { sending, sent, delivered }

class ChatMessage {
  final String messageId;
  final String senderName;
  final int senderAvatarIconIndex;
  final String senderDeviceId;

  /// Contenuto in chiaro. Nel database vive cifrato in `content_encrypted`:
  /// vuoto quando `decryptFailed` e true.
  final String content;

  final int timeDelta; // seconds from t0
  final bool isMine;
  final MessageStatus status;

  /// True quando la riga esiste nel database ma il contenuto non e decifrabile
  /// (tag GCM non valido, chiave del gruppo diversa, blob corrotto). La bolla
  /// mostra un segnaposto: mittente e orario sono in chiaro e restano leggibili.
  final bool decryptFailed;

  ChatMessage({
    required this.messageId,
    required this.senderName,
    required this.senderAvatarIconIndex,
    required this.senderDeviceId,
    required this.content,
    required this.timeDelta,
    required this.isMine,
    required this.status,
    this.decryptFailed = false,
  });

  String get formattedTime => MissionTimeService.formatDelta(timeDelta);

  // DECISION: rimossa la factory `ChatMessage.mock()` prescritta dal piano:
  // zero chiamanti, e ChatNotifier costruisce i mock direttamente col profilo reale.
  //
  // DECISION: rimosso `senderId`, che era sempre uguale a `senderDeviceId`, non
  // era usato da nessun widget e non ha una colonna nello schema di Fase 2.
}
