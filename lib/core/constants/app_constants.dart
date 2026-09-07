// lib/core/constants/app_constants.dart — Global mesh network and protocol constants
abstract class AppConstants {
  /// Hop limit del gossip protocol. Consumato dal routing mesh in Fase 5.
  static const int defaultTtl = 3;

  /// Nodi massimi per gruppo. Applicato dal servizio BLE in Fase 3.
  static const int maxGroupSize = 30;

  /// Byte massimi per payload BLE: limita la lunghezza del messaggio in input.
  static const int bleMtu = 512;

  /// Placeholder: diventa un UUID BLE valido con il modulo nativo di Fase 3.
  static const String meshServiceUuid = "FlightChat";

  /// Chiavi accettate in `GoRouterState.extra` sulla rotta /chat/:groupId.
  static const String extraProfile = "profile";
  static const String extraGroupName = "groupName";
}
