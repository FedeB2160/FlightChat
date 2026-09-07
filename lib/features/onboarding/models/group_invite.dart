// lib/features/onboarding/models/group_invite.dart — QR payload data model for group invitations with validation
import 'dart:convert';

class GroupInvite {
  final String groupId;
  final String aesKey;
  final int t0;

  GroupInvite({
    required this.groupId,
    required this.aesKey,
    required this.t0,
  });

  Map<String, dynamic> toMap() {
    return {
      'g': groupId,
      'k': aesKey,
      't0': t0,
    };
  }

  factory GroupInvite.fromMap(Map<String, dynamic> map) {
    if (!map.containsKey('g') || !map.containsKey('k') || !map.containsKey('t0')) {
      throw const FormatException("Invalid QR payload: missing required fields");
    }
    final groupId = map['g'] as String;
    final aesKey = map['k'] as String;
    final t0 = map['t0'] as int;

    if (groupId.isEmpty) {
      throw const FormatException("Invalid QR payload: groupId is empty");
    }
    if (aesKey.length != 64) {
      throw FormatException("Invalid QR payload: encryptionKey must be 64 hex chars, got ${aesKey.length}");
    }
    if (t0 <= 0) {
      throw const FormatException("Invalid QR payload: t0 must be > 0");
    }

    return GroupInvite(groupId: groupId, aesKey: aesKey, t0: t0);
  }

  String toJson() => json.encode(toMap());

  factory GroupInvite.fromJson(String source) =>
      GroupInvite.fromMap(json.decode(source));
}
