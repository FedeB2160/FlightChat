import 'dart:convert';

import 'package:flight_chat/core/services/database_service.dart';
import 'package:flight_chat/features/chat/data/message_repository.dart';
import 'package:flight_chat/features/chat/models/chat_message.dart';
import 'package:flight_chat/features/onboarding/data/group_repository.dart';
import 'package:flight_chat/features/onboarding/data/user_profile_repository.dart';
import 'package:flight_chat/features/onboarding/models/group_invite.dart';
import 'package:flight_chat/shared/models/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_db.dart';

ChatMessage message({
  required String id,
  String content = 'ciao',
  int timeDelta = 0,
  bool isMine = false,
  MessageStatus status = MessageStatus.sent,
}) =>
    ChatMessage(
      messageId: id,
      senderName: 'Capitano',
      senderAvatarIconIndex: 0,
      senderDeviceId: 'device-a',
      content: content,
      timeDelta: timeDelta,
      isMine: isMine,
      status: status,
    );

void main() {
  late DatabaseService db;
  late GroupRepository groups;
  late UserProfileRepository profiles;
  late MessageRepository messages;

  final invite = GroupInvite(
    groupId: 'group-1',
    aesKey: testKey,
    t0: 1700000000,
    groupName: 'Volo AZ1234',
  );

  setUp(() async {
    db = await openTestDb();
    groups = GroupRepository(db: db);
    profiles = UserProfileRepository(db: db);
    messages = MessageRepository(db: db);
  });

  tearDown(() async => (await db.database).close());

  group('GroupRepository', () {
    test('saves and reads back a group, name included', () async {
      await groups.saveGroup(invite, 'captain');
      final stored = await groups.getGroup('group-1');

      expect(stored, isNotNull);
      expect(stored!.groupId, 'group-1');
      expect(stored.aesKey, testKey);
      expect(stored.t0, 1700000000);
      // Il nome risale al campo n del QR: e la sola fonte per chi si unisce.
      expect(stored.groupName, 'Volo AZ1234');
    });

    test('an explicit groupName wins over the one in the invite', () async {
      await groups.saveGroup(invite, 'member', groupName: 'Volo rinominato');
      expect((await groups.getGroup('group-1'))!.groupName, 'Volo rinominato');
    });

    test('a blank explicit groupName falls back to the invite', () async {
      await groups.saveGroup(invite, 'member', groupName: '   ');
      expect((await groups.getGroup('group-1'))!.groupName, 'Volo AZ1234');
    });

    test('saving twice updates instead of failing', () async {
      await groups.saveGroup(invite, 'captain');
      await groups.saveGroup(
        GroupInvite(groupId: 'group-1', aesKey: otherKey, t0: 42),
        'member',
      );

      final stored = await groups.getGroup('group-1');
      expect(stored!.aesKey, otherKey);
      expect(stored.t0, 42);
      expect((await groups.getAllGroups()).length, 1);
    });

    test('getEncryptionKey returns the key, null for an unknown group', () async {
      await groups.saveGroup(invite, 'captain');
      expect(await groups.getEncryptionKey('group-1'), testKey);
      expect(await groups.getEncryptionKey('nope'), isNull);
    });

    test('getGroup returns null for an unknown group', () async {
      expect(await groups.getGroup('nope'), isNull);
    });
  });

  group('UserProfileRepository', () {
    test('saveLocalProfile keeps the deviceId stable across calls', () async {
      // Senza questo, ogni passaggio da onboarding cambierebbe l'identita
      // del nodo sotto i piedi alla mesh.
      final first = await profiles.saveLocalProfile(
        nickname: 'Capitano',
        iconIndex: 0,
      );
      final second = await profiles.saveLocalProfile(
        nickname: 'Comandante',
        iconIndex: 5,
      );

      expect(second.deviceId, first.deviceId);
      expect(second.nickname, 'Comandante');
      expect(second.avatarIconIndex, 5);
    });

    test('there is at most one local profile', () async {
      await profiles.saveLocalProfile(nickname: 'A', iconIndex: 0);
      await profiles.saveProfile(
        UserProfile(deviceId: 'remote-1', nickname: 'B', avatarIconIndex: 1),
      );
      await profiles.saveProfile(
        UserProfile(deviceId: 'remote-2', nickname: 'C', avatarIconIndex: 2),
        isLocal: true,
      );

      final local = await profiles.getLocalProfile();
      expect(local!.deviceId, 'remote-2');

      final database = await db.database;
      final rows = await database.query(
        'user_profiles',
        where: 'is_local = 1',
      );
      expect(rows.length, 1);
    });

    test('getLocalProfile is null before onboarding', () async {
      expect(await profiles.getLocalProfile(), isNull);
    });

    test('getProfile reads a remote node profile', () async {
      await profiles.saveProfile(
        UserProfile(deviceId: 'device-a', nickname: 'Passeggero', avatarIconIndex: 3),
      );
      final stored = await profiles.getProfile('device-a');
      expect(stored!.nickname, 'Passeggero');
      expect(stored.avatarIconIndex, 3);
      expect(await profiles.getProfile('nope'), isNull);
    });

    test('updateLastSeen stores the delta', () async {
      await profiles.saveProfile(
        UserProfile(deviceId: 'device-a', nickname: 'P', avatarIconIndex: 0),
      );
      await profiles.updateLastSeen('device-a', 1234);

      final database = await db.database;
      final rows = await database.query(
        'user_profiles',
        where: 'device_id = ?',
        whereArgs: ['device-a'],
      );
      expect(rows.first['last_seen_delta'], 1234);
    });
  });

  group('MessageRepository', () {
    setUp(() async => groups.saveGroup(invite, 'captain'));

    test('stores the content encrypted and reads it back in clear', () async {
      await messages.insertMessage(
        message(id: 'm1', content: 'Atterriamo alle 18'),
        'group-1',
        testKey,
      );

      final stored = await messages.getMessages('group-1', testKey);
      expect(stored.length, 1);
      expect(stored.first.content, 'Atterriamo alle 18');
      expect(stored.first.decryptFailed, false);
      expect(stored.first.senderName, 'Capitano');
      expect(stored.first.status, MessageStatus.sent);
    });

    test('the stored blob does not contain the plaintext', () async {
      const secret = 'CodiceSegretoDelVolo';
      await messages.insertMessage(
        message(id: 'm1', content: secret),
        'group-1',
        testKey,
      );

      final database = await db.database;
      final rows = await database.query('messages', columns: ['content_encrypted']);
      final blob = rows.first['content_encrypted'] as List<int>;

      // La verifica che conta: il testo in chiaro non deve comparire nel BLOB.
      expect(utf8.decode(blob, allowMalformed: true).contains(secret), false);
      expect(String.fromCharCodes(blob).contains(secret), false);
    });

    test('the same message_id inserted twice yields one row', () async {
      await messages.insertMessage(message(id: 'dup'), 'group-1', testKey);
      await messages.insertMessage(
        message(id: 'dup', content: 'altro contenuto'),
        'group-1',
        testKey,
      );

      final stored = await messages.getMessages('group-1', testKey);
      expect(stored.length, 1);
      // ON CONFLICT IGNORE: vince il primo inserimento.
      expect(stored.first.content, 'ciao');
    });

    test('messages come back in ascending time order', () async {
      for (final delta in [300, 100, 200]) {
        await messages.insertMessage(
          message(id: 'm$delta', timeDelta: delta),
          'group-1',
          testKey,
        );
      }

      final stored = await messages.getMessages('group-1', testKey);
      expect(stored.map((m) => m.timeDelta).toList(), [100, 200, 300]);
    });

    test('limit returns the most recent messages, not the oldest', () async {
      for (int i = 0; i < 10; i++) {
        await messages.insertMessage(
          message(id: 'm$i', content: 'msg $i', timeDelta: i * 60),
          'group-1',
          testKey,
        );
      }

      final stored = await messages.getMessages('group-1', testKey, limit: 3);
      expect(stored.map((m) => m.content).toList(), ['msg 7', 'msg 8', 'msg 9']);
    });

    test('a message that cannot be decrypted is flagged, not dropped', () async {
      await messages.insertMessage(
        message(id: 'm1', content: 'segreto', timeDelta: 42),
        'group-1',
        testKey,
      );

      final stored = await messages.getMessages('group-1', otherKey);
      expect(stored.length, 1);
      expect(stored.first.decryptFailed, true);
      expect(stored.first.content, '');
      // Mittente e orario sono in chiaro nel database e restano leggibili.
      expect(stored.first.senderName, 'Capitano');
      expect(stored.first.timeDelta, 42);
    });

    test('messages of other groups are not returned', () async {
      await groups.saveGroup(
        GroupInvite(groupId: 'group-2', aesKey: otherKey, t0: 1),
        'member',
      );
      await messages.insertMessage(message(id: 'a'), 'group-1', testKey);
      await messages.insertMessage(message(id: 'b'), 'group-2', otherKey);

      expect((await messages.getMessages('group-1', testKey)).length, 1);
    });

    test('messageExists reports known ids', () async {
      await messages.insertMessage(message(id: 'known'), 'group-1', testKey);
      expect(await messages.messageExists('known'), true);
      expect(await messages.messageExists('unknown'), false);
    });

    test('a message for a non-existent group is rejected', () async {
      // Prova che PRAGMA foreign_keys sia davvero attivo.
      expect(
        () => messages.insertMessage(message(id: 'orphan'), 'ghost', testKey),
        throwsA(isA<Object>()),
      );
    });
  });
}
