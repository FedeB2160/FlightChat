import 'dart:convert';
import 'dart:typed_data';

import 'package:flight_chat/core/services/crypto_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_db.dart' show testKey, otherKey;

void main() {
  group('CryptoService', () {
    test('round-trip on ASCII text', () {
      const plaintext = 'Boarding complete, see you at the gate.';
      expect(
        CryptoService.decrypt(CryptoService.encrypt(plaintext, testKey), testKey),
        plaintext,
      );
    });

    test('round-trip on Unicode text', () {
      // Criterio di accettazione del piano: ASCII e Unicode.
      const plaintext = 'Città, perché, così — 🛫 日本語 Ελληνικά';
      expect(
        CryptoService.decrypt(CryptoService.encrypt(plaintext, testKey), testKey),
        plaintext,
      );
    });

    test('round-trip on empty string', () {
      expect(CryptoService.decrypt(CryptoService.encrypt('', testKey), testKey), '');
    });

    test('the same plaintext never produces the same ciphertext', () {
      // Nonce nuovo a ogni chiamata: riusarlo romperebbe GCM.
      const plaintext = 'stesso testo';
      final a = CryptoService.encrypt(plaintext, testKey);
      final b = CryptoService.encrypt(plaintext, testKey);
      expect(a, isNot(equals(b)));
      // Anche i soli 12 byte di nonce devono differire.
      expect(a.sublist(0, 12), isNot(equals(b.sublist(0, 12))));
    });

    test('output is nonce + ciphertext + tag', () {
      const plaintext = 'dodici bytes';
      final bytes = utf8.encode(plaintext).length;
      expect(
        CryptoService.encrypt(plaintext, testKey).length,
        CryptoService.nonceLength + bytes + CryptoService.tagLength,
      );
    });

    test('decrypt with the wrong key fails', () {
      final data = CryptoService.encrypt('segreto', testKey);
      expect(() => CryptoService.decrypt(data, otherKey), throwsA(isA<Object>()));
    });

    test('decrypt rejects a tampered ciphertext', () {
      final data = CryptoService.encrypt('segreto', testKey);
      // Il tag GCM non deve tornare se un byte del payload cambia.
      data[data.length - 1] = data[data.length - 1] ^ 0xFF;
      expect(() => CryptoService.decrypt(data, testKey), throwsA(isA<Object>()));
    });

    test('decrypt rejects data shorter than nonce + tag', () {
      final tooShort = Uint8List(
        CryptoService.nonceLength + CryptoService.tagLength - 1,
      );
      expect(
        () => CryptoService.decrypt(tooShort, testKey),
        throwsFormatException,
      );
    });

    test('rejects a key that is not 64 hex chars', () {
      expect(() => CryptoService.encrypt('x', 'short'), throwsFormatException);
      expect(
        () => CryptoService.encrypt('x', 'z' * 64),
        throwsFormatException,
      );
    });

    test('accepts an uppercase hex key', () {
      final data = CryptoService.encrypt('ciao', testKey.toUpperCase());
      expect(CryptoService.decrypt(data, testKey), 'ciao');
    });
  });
}
