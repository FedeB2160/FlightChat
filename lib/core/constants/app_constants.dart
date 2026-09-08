// lib/core/constants/app_constants.dart — Global mesh network and protocol constants
abstract class AppConstants {
  /// Hop limit del gossip protocol. Consumato dal routing mesh in Fase 5.
  static const int defaultTtl = 3;

  /// Nodi massimi per gruppo. Applicato dal servizio BLE in Fase 3.
  static const int maxGroupSize = 30;

  // --- Budget del pacchetto mesh ----------------------------------------
  //
  // Rispecchia `BleConstants.kt` del modulo Android, che e la sorgente di
  // verita del formato. Se cambiano lassu, vanno cambiati anche qui.

  /// Dimensione massima di un pacchetto BLE, pari all'MTU richiesto.
  static const int blePacketMaxBytes = 512;

  /// Cornice del pacchetto: 41 byte di header piu 4 di CRC32.
  static const int blePacketFrameBytes = 45;

  /// Byte disponibili al payload cifrato: 512 - 45 = 467.
  static const int bleMaxPayloadBytes = blePacketMaxBytes - blePacketFrameBytes;

  /// Overhead di AES-256-GCM: 12 byte di nonce piu 16 di tag.
  static const int gcmOverheadBytes = 28;

  /// Byte UTF-8 di testo che stanno in un pacchetto: 467 - 28 = 439.
  ///
  /// Sono **byte**, non caratteri: un emoji ne occupa quattro. Il limite
  /// dell'input in `message_input.dart` misura i byte proprio per questo.
  /// Oltre questa soglia servirebbe il chunking, che e Fase 5.
  static const int maxMessageBytes = bleMaxPayloadBytes - gcmOverheadBytes;

  // DECISION: rimosso `meshServiceUuid`, che era un segnaposto in attesa della
  // Fase 3. L'UUID del servizio ora vive in `BleConstants.kt`, dove serve
  // davvero: Dart chiama `startMesh` e non ha bisogno di conoscerlo. Due
  // sorgenti di verita per lo stesso UUID sarebbero peggio di nessuna.
}
