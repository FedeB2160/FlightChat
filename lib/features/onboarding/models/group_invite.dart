// lib/features/onboarding/models/group_invite.dart — QR payload data model for group invitations with validation
import 'dart:convert';

class GroupInvite {
  static final RegExp _hex64 = RegExp(r'^[0-9a-fA-F]{64}$');

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

    return GroupInvite(groupId: groupId, aesKey: aesKey, t0: t0);
  }

  String toJson() => json.encode(toMap());

  factory GroupInvite.fromJson(String source) =>
      GroupInvite.fromMap(json.decode(source));
}
