// lib/core/constants/app_constants.dart — Global mesh network and protocol constants
abstract class AppConstants {
  /// Hop limit del gossip protocol. Consumato dal routing mesh in Fase 5.
  static const int defaultTtl = 3;

  /// Nodi massimi per gruppo. Applicato dal servizio BLE in Fase 3.
  static const int maxGroupSize = 30;

  /// Byte massimi per payload BLE: limita la lunghezza del messaggio in input.
  ///
  /// Nota per la Fase 3: questo limite non tiene conto dei 28 byte di
  /// overhead del formato GCM (12 di nonce + 16 di tag) ne dell'header del
  /// pacchetto mesh, che riducono lo spazio utile a circa 439 byte. Il valore
  /// va riconciliato quando il formato del pacchetto sara definito.
  static const int bleMtu = 512;

  /// Placeholder: diventa un UUID BLE valido con il modulo nativo di Fase 3.
  static const String meshServiceUuid = "FlightChat";
}
