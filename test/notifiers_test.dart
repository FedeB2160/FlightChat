import 'package:flight_chat/core/services/database_service.dart';
import 'package:flight_chat/features/chat/data/message_repository.dart';
import 'package:flight_chat/features/chat/presentation/notifiers/chat_notifier.dart';
import 'package:flight_chat/features/onboarding/data/group_repository.dart';
import 'package:flight_chat/features/onboarding/data/user_profile_repository.dart';
import 'package:flight_chat/features/onboarding/models/group_invite.dart';
import 'package:flight_chat/features/onboarding/presentation/notifiers/create_group_notifier.dart';
import 'package:flight_chat/features/onboarding/presentation/notifiers/join_group_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_db.dart';

void main() {
  late DatabaseService db;
  late GroupRepository groups;
  late UserProfileRepository profiles;
  late MessageRepository messages;

  setUp(() async {
    db = await openTestDb();
    groups = GroupRepository(db: db);
    profiles = UserProfileRepository(db: db);
    messages = MessageRepository(db: db);
  });

  tearDown(() async => (await db.database).close());

  CreateGroupNotifier createNotifier() =>
      CreateGroupNotifier(groupRepo: groups, profileRepo: profiles);

  JoinGroupNotifier joinNotifier() =>
      JoinGroupNotifier(groupRepo: groups, profileRepo: profiles);

  Future<ChatNotifier> chatNotifier(String groupId) async {
    final notifier = ChatNotifier(
      groupId: groupId,
      messageRepo: messages,
      groupRepo: groups,
      profileRepo: profiles,
    );
    await notifier.ready;
    return notifier;
  }

  group('CreateGroupNotifier', () {
    test('generateQr creates a valid invite and persists group and profile',
        () async {
      final notifier = createNotifier();
      notifier.selectAvatar(3);
      await notifier.generateQr('Captain Maverick');

      expect(notifier.generatedGroupId, isNotNull);
      expect(notifier.qrData, isNotNull);
      expect(notifier.localProfile!.nickname, 'Captain Maverick');
      expect(notifier.localProfile!.avatarIconIndex, 3);

      final invite = GroupInvite.fromJson(notifier.qrData!);
      expect(invite.groupId, notifier.generatedGroupId);
      expect(invite.aesKey.length, 64);
      // La chiave dev'essere esadecimale, non solo lunga 64.
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(invite.aesKey), true);
      // Senza nome indicato, il payload non porta il campo n.
      expect(invite.groupName, isNull);
      expect(notifier.groupName, isNull);

      // Gruppo e profilo devono essere nel database, non solo in memoria.
      final stored = await groups.getGroup(invite.groupId);
      expect(stored, isNotNull);
      expect(stored!.aesKey, invite.aesKey);
      expect((await profiles.getLocalProfile())!.nickname, 'Captain Maverick');
    });

    test('generateQr saves the group with the captain role', () async {
      final notifier = createNotifier();
      await notifier.generateQr('Captain');

      final database = await db.database;
      final rows = await database.query(
        'groups',
        columns: ['role'],
        where: 'group_id = ?',
        whereArgs: [notifier.generatedGroupId],
      );
      expect(rows.first['role'], 'captain');
    });

    test('generateQr puts the group name in the QR payload', () async {
      final notifier = createNotifier();
      await notifier.generateQr('Captain', groupName: '  Volo AZ1234  ');

      expect(notifier.groupName, 'Volo AZ1234');
      final invite = GroupInvite.fromJson(notifier.qrData!);
      expect(invite.groupName, 'Volo AZ1234');
      expect((await groups.getGroup(invite.groupId))!.groupName, 'Volo AZ1234');
    });

    test('generateQr treats a blank group name as absent', () async {
      final notifier = createNotifier();
      await notifier.generateQr('Captain', groupName: '   ');

      expect(notifier.groupName, isNull);
      expect(GroupInvite.fromJson(notifier.qrData!).groupName, isNull);
    });
  });

  group('JoinGroupNotifier', () {
    String payload({String? name}) {
      final n = name == null ? '' : ',"n":"$name"';
      return '{"g":"join-uuid","k":"$testKey","t0":1600000000$n}';
    }

    test('processScan succeeds on valid json', () {
      final notifier = joinNotifier();
      expect(notifier.processScan(payload()), true);
      expect(notifier.scanSuccess, true);
      expect(notifier.scannedInvite?.groupId, 'join-uuid');
    });

    test('processScan fails on invalid json', () {
      final notifier = joinNotifier();
      expect(notifier.processScan('invalid json payload'), false);
      expect(notifier.scanSuccess, false);
    });

    test('confirmJoin persists profile and group with the member role',
        () async {
      final notifier = joinNotifier();
      notifier.processScan(payload(name: 'Volo AZ1234'));
      notifier.selectAvatar(2);
      await notifier.confirmJoin('Passenger John');

      expect(notifier.localProfile!.nickname, 'Passenger John');
      expect(notifier.localProfile!.avatarIconIndex, 2);

      final stored = await groups.getGroup('join-uuid');
      // Il nome arriva dal campo n: chi si unisce non ha altra fonte.
      expect(stored!.groupName, 'Volo AZ1234');
      expect((await profiles.getLocalProfile())!.nickname, 'Passenger John');

      final database = await db.database;
      final rows = await database.query(
        'groups',
        columns: ['role'],
        where: 'group_id = ?',
        whereArgs: ['join-uuid'],
      );
      expect(rows.first['role'], 'member');
    });

    test('confirmJoin without a scanned invite throws', () {
      expect(joinNotifier().confirmJoin('X'), throwsStateError);
    });
  });

  group('ChatNotifier', () {
    test('loads group, profile and messages from the database', () async {
      final creator = createNotifier();
      await creator.generateQr('Capitano', groupName: 'Volo AZ1234');
      final groupId = creator.generatedGroupId!;
      final key = GroupInvite.fromJson(creator.qrData!).aesKey;

      final notifier = await chatNotifier(groupId);
      expect(notifier.isLoading, false);
      expect(notifier.groupMissing, false);
      expect(notifier.groupName, 'Volo AZ1234');
      expect(notifier.localProfile!.nickname, 'Capitano');
      // Nessun mock: un gruppo nuovo parte vuoto.
      expect(notifier.messages, isEmpty);

      await notifier.sendMessage('Primo messaggio');
      expect(notifier.messages.length, 1);

      // Il messaggio deve essere davvero nel database, cifrato con la chiave.
      final reloaded = await messages.getMessages(groupId, key);
      expect(reloaded.single.content, 'Primo messaggio');
      expect(reloaded.single.isMine, true);
    });

    test('sendMessage carries the local profile and a real time_delta',
        () async {
      final t0 = DateTime.now().millisecondsSinceEpoch ~/ 1000 - 120;
      await profiles.saveLocalProfile(nickname: 'Comandante Ada', iconIndex: 7);
      await groups.saveGroup(
        GroupInvite(groupId: 'g', aesKey: testKey, t0: t0),
        'captain',
      );

      final notifier = await chatNotifier('g');
      await notifier.sendMessage('Hello passengers!');

      final sent = notifier.messages.single;
      expect(sent.senderName, 'Comandante Ada');
      expect(sent.senderAvatarIconIndex, 7);
      // time_delta calcolato dal t0 del gruppo, non da un contatore finto.
      expect(sent.timeDelta, inInclusiveRange(120, 121));
    });

    test('an existing conversation is restored on reopen', () async {
      await groups.saveGroup(
        GroupInvite(groupId: 'g', aesKey: testKey, t0: 1),
        'captain',
      );
      final first = await chatNotifier('g');
      await first.sendMessage('sopravvivo al restart');

      final second = await chatNotifier('g');
      expect(second.messages.single.content, 'sopravvivo al restart');
    });

    test('an unknown group is reported instead of crashing', () async {
      final notifier = await chatNotifier('mai-visto');
      expect(notifier.groupMissing, true);
      expect(notifier.isLoading, false);
      expect(notifier.messages, isEmpty);
      // Senza gruppo l'invio è un no-op, non un'eccezione.
      await notifier.sendMessage('nel vuoto');
      expect(notifier.messages, isEmpty);
    });

    test('updateFabVisibility notifies listeners only on change', () async {
      await groups.saveGroup(
        GroupInvite(groupId: 'g', aesKey: testKey, t0: 1),
        'captain',
      );
      final notifier = await chatNotifier('g');

      int notifyCount = 0;
      notifier.addListener(() => notifyCount++);

      notifier.updateFabVisibility(true);
      expect(notifier.showFab, true);
      expect(notifyCount, 1);

      notifier.updateFabVisibility(true);
      expect(notifyCount, 1);
    });
  });
}
