// lib/features/onboarding/presentation/notifiers/join_group_notifier.dart — State for join group flow
import 'package:flutter/material.dart';

import '../../../../shared/models/user_profile.dart';
import '../../data/group_repository.dart';
import '../../data/user_profile_repository.dart';
import '../../models/group_invite.dart';

class JoinGroupNotifier extends ChangeNotifier {
  final GroupRepository groupRepo;
  final UserProfileRepository profileRepo;

  JoinGroupNotifier({required this.groupRepo, required this.profileRepo});

  bool scanSuccess = false;
  GroupInvite? scannedInvite;
  int selectedAvatarIndex = 1;
  UserProfile? localProfile;

  /// Returns true on success, false on parse error.
  bool processScan(String rawValue) {
    try {
      final invite = GroupInvite.fromJson(rawValue);
      scannedInvite = invite;
      scanSuccess = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('JoinGroupNotifier: QR payload rifiutato: $e');
      return false;
    }
  }

  void selectAvatar(int index) {
    selectedAvatarIndex = index;
    notifyListeners();
  }

  /// Persiste il profilo locale e il gruppo scansionato, con ruolo `'member'`.
  ///
  /// Il nome del gruppo arriva dal campo `n` del QR: e la sola fonte per chi si
  /// unisce, che non ha mai visto la schermata di creazione.
  Future<void> confirmJoin(String nickname) async {
    final invite = scannedInvite;
    if (invite == null) {
      throw StateError('confirmJoin chiamato senza un invito scansionato');
    }

    localProfile = await profileRepo.saveLocalProfile(
      nickname: nickname,
      iconIndex: selectedAvatarIndex,
    );
    await groupRepo.saveGroup(invite, 'member');
  }
}
