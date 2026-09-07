import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('it')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'FlightChat'**
  String get appTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Message offline. Fly connected.'**
  String get welcomeSubtitle;

  /// No description provided for @createFlight.
  ///
  /// In en, this message translates to:
  /// **'Create Flight'**
  String get createFlight;

  /// No description provided for @joinFlight.
  ///
  /// In en, this message translates to:
  /// **'Join Flight'**
  String get joinFlight;

  /// No description provided for @bluetoothActive.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth Active'**
  String get bluetoothActive;

  /// No description provided for @bluetoothInactive.
  ///
  /// In en, this message translates to:
  /// **'Bluetooth Inactive'**
  String get bluetoothInactive;

  /// No description provided for @groupNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Flight AZ1234'**
  String get groupNameHint;

  /// No description provided for @nicknameHint.
  ///
  /// In en, this message translates to:
  /// **'Your nickname'**
  String get nicknameHint;

  /// No description provided for @nicknameDefault.
  ///
  /// In en, this message translates to:
  /// **'Passenger-{n}'**
  String nicknameDefault(int n);

  /// No description provided for @captainDefault.
  ///
  /// In en, this message translates to:
  /// **'Captain'**
  String get captainDefault;

  /// No description provided for @chooseAvatar.
  ///
  /// In en, this message translates to:
  /// **'Choose your avatar'**
  String get chooseAvatar;

  /// No description provided for @generateQr.
  ///
  /// In en, this message translates to:
  /// **'Generate QR Code'**
  String get generateQr;

  /// No description provided for @continueToChat.
  ///
  /// In en, this message translates to:
  /// **'Continue to Chat'**
  String get continueToChat;

  /// No description provided for @joinChat.
  ///
  /// In en, this message translates to:
  /// **'Join Chat'**
  String get joinChat;

  /// No description provided for @scanInstruction.
  ///
  /// In en, this message translates to:
  /// **'Frame the Captain\'s QR Code'**
  String get scanInstruction;

  /// No description provided for @invalidQr.
  ///
  /// In en, this message translates to:
  /// **'Invalid QR Code'**
  String get invalidQr;

  /// No description provided for @messageHint.
  ///
  /// In en, this message translates to:
  /// **'Write a message...'**
  String get messageHint;

  /// No description provided for @nodesConnected.
  ///
  /// In en, this message translates to:
  /// **'{count} nodes connected'**
  String nodesConnected(int count);

  /// No description provided for @sendMessageLabel.
  ///
  /// In en, this message translates to:
  /// **'Send message'**
  String get sendMessageLabel;

  /// No description provided for @scrollToBottomLabel.
  ///
  /// In en, this message translates to:
  /// **'Scroll to latest messages'**
  String get scrollToBottomLabel;

  /// No description provided for @avatarOptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Avatar {index}'**
  String avatarOptionLabel(int index);

  /// No description provided for @senderAvatarLabel.
  ///
  /// In en, this message translates to:
  /// **'Avatar of {name}'**
  String senderAvatarLabel(String name);

  /// No description provided for @statusSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get statusSent;

  /// No description provided for @statusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered in the mesh'**
  String get statusDelivered;

  /// No description provided for @emptyChatTitle.
  ///
  /// In en, this message translates to:
  /// **'No messages yet'**
  String get emptyChatTitle;

  /// No description provided for @emptyChatHint.
  ///
  /// In en, this message translates to:
  /// **'Messages exchanged on this flight will appear here.'**
  String get emptyChatHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
