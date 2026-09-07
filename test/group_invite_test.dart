import 'package:flutter_test/flutter_test.dart';
import 'package:flight_chat/features/onboarding/models/group_invite.dart';

void main() {
  group('GroupInvite', () {
    const validKey = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

    test('valid payload parses successfully', () {
      final invite = GroupInvite.fromJson(
        '{"g":"test-group","k":"$validKey","t0":1700000000}',
      );
      expect(invite.groupId, 'test-group');
      expect(invite.aesKey, validKey);
      expect(invite.t0, 1700000000);
    });

    test('throws when required fields missing', () {
      expect(
        () => GroupInvite.fromJson('{"g":"test-group","k":"$validKey"}'),
        throwsFormatException,
      );
    });

    test('throws when groupId is empty', () {
      expect(
        () => GroupInvite.fromJson('{"g":"","k":"$validKey","t0":100}'),
        throwsFormatException,
      );
    });

    test('throws when aesKey length is not 64', () {
      expect(
        () => GroupInvite.fromJson('{"g":"test-group","k":"short","t0":100}'),
        throwsFormatException,
      );
    });

    test('throws when aesKey is 64 chars but not hexadecimal', () {
      final notHex = 'z' * 64;
      expect(
        () => GroupInvite.fromJson('{"g":"test-group","k":"$notHex","t0":100}'),
        throwsFormatException,
      );
    });

    test('throws FormatException on wrong field types', () {
      expect(
        () => GroupInvite.fromJson('{"g":"test-group","k":"$validKey","t0":"100"}'),
        throwsFormatException,
      );
      expect(
        () => GroupInvite.fromJson('{"g":123,"k":"$validKey","t0":100}'),
        throwsFormatException,
      );
    });

    test('parses the optional group name from field n', () {
      final invite = GroupInvite.fromJson(
        '{"g":"test-group","k":"$validKey","t0":100,"n":"Volo AZ1234"}',
      );
      expect(invite.groupName, 'Volo AZ1234');
    });

    test('payload without n stays valid', () {
      // Retrocompatibilita: i QR generati prima del campo n devono parsare.
      final invite = GroupInvite.fromJson(
        '{"g":"test-group","k":"$validKey","t0":100}',
      );
      expect(invite.groupName, isNull);
    });

    test('blank or whitespace n becomes null', () {
      for (final raw in ['""', '"   "']) {
        final invite = GroupInvite.fromJson(
          '{"g":"test-group","k":"$validKey","t0":100,"n":$raw}',
        );
        expect(invite.groupName, isNull);
      }
    });

    test('throws when n is not a string', () {
      expect(
        () => GroupInvite.fromJson(
          '{"g":"test-group","k":"$validKey","t0":100,"n":42}',
        ),
        throwsFormatException,
      );
    });

    test('throws when n exceeds the max length', () {
      final tooLong = 'x' * (GroupInvite.maxGroupNameLength + 1);
      expect(
        () => GroupInvite.fromJson(
          '{"g":"test-group","k":"$validKey","t0":100,"n":"$tooLong"}',
        ),
        throwsFormatException,
      );
    });

    test('round-trip preserves the group name', () {
      final original = GroupInvite(
        groupId: 'test-group',
        aesKey: validKey,
        t0: 100,
        groupName: 'Volo AZ1234',
      );
      final restored = GroupInvite.fromJson(original.toJson());
      expect(restored.groupId, original.groupId);
      expect(restored.aesKey, original.aesKey);
      expect(restored.t0, original.t0);
      expect(restored.groupName, 'Volo AZ1234');
    });

    test('omits n entirely when there is no group name', () {
      final invite = GroupInvite(groupId: 'g', aesKey: validKey, t0: 100);
      expect(invite.toMap().containsKey('n'), false);
      expect(invite.toJson().contains('"n"'), false);
    });

    test('throws when t0 <= 0', () {
      expect(
        () => GroupInvite.fromJson('{"g":"test-group","k":"$validKey","t0":0}'),
        throwsFormatException,
      );
      expect(
        () => GroupInvite.fromJson('{"g":"test-group","k":"$validKey","t0":-5}'),
        throwsFormatException,
      );
    });
  });
}
