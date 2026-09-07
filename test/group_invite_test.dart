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
