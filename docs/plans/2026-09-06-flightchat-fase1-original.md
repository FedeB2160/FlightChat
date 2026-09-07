# FlightChat — Fase 1: Setup Progetto & Interfaccia

> **Obiettivo:** App di messaggistica offline BLE mesh per passeggeri aerei in Modalità Aereo.

## Conferma Architettura Compresa

| Aspetto | Decisione |
|---------|-----------|
| **Framework** | Flutter (Dart) + Method Channels nativi |
| **BLE Engine** | Swift/CoreBluetooth (iOS) + Kotlin/Android BLE API (Android) — NO librerie cross-platform |
| **Database** | SQLite (via `sqflite`) |
| **Crittografia** | AES-256-GCM, chiave nel QR |
| **Target** | Android 12+ (API 31), iOS 16+ |
| **Gruppo** | 10-30 nodi, TTL default = 3 |
| **Tempo** | Mission Time (`t0` + `time_delta`), NO ora locale |
| **Routing** | Gossip Protocol, deduplica per `message_id` |
| **Background** | Android = Foreground Service (Peripheral/Advertiser), iOS = Central aggressivo + State Restoration |
| **File Transfer** | Manifest msg → L2CAP CoC P2P (fallback GATT chunking) |
| **i18n** | Multilingua da subito (`flutter_localizations` + ARB files) |

---

## Design System (da ui-ux-pro-max)

| Token | Valore | Uso |
|-------|--------|-----|
| `primary` | `#2563EB` | Azioni, link, bubble propria |
| `secondary` | `#6366F1` | Accenti, indicatori stato |
| `accent` | `#059669` | Online/connesso, conferma |
| `background` | `#0F172A` | Sfondo principale (dark) |
| `surface` | `#111827` | Card, bubble altri |
| `muted` | `#1E293B` | Input, separatori |
| `foreground` | `#F8FAFC` | Testo primario |
| `muted-fg` | `#CBD5E1` | Testo secondario |
| `border` | `#334155` | Bordi, divider |
| `destructive` | `#DC2626` | Errori, disconnessione |
| Font | **Inter** (300-700) | Variable, premium feel |
| Spacing | 4/8/12/16/24/32dp | Ritmo consistente |
| Radius | 12dp (cards), 20dp (bubbles), 24dp (input) | Morbido ma non eccessivo |
| Animation | 200-300ms, `Curves.easeOutCubic` | Micro-interazioni fluide |

---

## Sistema Identità Utente (Decisioni Confermate)

### Nickname
- **Default auto-generato:** `Passeggero-{N}` (N = ordine di ingresso nel gruppo)
- **Modificabile:** schermata onboarding mostra campo nickname pre-compilato, l'utente può cambiarlo
- Salvato localmente e trasmesso nei messaggi mesh

### Avatar (Sistema Ibrido)
- **Colore:** auto-generato da hash del `deviceId` → indice nella palette di 12 colori distinti
- **Icona:** selezionabile da set predefinito aviation-themed (aereo, pilota, hostess, valigia, nuvola, mappamondo, cuffie, bussola, passaporto, binocolo, ticket, stella)
- **Default:** icona aereo + colore da hash
- Widget `AvatarPickerWidget` con griglia 4x3 di icone selezionabili
- Cerchio colorato con icona bianca come avatar nei bubble e nella lista partecipanti

### Logo
- SVG creato in `assets/logo/flightchat_logo.svg`
- Aereo stilizzato con onde radio BLE e nodi mesh
- Colori del design system: primary (#2563EB), secondary (#6366F1), accent (#059669)

---

## Fase 1 — Modifiche Proposte

### Struttura Progetto Flutter

```
flight_chat/
├── lib/
│   ├── main.dart                          # Entry point, providers setup
│   ├── app.dart                           # MaterialApp, routing, theme
│   ├── l10n/                              # i18n ARB files
│   │   ├── app_en.arb
│   │   └── app_it.arb
│   ├── core/
│   │   ├── theme/
│   │   │   ├── app_colors.dart            # Design tokens colori
│   │   │   ├── app_theme.dart             # ThemeData dark
│   │   │   └── app_typography.dart        # Text styles Inter
│   │   ├── router/
│   │   │   └── app_router.dart            # GoRouter setup
│   │   └── constants/
│   │       └── app_constants.dart         # TTL, MTU, timeouts
│   ├── features/
│   │   ├── onboarding/
│   │   │   ├── presentation/
│   │   │   │   ├── screens/
│   │   │   │   │   ├── welcome_screen.dart     # Scelta: Crea/Unisciti
│   │   │   │   │   ├── create_group_screen.dart # QR generator
│   │   │   │   │   └── join_group_screen.dart   # QR scanner
│   │   │   │   └── widgets/
│   │   │   │       ├── qr_display_widget.dart   # QR code rendering
│   │   │   │       └── qr_scanner_widget.dart   # Camera scanner
│   │   │   └── models/
│   │   │       └── group_invite.dart            # {"g","k","t0"} model
│   │   └── chat/
│   │       ├── presentation/
│   │       │   ├── screens/
│   │       │   │   └── chat_screen.dart         # Chat principale
│   │       │   └── widgets/
│   │       │       ├── message_bubble.dart       # Bubble sent/received
│   │       │       ├── message_input.dart        # Input + send button
│   │       │       ├── mesh_status_bar.dart      # Nodi connessi, stato BLE
│   │       │       └── message_list.dart         # ListView builder
│   │       └── models/
│   │           └── chat_message.dart            # UI model messaggio
│   ├── shared/
│   │   ├── models/
│   │   │   └── user_profile.dart              # Nickname + avatar model
│   │   └── widgets/
│   │       ├── animated_gradient_bg.dart        # Background animato
│   │       ├── glass_card.dart                  # Glassmorphism card
│   │       └── avatar_picker_widget.dart        # Griglia icone selezionabili
│   └── assets/
│       └── logo/
│           └── flightchat_logo.svg             # Logo SVG
├── android/                                # Kotlin BLE (Fase 3)
├── ios/                                    # Swift BLE (Fase 4)
├── pubspec.yaml
└── analysis_options.yaml
```

### Dettaglio Schermate

#### 1. Welcome Screen
- Logo FlightChat da SVG (`assets/logo/flightchat_logo.svg`) con animazione pulsante
- Due bottoni grandi: **"Crea Volo"** / **"Unisciti al Volo"**
- Background: gradiente animato `#0F172A` → `#1E293B` con particelle sottili
- Status BLE in basso (icona + testo "Bluetooth attivo/disattivo")

#### 2. Create Group Screen (Capitano)
- Input nome gruppo opzionale (es. "Volo AZ1234")
- Input nickname (pre-compilato "Capitano", modificabile)
- `AvatarPickerWidget` per scegliere icona (default: pilota)
- Genera UUID v4 + AES-256 key + timestamp → JSON
- Mostra QR code grande, centrato, con animazione fade-in
- Bottone "Continua alla Chat" dopo generazione
- QR code usa colori ad alto contrasto su sfondo dark

#### 3. Join Group Screen (Passeggeri)
- Camera scanner QR full-screen con overlay animato
- Parsing JSON → validazione campi `g`, `k`, `t0`
- Feedback haptico + animazione check su scansione riuscita
- Dopo scan: mostra input nickname (pre-compilato "Passeggero-N") + `AvatarPickerWidget`
- Bottone "Entra nella Chat" → naviga a `/chat/:groupId`

#### 4. Chat Screen
- **AppBar:** Nome gruppo + Mesh Status (icona nodi connessi)
- **Mesh Status Bar:** Barra compatta sotto AppBar con contatore nodi, indicatore forza segnale
- **Message List:** `ListView.builder` reverse, scroll-to-bottom FAB
- **Message Bubbles:**
  - Proprie: allineate a destra, colore `primary` (#2563EB), bordi arrotondati
  - Altrui: allineate a sinistra, colore `surface` (#111827), bordi arrotondati
  - Avatar cerchio (colore auto + icona) a sinistra delle bubble altrui
  - Nickname sopra il testo (solo bubble altrui), colore `secondary`
  - Timestamp = `time_delta` formattato come "T+00:05:23"
  - Stato messaggio: inviato ✓ / ricevuto nella mesh ✓✓
- **Input Bar:** TextField con bordo arrotondato + bottone invio animato

---

## Dipendenze Fase 1

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  go_router: ^15.1.0          # Routing dichiarativo
  provider: ^6.1.0             # State management leggero
  qr_flutter: ^4.1.0           # QR code generation
  mobile_scanner: ^6.0.0       # QR scanning (camera)
  uuid: ^4.5.0                 # UUID v4 generation
  google_fonts: ^6.2.0         # Inter font
  intl: ^0.19.0                # i18n support
  
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
```

> **Nota:** `sqflite` e `pointycastle` (AES-256) verranno aggiunti in Fase 2. BLE modules in Fasi 3-4.

---

## Navigazione (GoRouter)

```
/                  → WelcomeScreen
/create            → CreateGroupScreen
/join              → JoinGroupScreen  
/chat/:groupId     → ChatScreen
```

---

## Verifiche Fase 1

### Automatiche
```bash
flutter analyze
flutter test
```

### Manuali
- Welcome screen rendering corretto su Android 12+ emulator e iOS 16+ simulator
- QR generato contiene JSON valido con campi `g`, `k`, `t0`
- QR scanner legge e parsa correttamente il JSON
- Chat UI mostra messaggi mock con `time_delta` formattato
- i18n switch EN/IT funzionante
- Dark theme applicato correttamente
- Animazioni rispettano `reduceMotion`

---

## Decisioni Confermate

| Domanda | Decisione |
|---------|----------|
| **Nome utente** | Nickname auto-generato ("Passeggero-N" / "Capitano"), modificabile dall'utente |
| **Avatar** | Sistema ibrido: colore auto da hash deviceId + icona selezionabile da set aviation-themed |
| **Logo** | SVG creato → `assets/logo/flightchat_logo.svg` |

---

## Roadmap Completa (5 Fasi)

| Fase | Contenuto | Dipendenze |
|------|-----------|------------|
| **1** (corrente) | Setup progetto + UI (Welcome, QR, Chat) | Nessuna |
| **2** | Motore Crypto AES-256 + SQLite + logica `time_delta` | Fase 1 |
| **3** | Modulo nativo Android (Kotlin BLE Dual Role + Foreground Service) | Fase 2 |
| **4** | Modulo nativo iOS (CoreBluetooth + State Restoration) | Fase 2 |
| **5** | Routing Mesh (Gossip + TTL) + L2CAP file transfer | Fasi 3+4 |
