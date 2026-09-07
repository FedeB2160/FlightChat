// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'FlightChat';

  @override
  String get welcomeSubtitle => 'Message offline. Fly connected.';

  @override
  String get createFlight => 'Create Flight';

  @override
  String get joinFlight => 'Join Flight';

  @override
  String get bluetoothActive => 'Bluetooth Active';

  @override
  String get bluetoothInactive => 'Bluetooth Inactive';

  @override
  String get groupNameHint => 'e.g. Flight AZ1234';

  @override
  String get nicknameHint => 'Your nickname';

  @override
  String nicknameDefault(int n) {
    return 'Passenger-$n';
  }

  @override
  String get captainDefault => 'Captain';

  @override
  String get chooseAvatar => 'Choose your avatar';

  @override
  String get generateQr => 'Generate QR Code';

  @override
  String get continueToChat => 'Continue to Chat';

  @override
  String get joinChat => 'Join Chat';

  @override
  String get scanInstruction => 'Frame the Captain\'s QR Code';

  @override
  String get invalidQr => 'Invalid QR Code';

  @override
  String get messageHint => 'Write a message...';

  @override
  String nodesConnected(int count) {
    return '$count nodes connected';
  }

  @override
  String get sendMessageLabel => 'Send message';

  @override
  String get scrollToBottomLabel => 'Scroll to latest messages';

  @override
  String avatarOptionLabel(int index) {
    return 'Avatar $index';
  }

  @override
  String senderAvatarLabel(String name) {
    return 'Avatar of $name';
  }

  @override
  String get statusSent => 'Sent';

  @override
  String get statusDelivered => 'Delivered in the mesh';

  @override
  String get emptyChatTitle => 'No messages yet';

  @override
  String get undecryptableMessage => 'Message cannot be decrypted';

  @override
  String get groupNotFoundTitle => 'Flight not found';

  @override
  String get groupNotFoundHint =>
      'This flight is not saved on this device. Scan the QR code again to join.';

  @override
  String get sendFailed => 'Message not sent. Try again.';

  @override
  String get saveFailed => 'Could not save. Try again.';

  @override
  String get emptyChatHint =>
      'Messages exchanged on this flight will appear here.';
}
