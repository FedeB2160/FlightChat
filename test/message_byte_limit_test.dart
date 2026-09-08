import 'dart:convert';

import 'package:flight_chat/core/constants/app_constants.dart';
import 'package:flight_chat/features/chat/presentation/widgets/message_input.dart';
import 'package:flutter_test/flutter_test.dart';

/// Applica il formatter come farebbe il campo di testo.
String limited(String input, {int? maxBytes}) {
  const empty = TextEditingValue.empty;
  final formatter = Utf8ByteLimitingFormatter(
    maxBytes ?? AppConstants.maxMessageBytes,
  );
  return formatter
      .formatEditUpdate(empty, TextEditingValue(text: input))
      .text;
}

void main() {
  group('budget del pacchetto', () {
    test('i numeri derivano dal formato e non sono scritti a mano', () {
      // 512 - 45 = 467 al payload, meno i 28 di GCM = 439 di testo.
      expect(AppConstants.bleMaxPayloadBytes, 467);
      expect(AppConstants.maxMessageBytes, 439);
    });
  });

  group('Utf8ByteLimitingFormatter', () {
    test('lascia passare un testo entro il limite', () {
      const text = 'Ciao dal volo AZ1234';
      expect(limited(text), text);
    });

    test('lascia passare un testo esattamente al limite', () {
      final text = 'a' * AppConstants.maxMessageBytes;
      expect(limited(text), text);
      expect(utf8.encode(limited(text)).length, AppConstants.maxMessageBytes);
    });

    test('taglia un testo ASCII oltre il limite', () {
      final text = 'a' * (AppConstants.maxMessageBytes + 50);
      expect(limited(text).length, AppConstants.maxMessageBytes);
    });

    test('conta byte e non caratteri sugli accenti', () {
      // Ogni lettera accentata occupa 2 byte in UTF-8.
      final text = 'à' * 300; // 300 caratteri, 600 byte
      final result = limited(text);

      expect(utf8.encode(text).length, 600);
      expect(utf8.encode(result).length, lessThanOrEqualTo(439));
      // Se contasse i caratteri, 300 < 439 e passerebbe tutto.
      expect(result.length, lessThan(300));
      expect(result.length, 219); // 219 * 2 = 438 byte, il 220esimo sfonderebbe
    });

    test('conta byte e non caratteri sugli emoji', () {
      // Un emoji come questo occupa 4 byte in UTF-8 e 2 code unit in Dart.
      const emoji = '🛫';
      expect(utf8.encode(emoji).length, 4);

      final text = emoji * 200; // 800 byte
      final result = limited(text);

      expect(utf8.encode(result).length, lessThanOrEqualTo(439));
      // 109 emoji fanno 436 byte; il 110esimo arriverebbe a 440.
      expect(utf8.encode(result).length, 436);
    });

    test('non spezza mai un carattere multibyte a meta', () {
      // Con un limite dispari il taglio non puo cadere dentro un carattere.
      for (final max in [1, 2, 3, 5, 7, 11]) {
        final result = limited('à' * 20, maxBytes: max);
        // Se avesse tagliato a meta byte, il decode fallirebbe o darebbe U+FFFD.
        expect(result.contains('�'), false);
        expect(utf8.encode(result).length, lessThanOrEqualTo(max));
        expect(utf8.decode(utf8.encode(result)), result);
      }
    });

    test('un carattere piu grande del limite produce una stringa vuota', () {
      expect(limited('🛫', maxBytes: 3), '');
    });

    test('il cursore finisce alla fine del testo troncato', () {
      final formatter = Utf8ByteLimitingFormatter(10);
      final result = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(text: 'abcdefghijklmnop'),
      );
      expect(result.text, 'abcdefghij');
      expect(result.selection.baseOffset, 10);
    });

    test('una stringa vuota resta vuota', () {
      expect(limited(''), '');
    });
  });
}
