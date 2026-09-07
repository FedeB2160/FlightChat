// lib/features/onboarding/models/group_invite.dart — QR payload data model for group invitations with validation
import 'dart:convert';

class GroupInvite {
  static final RegExp _hex64 = RegExp(r'^[0-9a-fA-F]{64}$');

  /// Limite del nome gruppo nel payload. Tiene bassa la densità del QR e vale
  /// anche come `maxLength` del campo di input in CreateGroupScreen.
  static const int maxGroupNameLength = 60;

  final String groupId;
  final String aesKey;
  final int t0;

  /// Nome scelto dal Capitano, trasportato dal QR come campo `n` così che anche
  /// chi si unisce scansionando lo riceva. Null quando non è stato indicato.
  final String? groupName;

  GroupInvite({
    required this.groupId,
    required this.aesKey,
    required this.t0,
    this.groupName,
  });

  Map<String, dynamic> toMap() {
    return {
      'g': groupId,
      'k': aesKey,
      't0': t0,
      // `n` è omesso quando manca: i QR senza nome restano identici a prima.
      if (groupName != null) 'n': groupName,
    };
  }

  factory GroupInvite.fromMap(Map<String, dynamic> map) {
    if (!map.containsKey('g') || !map.containsKey('k') || !map.containsKey('t0')) {
      throw const FormatException("Invalid QR payload: missing required fields");
    }
    final rawGroupId = map['g'];
    final rawAesKey = map['k'];
    final rawT0 = map['t0'];
    if (rawGroupId is! String || rawAesKey is! String || rawT0 is! int) {
      throw const FormatException('Invalid QR payload: unexpected field types');
    }
    final groupId = rawGroupId;
    final aesKey = rawAesKey;
    final t0 = rawT0;

    if (groupId.isEmpty) {
      throw const FormatException("Invalid QR payload: groupId is empty");
    }
    if (!_hex64.hasMatch(aesKey)) {
      throw FormatException(
        "Invalid QR payload: encryptionKey must be 64 hex chars, got ${aesKey.length}",
      );
    }
    if (t0 <= 0) {
      throw const FormatException("Invalid QR payload: t0 must be > 0");
    }

    // `n` è opzionale: un payload generato prima della sua introduzione resta valido.
    String? groupName;
    if (map.containsKey('n') && map['n'] != null) {
      final rawGroupName = map['n'];
      if (rawGroupName is! String) {
        throw const FormatException('Invalid QR payload: groupName must be a string');
      }
      if (rawGroupName.length > maxGroupNameLength) {
        throw FormatException(
          "Invalid QR payload: groupName must be at most "
          "$maxGroupNameLength chars, got ${rawGroupName.length}",
        );
      }
      final trimmed = rawGroupName.trim();
      groupName = trimmed.isEmpty ? null : trimmed;
    }

    return GroupInvite(
      groupId: groupId,
      aesKey: aesKey,
      t0: t0,
      groupName: groupName,
    );
  }

  String toJson() => json.encode(toMap());

  factory GroupInvite.fromJson(String source) =>
      GroupInvite.fromMap(json.decode(source));
}
