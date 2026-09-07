// lib/features/onboarding/presentation/notifiers/create_group_notifier.dart — State for group creation flow
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../shared/models/user_profile.dart';
import '../../data/group_repository.dart';
import '../../data/user_profile_repository.dart';
import '../../models/group_invite.dart';

class CreateGroupNotifier extends ChangeNotifier {
  final GroupRepository groupRepo;
  final UserProfileRepository profileRepo;

  CreateGroupNotifier({required this.groupRepo, required this.profileRepo});

  String? qrData;
  String? generatedGroupId;
  String? groupName;
  int selectedAvatarIndex = 1;
  UserProfile? localProfile;

  String _generateRandomHex(int bytes) {
    final random = Random.secure();
    final values = List<int>.generate(bytes, (i) => random.nextInt(256));
    return values.map((e) => e.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Genera l'invito e lo persiste. Solleva se la scrittura sul database falla:
  /// mostrare un QR per un gruppo che non esiste sarebbe peggio di un errore.
  Future<void> generateQr(String nickname, {String? groupName}) async {
    final groupId = const Uuid().v4();
    final aesKey = _generateRandomHex(32); // 64 chars hex
    final t0 = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final trimmedName = groupName?.trim();
    this.groupName =
        (trimmedName == null || trimmedName.isEmpty) ? null : trimmedName;

    final invite = GroupInvite(
      groupId: groupId,
      aesKey: aesKey,
      t0: t0,
      groupName: this.groupName,
    );

    localProfile = await profileRepo.saveLocalProfile(
      nickname: nickname,
      iconIndex: selectedAvatarIndex,
    );
    await groupRepo.saveGroup(invite, 'captain');

    generatedGroupId = groupId;
    qrData = invite.toJson();
    notifyListeners();
  }

  void selectAvatar(int index) {
    selectedAvatarIndex = index;
    notifyListeners();
  }
}
