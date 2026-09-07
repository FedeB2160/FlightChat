// lib/features/onboarding/presentation/notifiers/create_group_notifier.dart — State for group creation flow
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';
import '../../../../shared/models/user_profile.dart';
import '../../models/group_invite.dart';

class CreateGroupNotifier extends ChangeNotifier {
  String? qrData;
  String? generatedGroupId;
  int selectedAvatarIndex = 1;
  UserProfile? localProfile;

  String _generateRandomHex(int bytes) {
    final random = Random.secure();
    final values = List<int>.generate(bytes, (i) => random.nextInt(256));
    return values.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
  }

  void generateQr(String nickname) {
    final groupId = const Uuid().v4();
    final aesKey = _generateRandomHex(32); // 64 chars hex
    final t0 = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final invite = GroupInvite(groupId: groupId, aesKey: aesKey, t0: t0);

    localProfile = UserProfile.create(
      nickname: nickname,
      iconIndex: selectedAvatarIndex,
    );

    generatedGroupId = groupId;
    qrData = invite.toJson();
    notifyListeners();
  }

  void selectAvatar(int index) {
    selectedAvatarIndex = index;
    notifyListeners();
  }
}
