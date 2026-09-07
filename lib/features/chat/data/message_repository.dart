// lib/features/chat/data/message_repository.dart — CRUD messaggi cifrati, con deduplicazione per message_id
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/services/crypto_service.dart';
import '../../../core/services/database_service.dart';
import '../models/chat_message.dart';

class MessageRepository {
  final DatabaseService db;

  /// DECISION: nessun parametro `crypto`. Il piano si contraddice — lo richiede
  /// nella firma, non lo passa in main.dart, e vieta CryptoService come Provider.
  /// Vince il vincolo esplicito: CryptoService ha metodi statici.
  MessageRepository({required this.db});

  Future<void> insertMessage(
    ChatMessage msg,
    String groupId,
    String hexKey,
  ) async {
    final database = await db.database;

    await database.insert(
      'messages',
      {
        'message_id': msg.messageId,
        'group_id': groupId,
        'sender_device_id': msg.senderDeviceId,
        'sender_name': msg.senderName,
        'sender_avatar_icon_index': msg.senderAvatarIconIndex,
        'content_encrypted': CryptoService.encrypt(msg.content, hexKey),
        'time_delta': msg.timeDelta,
        'status': msg.status.name,
        'is_mine': msg.isMine ? 1 : 0,
      },
      // Deduplicazione: lo stesso message_id che rimbalza nella mesh non
      // produce un secondo record.
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Restituisce i messaggi **piu recenti** del gruppo, in ordine cronologico.
  ///
  /// DECISION: il piano dice "ordinata per time_delta ASC" con limit e offset,
  /// che per una chat e sbagliato — con ASC e offset 0 un limit di 50
  /// restituirebbe i 50 messaggi piu vecchi. Si interroga DESC per prendere la
  /// coda della conversazione e si restituisce ASC, l'ordine che MessageList
  /// si aspetta e quello prescritto dall'architettura (time_delta, poi message_id).
  Future<List<ChatMessage>> getMessages(
    String groupId,
    String hexKey, {
    int limit = 50,
    int offset = 0,
  }) async {
    final database = await db.database;
    final rows = await database.query(
      'messages',
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: 'time_delta DESC, message_id DESC',
      limit: limit,
      offset: offset,
    );

    return rows.reversed.map((row) => _fromRow(row, hexKey)).toList();
  }

  /// Usato dalla deduplicazione del gossip protocol in Fase 5.
  Future<bool> messageExists(String messageId) async {
    final database = await db.database;
    final rows = await database.query(
      'messages',
      columns: ['message_id'],
      where: 'message_id = ?',
      whereArgs: [messageId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  ChatMessage _fromRow(Map<String, Object?> row, String hexKey) {
    final blob = row['content_encrypted'];
    String content = '';
    bool decryptFailed = false;

    try {
      content = CryptoService.decrypt(
        blob is Uint8List ? blob : Uint8List.fromList(blob as List<int>),
        hexKey,
      );
    } catch (e) {
      // Il piano non copre questo caso. La riga non viene scartata: mittente e
      // orario sono in chiaro e restano visibili, la UI mostra un segnaposto.
      // Scartarla in silenzio nasconderebbe una perdita di dati.
      decryptFailed = true;
      debugPrint(
        'MessageRepository: contenuto non decifrabile '
        'per ${row['message_id']}: $e',
      );
    }

    return ChatMessage(
      messageId: row['message_id'] as String,
      senderName: row['sender_name'] as String,
      senderAvatarIconIndex: row['sender_avatar_icon_index'] as int,
      senderDeviceId: row['sender_device_id'] as String,
      content: content,
      timeDelta: row['time_delta'] as int,
      isMine: (row['is_mine'] as int) == 1,
      status: _statusFromName(row['status'] as String),
      decryptFailed: decryptFailed,
    );
  }

  static MessageStatus _statusFromName(String name) => MessageStatus.values
      .firstWhere((s) => s.name == name, orElse: () => MessageStatus.sent);
}
