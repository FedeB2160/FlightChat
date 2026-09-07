# FlightChat — Piano Fase 1 (Adattato per Gemini 3.1 Pro · Effort: HIGH)

> **Istruzioni per il modello:** Questo documento è un piano di implementazione autosufficiente. Contiene TUTTO il contesto necessario. NON fare assunzioni al di fuori di ciò che è scritto qui. Segui ogni sezione nell'ordine esatto. Produci codice completo e funzionante per ogni file — nessun placeholder, nessun `// TODO`, nessun `...`. Ogni file deve compilare senza errori. Se trovi ambiguità, scegli l'opzione più robusta e documenta la scelta con un commento `// DECISION:`.

---

## 🎯 Obiettivo

Costruire la **Fase 1** di FlightChat: un'app Flutter di messaggistica offline BLE mesh per passeggeri aerei. Fase 1 copre SOLO: setup progetto, design system, interfaccia grafica (4 schermate), QR code generation/scanning, e dati mock. NON implementare database, crittografia, o BLE in questa fase.

---

## 📐 Architettura (Contesto Completo — Leggi Tutto)

### Stack Tecnologico
- **Framework:** Flutter (Dart) con Method Channels per comunicazione nativa
- **BLE Engine (Fasi future):** Swift/CoreBluetooth (iOS) + Kotlin/Android Bluetooth API — MAI usare flutter_blue, react-native-ble-plx o altre librerie BLE cross-platform
- **Database (Fase 2):** SQLite via `sqflite`
- **Crittografia (Fase 2):** AES-256-GCM
- **Target:** Android 12+ (API 31), iOS 16+
- **Gruppo:** 10-30 nodi, TTL default = 3
- **i18n:** Multilingua da subito (EN + IT)

### Regole d'Oro (Contesto per le scelte UI)
1. **Onboarding via QR Code:** Il "Capitano" crea il gruppo → genera QR con JSON `{"g": "Group_UUID", "k": "AES-256-KEY", "t0": UNIX_TIMESTAMP}`. Altri scansionano per unirsi.
2. **Mission Time:** MAI usare ora locale. Ogni messaggio usa `time_delta` = secondi trascorsi da `t0`. Display format: `T+HH:MM:SS`.
3. **Gossip Protocol:** Ogni telefono è un nodo mesh. Pacchetti non destinati vengono ritrasmessi con TTL-1. Deduplicazione per `message_id`.

---

## 🎨 Design System (OBBLIGATORIO — Usa questi valori esatti)

### Palette Colori (Dark Theme)

```dart
// COPIA ESATTAMENTE in app_colors.dart
static const Color primary = Color(0xFF2563EB);       // Azioni, bubble propria
static const Color onPrimary = Color(0xFFFFFFFF);      // Testo su primary
static const Color secondary = Color(0xFF6366F1);      // Accenti, stato
static const Color accent = Color(0xFF059669);          // Online, conferma, successo
static const Color background = Color(0xFF0F172A);      // Sfondo app
static const Color surface = Color(0xFF111827);          // Card, bubble altrui
static const Color muted = Color(0xFF1E293B);            // Input, separatori
static const Color foreground = Color(0xFFF8FAFC);       // Testo primario
static const Color mutedForeground = Color(0xFFCBD5E1);  // Testo secondario
static const Color border = Color(0xFF334155);            // Bordi, divider
static const Color destructive = Color(0xFFDC2626);       // Errori
static const Color onDestructive = Color(0xFFFFFFFF);     // Testo su errori
```

### Tipografia
- **Font:** Inter (Google Fonts) — pesi 300, 400, 500, 600, 700
- **Import:** `google_fonts: ^6.2.0` — usare `GoogleFonts.inter()`
- **Scale:** headlineLarge=28/700, headlineMedium=22/600, titleMedium=16/600, bodyLarge=16/400, bodyMedium=14/400, bodySmall=12/400, labelSmall=10/500

### Spacing & Radius
- **Spacing grid:** 4, 8, 12, 16, 24, 32dp — MAI usare valori fuori griglia
- **Border radius:** cards=12dp, message bubbles=20dp, input fields=24dp, buttons=12dp
- **Animazioni:** durata 200-300ms, curva `Curves.easeOutCubic`

### Sistema Identità Utente (DECISIONE CONFERMATA — implementa esattamente)

**Nickname:**
- Default auto-generato: `Passeggero-{N}` (N = ordine ingresso gruppo). Il Capitano ha default `Capitano`.
- Campo nickname pre-compilato con default, l'utente lo modifica se vuole.
- Salvato nel `UserProfile` locale e trasmesso come campo dei messaggi mesh.

**Avatar (Sistema Ibrido):**
- **Colore:** auto-generato da hash del `deviceId` → indice in palette di 12 colori distinti:
```dart
// COPIA ESATTAMENTE in user_profile.dart
static const List<Color> avatarPalette = [
  Color(0xFF2563EB), Color(0xFF6366F1), Color(0xFF059669), Color(0xFFDC2626),
  Color(0xFFF59E0B), Color(0xFF8B5CF6), Color(0xFFEC4899), Color(0xFF14B8A6),
  Color(0xFFF97316), Color(0xFF06B6D4), Color(0xFF84CC16), Color(0xFFE11D48),
];
```
- **Icona:** selezionabile da set di 12 icone Material aviation-themed:
  - `Icons.airplanemode_active` (default), `Icons.person`, `Icons.flight_takeoff`, `Icons.luggage`, `Icons.cloud`, `Icons.public`, `Icons.headphones`, `Icons.explore`, `Icons.card_travel`, `Icons.visibility`, `Icons.confirmation_number`, `Icons.star`
- **Rendering:** cerchio colorato (diametro 36dp) con icona bianca centrata (20dp)
- Widget `AvatarPickerWidget`: griglia 4x3 di cerchi selezionabili con bordo `primary` sull'icona selezionata

**Logo:**
- File SVG in `assets/logo/flightchat_logo.svg` (già creato, includilo nel pubspec assets)
- Usalo nella Welcome Screen con `flutter_svg` (aggiungi dipendenza)
- Se `flutter_svg` crea problemi, fallback a Icon Material `Icons.airplanemode_active` grande

---

## 📁 Struttura File (Crea ESATTAMENTE questi file)

```
lib/
├── main.dart
├── app.dart
├── l10n/
│   ├── app_en.arb
│   └── app_it.arb
├── core/
│   ├── theme/
│   │   ├── app_colors.dart
│   │   ├── app_theme.dart
│   │   └── app_typography.dart
│   ├── router/
│   │   └── app_router.dart
│   └── constants/
│       └── app_constants.dart
├── features/
│   ├── onboarding/
│   │   ├── presentation/
│   │   │   ├── screens/
│   │   │   │   ├── welcome_screen.dart
│   │   │   │   ├── create_group_screen.dart
│   │   │   │   └── join_group_screen.dart
│   │   │   └── widgets/
│   │   │       ├── qr_display_widget.dart
│   │   │       └── qr_scanner_widget.dart
│   │   └── models/
│   │       └── group_invite.dart
│   └── chat/
│       ├── presentation/
│       │   ├── screens/
│       │   │   └── chat_screen.dart
│       │   └── widgets/
│       │       ├── message_bubble.dart
│       │       ├── message_input.dart
│       │       ├── mesh_status_bar.dart
│       │       └── message_list.dart
│       └── models/
│           └── chat_message.dart
├── shared/
│   ├── models/
│   │   └── user_profile.dart
│   └── widgets/
│       ├── animated_gradient_bg.dart
│       ├── glass_card.dart
│       └── avatar_picker_widget.dart
└── assets/
    └── logo/
        └── flightchat_logo.svg
```

---

## 📦 Dipendenze (pubspec.yaml)

```yaml
name: flight_chat
description: Offline BLE mesh messaging for airplane passengers
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: ^3.5.0

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  go_router: ^15.1.0
  provider: ^6.1.0
  qr_flutter: ^4.1.0
  mobile_scanner: ^6.0.0
  uuid: ^4.5.0
  google_fonts: ^6.2.0
  intl: ^0.19.0
  flutter_svg: ^2.0.0              # SVG logo rendering

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0

flutter:
  uses-material-design: true
  generate: true
  assets:
    - assets/logo/
```

---

## 📄 Specifica Dettagliata per File

### `main.dart`
- Setup `WidgetsFlutterBinding.ensureInitialized()`
- Wrap app con `MultiProvider` (per ora vuoto, predisposto per Fase 2)
- Lancia `FlightChatApp`

### `app.dart`
- `MaterialApp.router` con GoRouter
- Dark theme UNICO (no light theme)
- Localizzazioni EN + IT
- Font Inter via GoogleFonts come textTheme base

### `core/theme/app_colors.dart`
- Classe astratta `AppColors` con tutti i colori del design system come `static const`
- Usa ESATTAMENTE i valori hex definiti sopra

### `core/theme/app_theme.dart`
- `ThemeData` dark mode
- `scaffoldBackgroundColor: AppColors.background`
- `colorScheme: ColorScheme.dark(...)` mappato ai colori del design system
- `appBarTheme` trasparente con elevation 0
- Input decoration theme con bordi arrotondati (24dp)
- ElevatedButton theme con radius 12dp

### `core/theme/app_typography.dart`
- Classe `AppTypography` con TextStyle statici
- Usa `GoogleFonts.inter()` per ogni stile
- Implementa la scale definita sopra

### `core/router/app_router.dart`
- 4 routes: `/` (welcome), `/create` (crea gruppo), `/join` (unisciti), `/chat/:groupId` (chat)
- Transizioni animate (slide + fade, 300ms)

### `core/constants/app_constants.dart`
- `defaultTtl = 3`
- `maxGroupSize = 30`
- `bleMtu = 512`
- `meshServiceUuid = "FlightChat"` (placeholder per Fase 3)

### `features/onboarding/models/group_invite.dart`
- Classe `GroupInvite` con campi: `groupId` (String), `encryptionKey` (String), `t0` (int, unix timestamp)
- Factory `fromJson(Map<String, dynamic>)` — parsa `{"g": ..., "k": ..., "t0": ...}`
- Metodo `toJson()` — produce il JSON compatto
- Validazione: `groupId` non vuoto, `encryptionKey` lunghezza 64 hex chars, `t0 > 0`

### `features/onboarding/presentation/screens/welcome_screen.dart`
- Background: `AnimatedGradientBg` widget (gradiente animato #0F172A → #1E293B)
- Logo: `SvgPicture.asset('assets/logo/flightchat_logo.svg')`, dimensione 120x120dp, con animazione pulsante (`AnimatedScale` repeat)
- Titolo "FlightChat" con typography headlineLarge
- Sottotitolo i18n `welcomeSubtitle` con mutedForeground
- Due bottoni grandi in GlassCard:
  - Icona `Icons.flight_takeoff` + testo i18n `createFlight` → naviga a `/create`
  - Icona `Icons.qr_code_scanner` + testo i18n `joinFlight` → naviga a `/join`
- Footer: stato BLE (mock: icona `Icons.bluetooth` verde + testo i18n `bluetoothActive`)
- Animazione entrata: stagger dei componenti (opacity + translateY, 100ms delay each)
- NO emoji come icone — usa SOLO Icons Material

### `features/onboarding/presentation/screens/create_group_screen.dart`
- AppBar con back button
- TextField per nome gruppo (opzionale, hint i18n `groupNameHint`)
- TextField nickname (pre-compilato "Capitano", hint i18n `nicknameHint`)
- `AvatarPickerWidget` per selezionare icona (default: `Icons.person`, il pilota)
- Bottone i18n `generateQr`
- Al press: genera UUID v4, genera chiave random 32 bytes (hex string 64 chars), cattura timestamp, crea `UserProfile` locale
- Mostra `QrDisplayWidget` con il JSON encodato
- Bottone i18n `continueToChat` (appare dopo generazione) → naviga a `/chat/:groupId`

### `features/onboarding/presentation/screens/join_group_screen.dart`
- Scanner QR full-screen con `MobileScanner`
- Overlay: cornice rettangolare animata con bordi arrotondati e glow effect
- Testo istruzione i18n `scanInstruction`
- Al scan: parsa JSON, valida, mostra animazione checkmark verde (300ms)
- Dopo scan OK: mostra bottom sheet con:
  - TextField nickname (pre-compilato "Passeggero-N" dove N = ordine)
  - `AvatarPickerWidget` per scegliere icona
  - Bottone i18n `joinChat` → crea `UserProfile`, naviga a `/chat/:groupId`
- Gestione errori: se JSON invalido, mostra snackbar i18n `invalidQr` e continua scanning

### `shared/models/user_profile.dart`
- Classe `UserProfile` con: `deviceId` (String UUID generato al primo avvio), `nickname` (String), `avatarIconIndex` (int, indice nell'array di icone), `avatarColor` (Color, calcolato da hash deviceId)
- `static const List<Color> avatarPalette` — i 12 colori definiti sopra
- `static const List<IconData> avatarIcons` — le 12 icone Material definite sopra
- Factory `UserProfile.create({required String nickname, int iconIndex = 0})` — genera deviceId, calcola colore
- Metodo `Color get color => avatarPalette[deviceId.hashCode.abs() % avatarPalette.length]`
- Metodo `IconData get icon => avatarIcons[avatarIconIndex]`

### `shared/widgets/avatar_picker_widget.dart`
- Input: `selectedIndex` (int), `onSelected` (callback int)
- Griglia 4 colonne × 3 righe di cerchi 44dp
- Ogni cerchio: colore `muted`, icona bianca centrata 20dp
- Cerchio selezionato: bordo 2dp `primary`, scala 1.1 con `AnimatedScale`
- Al tap: chiama `onSelected(index)` con feedback haptico

### `features/chat/models/chat_message.dart`
- Classe `ChatMessage` con: `messageId` (String UUID), `senderId` (String), `senderName` (String), `senderAvatarIconIndex` (int), `senderDeviceId` (String, per calcolo colore avatar), `content` (String), `timeDelta` (int, secondi da t0), `isMine` (bool), `status` (enum: sending/sent/delivered)
- Metodo `formattedTime` → converte `timeDelta` in `T+HH:MM:SS`
- Factory per messaggi mock con avatar diversi

### `features/chat/presentation/screens/chat_screen.dart`
- AppBar: nome gruppo a sinistra, `MeshStatusBar` integrato
- Body: `MessageList` widget
- Bottom: `MessageInput` widget con safe area
- Genera 15-20 messaggi mock con `time_delta` crescenti al build
- Provider/ChangeNotifier per lista messaggi (aggiunta locale per ora)

### `features/chat/presentation/widgets/message_bubble.dart`
- Allineamento: destra (mio) / sinistra (altri)
- Colori: `primary` (mio) / `surface` (altri)
- Border radius: 20dp, con angolo inferiore destro/sinistro piatto (stile WhatsApp)
- **Bubble altrui:** avatar cerchio (36dp, colore da hash deviceId, icona bianca) a sinistra
- **Bubble altrui:** nickname sopra il testo in colore `secondary`, fontSize bodySmall
- **Bubble proprie:** NO avatar, NO nickname
- Contenuto: testo, timestamp `T+HH:MM:SS` in riga sotto a destra
- Icone stato: `Icons.check` (sent) / doppio check (delivered) solo per bubble proprie — NON emoji
- Max width: 75% dello schermo
- Animazione entrata: `AnimatedSlide` + `AnimatedOpacity` su insert

### `features/chat/presentation/widgets/message_input.dart`
- Container con background `muted`, border radius 24dp
- TextField con hint "Scrivi un messaggio..."
- Bottone invio circolare `primary` a destra
- Animazione bottone: scale + rotate su press
- `onSubmit` callback per aggiungere messaggio alla lista

### `features/chat/presentation/widgets/mesh_status_bar.dart`
- Barra compatta (altezza 32dp) sotto AppBar
- Icona mesh + "N nodi connessi" (mock: "4 nodi connessi")
- Indicatore pallino: verde (connesso) / rosso (disconnesso)
- Background: `surface` con opacità 0.8

### `features/chat/presentation/widgets/message_list.dart`
- `ListView.builder` con `reverse: true`
- `ScrollController` per scroll-to-bottom
- FAB circolare piccolo per scroll-to-bottom (appare solo se scrolled up)
- Separatore data: quando il `time_delta` supera 5 minuti tra messaggi, mostra divider "T+HH:MM"

### `shared/widgets/animated_gradient_bg.dart`
- `AnimationController` con `repeat(reverse: true)`, durata 8s
- Gradiente lineare che si sposta lentamente tra `background` e `muted`
- Rispetta `MediaQuery.disableAnimations` per reduced motion

### `shared/widgets/glass_card.dart`
- Container con `BackdropFilter` (blur 10)
- Background `surface` con opacità 0.6
- Border 1px `border` con opacità 0.3
- Border radius 12dp
- Padding 16dp

### `l10n/app_en.arb`
```json
{
  "@@locale": "en",
  "appTitle": "FlightChat",
  "welcomeSubtitle": "Message offline. Fly connected.",
  "createFlight": "Create Flight",
  "joinFlight": "Join Flight",
  "bluetoothActive": "Bluetooth Active",
  "bluetoothInactive": "Bluetooth Inactive",
  "groupNameHint": "e.g. Flight AZ1234",
  "nicknameHint": "Your nickname",
  "nicknameDefault": "Passenger-{n}",
  "@nicknameDefault": { "placeholders": { "n": { "type": "int" } } },
  "captainDefault": "Captain",
  "chooseAvatar": "Choose your avatar",
  "generateQr": "Generate QR Code",
  "continueToChat": "Continue to Chat",
  "joinChat": "Join Chat",
  "scanInstruction": "Frame the Captain's QR Code",
  "invalidQr": "Invalid QR Code",
  "messageHint": "Write a message...",
  "nodesConnected": "{count} nodes connected",
  "@nodesConnected": { "placeholders": { "count": { "type": "int" } } }
}
```

### `l10n/app_it.arb`
```json
{
  "@@locale": "it",
  "appTitle": "FlightChat",
  "welcomeSubtitle": "Messaggia offline. Vola connesso.",
  "createFlight": "Crea Volo",
  "joinFlight": "Unisciti al Volo",
  "bluetoothActive": "Bluetooth Attivo",
  "bluetoothInactive": "Bluetooth Disattivo",
  "groupNameHint": "es. Volo AZ1234",
  "nicknameHint": "Il tuo nickname",
  "nicknameDefault": "Passeggero-{n}",
  "@nicknameDefault": { "placeholders": { "n": { "type": "int" } } },
  "captainDefault": "Capitano",
  "chooseAvatar": "Scegli il tuo avatar",
  "generateQr": "Genera QR Code",
  "continueToChat": "Continua alla Chat",
  "joinChat": "Entra nella Chat",
  "scanInstruction": "Inquadra il QR Code del Capitano",
  "invalidQr": "QR Code non valido",
  "messageHint": "Scrivi un messaggio...",
  "nodesConnected": "{count} nodi connessi",
  "@nodesConnected": { "placeholders": { "count": { "type": "int" } } }
}
```

---

## ✅ Ordine di Implementazione (Segui esattamente)

1. Crea progetto Flutter: `flutter create --org com.flightchat --project-name flight_chat .`
2. Sostituisci `pubspec.yaml` con le dipendenze sopra
3. `flutter pub get`
4. Crea `core/theme/app_colors.dart`
5. Crea `core/theme/app_typography.dart`
6. Crea `core/theme/app_theme.dart`
7. Crea `core/constants/app_constants.dart`
8. Crea i file `l10n/*.arb`
9. Crea `core/router/app_router.dart`
10. Crea `shared/widgets/animated_gradient_bg.dart`
11. Crea `shared/widgets/glass_card.dart`
12. Crea `shared/models/user_profile.dart`
13. Crea `shared/widgets/avatar_picker_widget.dart`
14. Crea `features/onboarding/models/group_invite.dart`
15. Crea `features/chat/models/chat_message.dart`
16. Crea `features/onboarding/presentation/widgets/qr_display_widget.dart`
17. Crea `features/onboarding/presentation/widgets/qr_scanner_widget.dart`
18. Crea `features/onboarding/presentation/screens/welcome_screen.dart`
19. Crea `features/onboarding/presentation/screens/create_group_screen.dart`
20. Crea `features/onboarding/presentation/screens/join_group_screen.dart`
21. Crea `features/chat/presentation/widgets/message_bubble.dart`
22. Crea `features/chat/presentation/widgets/message_input.dart`
23. Crea `features/chat/presentation/widgets/mesh_status_bar.dart`
24. Crea `features/chat/presentation/widgets/message_list.dart`
25. Crea `features/chat/presentation/screens/chat_screen.dart`
26. Crea `app.dart`
27. Aggiorna `main.dart`
28. Copia `assets/logo/flightchat_logo.svg` nella directory assets del progetto
29. Esegui `flutter analyze` — ZERO errori accettati
30. Esegui `flutter test` — tutti i test devono passare

---

## 🔍 Criteri di Accettazione (Verifica ogni punto)

- [ ] `flutter analyze` riporta 0 errori, 0 warning
- [ ] App si avvia senza crash su Android 12+ emulator
- [ ] Welcome screen mostra SVG logo con pulsazione, gradiente animato, 2 bottoni
- [ ] "Crea Volo" → mostra campo nickname pre-compilato "Capitano" + AvatarPicker + genera QR con JSON `g`, `k`, `t0`
- [ ] "Unisciti al Volo" → scanner camera → dopo scan mostra nickname + AvatarPicker → entra in chat
- [ ] Chat screen mostra 15+ messaggi mock con timestamp `T+HH:MM:SS`
- [ ] Bubble altrui mostrano avatar cerchio colorato con icona + nickname sopra il testo
- [ ] Bubble proprie a destra (blu), altrui a sinistra (grigio scuro) con avatar
- [ ] Input bar funziona: scrivi testo → premi invio → messaggio appare nella lista
- [ ] Mesh status bar mostra "N nodi connessi" (mock)
- [ ] Scroll-to-bottom FAB appare quando scrolli verso l'alto
- [ ] Tema dark applicato globalmente, font Inter
- [ ] Stringhe i18n funzionanti (almeno EN)
- [ ] ZERO emoji come icone strutturali — solo Material Icons
- [ ] Nessun `// TODO` nel codice finale
- [ ] Nessun placeholder — tutto il codice è funzionante

---

## ⚠️ Vincoli Espliciti

1. **NON** implementare SQLite, crittografia AES, o moduli BLE — quelli sono Fasi 2-5
2. **NON** usare emoji come icone strutturali (solo vector icons da Material) — MAI ✈ 📡 🔒 come icone UI
3. **NON** usare Tailwind, Bootstrap, o framework CSS — è Flutter, usa Widget
4. **NON** creare file non elencati nella struttura sopra
5. **NON** aggiungere dipendenze non elencate nel pubspec.yaml (eccezione: `flutter_svg` è stato aggiunto)
6. **NON** usare `setState` nei widget screen — usa Provider/ChangeNotifier
7. **RISPETTA** esattamente i valori del design system (colori, spacing, radius)
8. **OGNI** file deve avere un commento header con path e descrizione breve
9. **GENERA** la chiave AES come random hex string (64 chars) — la vera crypto è Fase 2
10. **MOCK** il conteggio nodi mesh (hardcode 4) — il vero BLE è Fasi 3-4
11. **USA** `UserProfile` per nickname e avatar — NO stringhe hardcoded per nomi utente nei mock
12. **IMPLEMENTA** `AvatarPickerWidget` come componente riutilizzabile in `shared/widgets/`

---

## 📋 Roadmap Completa (Contesto — NON implementare)

| Fase | Contenuto | Status |
|------|-----------|--------|
| **1** ← CORRENTE | Setup + UI (Welcome, QR, Chat) | 🔨 Da fare |
| **2** | SQLite + AES-256-GCM + logica `time_delta` | ⏳ Attesa |
| **3** | Android Kotlin BLE (GATT Server + Scanner + Foreground Service) | ⏳ Attesa |
| **4** | iOS Swift CoreBluetooth (State Restoration + Background) | ⏳ Attesa |
| **5** | Gossip Mesh Routing + L2CAP file transfer | ⏳ Attesa |
