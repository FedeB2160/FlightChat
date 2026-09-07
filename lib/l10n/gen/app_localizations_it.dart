// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'FlightChat';

  @override
  String get welcomeSubtitle => 'Messaggia offline. Vola connesso.';

  @override
  String get createFlight => 'Crea Volo';

  @override
  String get joinFlight => 'Unisciti al Volo';

  @override
  String get bluetoothActive => 'Bluetooth Attivo';

  @override
  String get bluetoothInactive => 'Bluetooth Disattivo';

  @override
  String get groupNameHint => 'es. Volo AZ1234';

  @override
  String get nicknameHint => 'Il tuo nickname';

  @override
  String nicknameDefault(int n) {
    return 'Passeggero-$n';
  }

  @override
  String get captainDefault => 'Capitano';

  @override
  String get chooseAvatar => 'Scegli il tuo avatar';

  @override
  String get generateQr => 'Genera QR Code';

  @override
  String get continueToChat => 'Continua alla Chat';

  @override
  String get joinChat => 'Entra nella Chat';

  @override
  String get scanInstruction => 'Inquadra il QR Code del Capitano';

  @override
  String get invalidQr => 'QR Code non valido';

  @override
  String get messageHint => 'Scrivi un messaggio...';

  @override
  String nodesConnected(int count) {
    return '$count nodi connessi';
  }
}
