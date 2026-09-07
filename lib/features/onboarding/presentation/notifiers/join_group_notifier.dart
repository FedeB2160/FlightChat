// lib/features/onboarding/presentation/notifiers/join_group_notifier.dart — State for join group flow
import 'package:flutter/material.dart';
import '../../../../shared/models/user_profile.dart';
import '../../models/group_invite.dart';

class JoinGroupNotifier extends ChangeNotifier {
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

  void createProfile(String nickname) {
    localProfile = UserProfile.create(
      nickname: nickname,
      iconIndex: selectedAvatarIndex,
    );
  }
}
