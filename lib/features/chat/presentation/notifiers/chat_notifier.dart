// lib/features/chat/presentation/notifiers/chat_notifier.dart — Chat state management via ChangeNotifier
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/mission_time_service.dart';
import '../../../../shared/models/user_profile.dart';
import '../../../onboarding/data/group_repository.dart';
import '../../../onboarding/data/user_profile_repository.dart';
import '../../../onboarding/models/group_invite.dart';
import '../../data/message_repository.dart';
import '../../models/chat_message.dart';

class ChatNotifier extends ChangeNotifier {
  final String groupId;
  final MessageRepository messageRepo;
  final GroupRepository groupRepo;
  final UserProfileRepository profileRepo;

  ChatNotifier({
    required this.groupId,
    required this.messageRepo,
    required this.groupRepo,
    required this.profileRepo,
  }) {
    _initFuture = _init();
  }

  /// Completa quando gruppo, profilo e messaggi sono stati letti.
  /// I test attendono questo invece di dormire su un timer.
  Future<void> get ready => _initFuture;

  /// True finché gruppo, profilo e messaggi non sono stati letti dal database.
  bool isLoading = true;

  /// True quando `groupId` non corrisponde a nessun gruppo salvato: succede
  /// aprendo un deep link verso un gruppo mai creato o mai scansionato.
  bool groupMissing = false;

  String? groupName;
  UserProfile? localProfile;
  bool showFab = false;

  late final Future<void> _initFuture;
  GroupInvite? _group;
  MissionTimeService? _missionTime;
  final List<ChatMessage> _messages = [];
  bool _disposed = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _safeNotify() {
    // _init e sendMessage sono asincroni: la rotta può essere già stata chiusa.
    if (!_disposed) notifyListeners();
  }

  Future<void> _init() async {
    final group = await groupRepo.getGroup(groupId);
    if (group == null) {
      groupMissing = true;
      isLoading = false;
      _safeNotify();
      return;
    }

    _group = group;
    groupName = group.groupName;
    _missionTime = MissionTimeService(t0: group.t0);
    localProfile = await profileRepo.getLocalProfile();
    _messages.addAll(await messageRepo.getMessages(groupId, group.aesKey));

    isLoading = false;
    _safeNotify();
  }

  /// Cifra e persiste il messaggio, e solo dopo lo mostra in lista: se
  /// l'inserimento falla l'eccezione risale e la UI non mostra un messaggio
  /// che in realtà non è stato salvato.
  Future<void> sendMessage(String text) async {
    final group = _group;
    final missionTime = _missionTime;
    if (group == null || missionTime == null) return;

    final profile = localProfile;
    final message = ChatMessage(
      messageId: const Uuid().v4(),
      senderName: profile?.nickname ?? 'Me',
      senderAvatarIconIndex: profile?.avatarIconIndex ?? 1,
      senderDeviceId: profile?.deviceId ?? 'local-device',
      content: text,
      timeDelta: missionTime.currentTimeDelta(),
      isMine: true,
      status: MessageStatus.sent,
    );

    await messageRepo.insertMessage(message, groupId, group.aesKey);

    _messages.add(message);
    _safeNotify();
  }

  void updateFabVisibility(bool visible) {
    if (showFab != visible) {
      showFab = visible;
      _safeNotify();
    }
  }
}
