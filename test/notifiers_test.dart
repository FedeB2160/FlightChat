import 'package:flutter_test/flutter_test.dart';
import 'package:flight_chat/features/chat/presentation/notifiers/chat_notifier.dart';
import 'package:flight_chat/features/onboarding/presentation/notifiers/create_group_notifier.dart';
import 'package:flight_chat/features/onboarding/presentation/notifiers/join_group_notifier.dart';
import 'package:flight_chat/features/onboarding/models/group_invite.dart';

void main() {
  group('ChatNotifier', () {
    test('initializes with 15 mock messages and stable sender device IDs', () {
      final notifier = ChatNotifier(groupId: 'test-group');
      expect(notifier.messages.length, 15);
      expect(notifier.showFab, false);

      final captainMsg = notifier.messages.firstWhere((m) => m.senderName == 'Captain');
      final anotherCaptainMsg = notifier.messages.lastWhere((m) => m.senderName == 'Captain');
      expect(captainMsg.senderDeviceId, anotherCaptainMsg.senderDeviceId);
    });

    test('sendMessage adds a new local message', () {
      final notifier = ChatNotifier(groupId: 'test-group');
      notifier.sendMessage('Hello passengers!');
      expect(notifier.messages.length, 16);
      expect(notifier.messages.last.content, 'Hello passengers!');
      expect(notifier.messages.last.isMine, true);
    });

    test('updateFabVisibility notifies listeners when value changes', () {
      final notifier = ChatNotifier(groupId: 'test-group');
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
