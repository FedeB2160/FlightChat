import 'package:flutter_test/flutter_test.dart';
import 'package:flight_chat/features/chat/presentation/notifiers/chat_notifier.dart';
import 'package:flight_chat/features/onboarding/presentation/notifiers/create_group_notifier.dart';
import 'package:flight_chat/features/onboarding/presentation/notifiers/join_group_notifier.dart';
import 'package:flight_chat/features/onboarding/models/group_invite.dart';
import 'package:flight_chat/shared/models/user_profile.dart';

ChatNotifier buildChatNotifier({UserProfile? profile}) => ChatNotifier(
      groupId: 'test-group',
      localProfile: profile,
      mockCaptainName: 'Capitano',
      mockPassengerName: 'Passeggero-2',
    );

void main() {
  group('ChatNotifier', () {
    test('initializes with 15 mock messages using the localized sender names', () {
      final notifier = buildChatNotifier();
      expect(notifier.messages.length, 15);
      expect(notifier.showFab, false);

      final captainMsg =
          notifier.messages.firstWhere((m) => m.senderName == 'Capitano');
      final anotherCaptainMsg =
          notifier.messages.lastWhere((m) => m.senderName == 'Capitano');
      expect(captainMsg.senderDeviceId, anotherCaptainMsg.senderDeviceId);
      expect(
        notifier.messages.any((m) => m.senderName == 'Passeggero-2'),
        true,
      );
    });

    test('mock isMine always agrees with the sender identity', () {
      final profile = UserProfile.create(nickname: 'Io', iconIndex: 5);
      final notifier = buildChatNotifier(profile: profile);

      for (final message in notifier.messages) {
        expect(
          message.isMine,
          message.senderDeviceId == profile.deviceId,
          reason: 'isMine e mittente divergono su ${message.messageId}',
        );
      }
      // Entrambi i tipi di bolla devono essere rappresentati nei mock.
      expect(notifier.messages.any((m) => m.isMine), true);
      expect(notifier.messages.any((m) => !m.isMine), true);
    });

    test('without a local profile no mock message is mine', () {
      final notifier = buildChatNotifier();
      expect(notifier.messages.any((m) => m.isMine), false);
    });

    test('sendMessage carries the onboarding profile', () {
      final profile = UserProfile.create(nickname: 'Comandante Ada', iconIndex: 7);
      final notifier = buildChatNotifier(profile: profile);
      notifier.sendMessage('Hello passengers!');

      final sent = notifier.messages.last;
      expect(notifier.messages.length, 16);
      expect(sent.content, 'Hello passengers!');
      expect(sent.isMine, true);
      expect(sent.senderName, 'Comandante Ada');
      expect(sent.senderAvatarIconIndex, 7);
      expect(sent.senderDeviceId, profile.deviceId);
    });

    test('sendMessage falls back when no profile reached the chat', () {
      final notifier = buildChatNotifier();
      notifier.sendMessage('Anonimo');
      expect(notifier.messages.last.senderName, 'Me');
      expect(notifier.messages.last.isMine, true);
    });

    test('sendMessage keeps time_delta strictly increasing', () {
      final notifier = buildChatNotifier();
      final before = notifier.messages.last.timeDelta;
      notifier.sendMessage('primo');
      notifier.sendMessage('secondo');

      final deltas = notifier.messages.map((m) => m.timeDelta).toList();
      expect(deltas.last > before, true);
      for (int i = 1; i < deltas.length; i++) {
        expect(deltas[i] >= deltas[i - 1], true);
      }
    });

    test('updateFabVisibility notifies listeners when value changes', () {
      final notifier = buildChatNotifier();
      int notifyCount = 0;
      notifier.addListener(() => notifyCount++);

      notifier.updateFabVisibility(true);
      expect(notifier.showFab, true);
      expect(notifyCount, 1);

      // No notify if unchanged
      notifier.updateFabVisibility(true);
      expect(notifyCount, 1);
    });
  });

  group('CreateGroupNotifier', () {
    test('generateQr creates valid invite and UserProfile', () {
      final notifier = CreateGroupNotifier();
      notifier.selectAvatar(3);
      notifier.generateQr('Captain Maverick');

      expect(notifier.generatedGroupId, isNotNull);
      expect(notifier.qrData, isNotNull);
      expect(notifier.localProfile, isNotNull);
      expect(notifier.localProfile!.nickname, 'Captain Maverick');
      expect(notifier.localProfile!.avatarIconIndex, 3);

      final invite = GroupInvite.fromJson(notifier.qrData!);
      expect(invite.groupId, notifier.generatedGroupId);
      expect(invite.aesKey.length, 64);
      // La chiave dev'essere esadecimale, non solo lunga 64.
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(invite.aesKey), true);
    });
  });

  group('JoinGroupNotifier', () {
    const validKey = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

    test('processScan succeeds on valid json', () {
      final notifier = JoinGroupNotifier();
      final success = notifier.processScan(
        '{"g":"join-uuid","k":"$validKey","t0":1600000000}',
      );
      expect(success, true);
      expect(notifier.scanSuccess, true);
      expect(notifier.scannedInvite?.groupId, 'join-uuid');
    });

    test('processScan fails on invalid json', () {
      final notifier = JoinGroupNotifier();
      final success = notifier.processScan('invalid json payload');
      expect(success, false);
      expect(notifier.scanSuccess, false);
    });

    test('createProfile saves local UserProfile', () {
      final notifier = JoinGroupNotifier();
      notifier.selectAvatar(2);
      notifier.createProfile('Passenger John');

      expect(notifier.localProfile, isNotNull);
      expect(notifier.localProfile!.nickname, 'Passenger John');
      expect(notifier.localProfile!.avatarIconIndex, 2);
    });
  });
}
