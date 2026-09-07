// lib/core/services/crypto_service.dart — AES-256-GCM encrypt/decrypt del contenuto dei messaggi
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';

/// Formato del blob prodotto: `nonce (12) || ciphertext || tag (16)`.
///
/// Metodi statici e non un Provider, come da vincolo 10 del piano di Fase 2.
abstract class CryptoService {
  static const int nonceLength = 12;
  static const int tagLength = 16;
  static const int _keyLengthBytes = 32;

  /// DECISION: `Random.secure()` e il CSPRNG del sistema operativo. Il piano
  /// indica il `SecureRandom` di pointycastle, che richiede un seeding esplicito
  /// che il piano non specifica: qui non c'e nessun seed da sbagliare.
  static final Random _random = Random.secure();

  static final RegExp _hex64 = RegExp(r'^[0-9a-fA-F]{64}$');

  static Uint8List encrypt(String plaintext, String hexKey) {
    final key = Key(_hexToBytes(hexKey));
    // Nonce nuovo a ogni chiamata: riusarlo con la stessa chiave romperebbe GCM.
    final nonce = Uint8List.fromList(
      List<int>.generate(nonceLength, (_) => _random.nextInt(256)),
    );

    final encrypter = Encrypter(AES(key, mode: AESMode.gcm));
    final encrypted = encrypter.encryptBytes(
      utf8.encode(plaintext),
      iv: IV(nonce),
    );

    return Uint8List.fromList([...nonce, ...encrypted.bytes]);
  }

  static String decrypt(Uint8List data, String hexKey) {
    if (data.length < nonceLength + tagLength) {
      throw FormatException(
        'Ciphertext troppo corto: attesi almeno '
        '${nonceLength + tagLength} byte, ricevuti ${data.length}',
      );
    }

    final nonce = Uint8List.sublistView(data, 0, nonceLength);
    final payload = Uint8List.sublistView(data, nonceLength);

    final encrypter = Encrypter(AES(Key(_hexToBytes(hexKey)), mode: AESMode.gcm));
    // Con una chiave sbagliata o un payload manomesso il tag non torna e
    // pointycastle solleva: l'errore va gestito dal chiamante, non ignorato.
    return utf8.decode(encrypter.decryptBytes(Encrypted(payload), iv: IV(nonce)));
  }

  /// DECISION: conversione diretta hex -> 32 byte, nessun KDF e nessun hash,
  /// come prescrive il piano. `hexKey.toBytes()` che il piano cita non esiste
  /// in Dart, quindi la conversione e scritta qui.
  static Uint8List _hexToBytes(String hexKey) {
    if (!_hex64.hasMatch(hexKey)) {
      throw FormatException(
        'Chiave non valida: attesi 64 caratteri esadecimali, '
        'ricevuti ${hexKey.length}',
      );
    }

    final bytes = Uint8List(_keyLengthBytes);
    for (int i = 0; i < _keyLengthBytes; i++) {
      bytes[i] = int.parse(hexKey.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }
}
