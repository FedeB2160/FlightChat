# FlightChat

Messaggistica offline per passeggeri in volo. Nessun server, nessuna rete dati: i telefoni
formano una mesh Bluetooth Low Energy in cui ogni dispositivo è al tempo stesso nodo,
mittente e ripetitore. Funziona in Modalità Aereo con il Bluetooth attivo.

## Come funziona

**Onboarding senza accoppiamento.** Il "Capitano" crea il gruppo e l'app genera un QR code
contenente `{"g": "<uuid gruppo>", "k": "<chiave AES-256>", "t0": <unix timestamp>}`. Gli altri
passeggeri lo scansionano per unirsi. Nessuna schermata di pairing, nessun account.

**Tempo di missione.** L'ora locale dei dispositivi non è affidabile né allineata, quindi non
viene usata. Dal QR si estrae il tempo zero `t0`; ogni messaggio memorizza solo il proprio
`time_delta`, i secondi trascorsi da `t0`. La chat è ordinata per `time_delta`, poi per
`message_id`, e i timestamp si mostrano come `T+HH:MM:SS`.

**Routing gossip.** Un pacchetto ricevuto e non destinato al nodo corrente viene ritrasmesso
con il TTL decrementato di 1. La deduplicazione avviene per `message_id`, così un pacchetto
già visto viene ignorato invece di rimbalzare nella mesh.

**Background asimmetrico.** Android tiene un foreground service e fa da peripheral aggressivo,
annunciando il `Group_UUID`. iOS nasconde l'advertising in background, quindi fa da central
aggressivo cercando quello stesso UUID, con la State Restoration di CoreBluetooth per essere
rianimato dopo un kill di sistema.

**File via manifest.** Foto e audio non viaggiano nella mesh. Un normale messaggio di testo
dichiara la presenza del file; alla richiesta di download il modulo nativo apre un canale
L2CAP CoC verso il dispositivo che lo possiede, con fallback al chunking GATT dove L2CAP non
è disponibile.

## Stack

| Livello | Scelta |
|---|---|
| UI e logica applicativa | Flutter (Dart), Provider / ChangeNotifier, GoRouter |
| Database locale | SQLite via `sqflite` (Fase 2) |
| Crittografia | AES-256-GCM, chiave trasportata dal QR (Fase 2) |
| Motore BLE | Moduli nativi: Kotlin con le Bluetooth API (Fase 3), Swift con CoreBluetooth (Fase 4) |
| Ponte UI ↔ nativo | Method Channel `com.flightchat/ble` |

Il motore mesh **non** usa librerie BLE cross-platform (`flutter_blue`, `flutter_blue_plus`,
`flutter_reactive_ble` e simili): non gestiscono in modo affidabile il Dual Role in background
sulle due piattaforme. Il vincolo è verificabile: nessuna di queste compare in `pubspec.lock`.

Target: Android 12+ (API 31), iOS 16+. Gruppi da 10 a 30 nodi, TTL di default 3.

## Stato

| Fase | Contenuto | Stato |
|---|---|---|
| 1 | Setup progetto, design system, 4 schermate, QR generation e scanning, dati mock | Completata |
| 2 | SQLite, AES-256-GCM, tabella messaggi e logica `time_delta` | Da fare |
| 3 | Modulo nativo Android: BLE Dual Role, foreground service, bridge | Da fare |
| 4 | Modulo nativo iOS: CoreBluetooth manager, State Restoration, bridge | Da fare |
| 5 | Routing mesh (gossip, TTL) e canali L2CAP per i file | Da fare |

I piani di dettaglio delle cinque fasi sono in [`docs/plans/`](docs/plans/), lo stato di
avanzamento in [`docs/plans/task.md`](docs/plans/task.md).

Quello che la Fase 1 **non** contiene ancora, per scelta di piano: nessun database, nessun
cifrario, nessun codice BLE. La chat mostra messaggi mock e il contatore dei nodi mesh è fisso
a 4 finché non esiste un modulo nativo che lo alimenti.

## Requisiti

- Flutter stabile ≥ 3.38.4 con Dart ≥ 3.11 (verifica con `flutter --version`)
- Android SDK con API 31 o superiore, oppure Xcode 15+ per iOS

## Setup

```bash
flutter pub get
```

```bash
flutter run
```

Se `flutter` non è nel `PATH`, invocalo dal percorso completo dell'SDK, per esempio
`C:\src\flutter\bin\flutter.bat pub get` su Windows.

Le localizzazioni sono generate da `flutter pub get` grazie a `generate: true` nel
`pubspec.yaml`. Per rigenerarle da sole, dopo aver modificato i file `.arb`:

```bash
flutter gen-l10n
```

L'output finisce in `lib/l10n/gen/` come da `l10n.yaml`, ed è versionato.

## Verifica

```bash
flutter analyze
```

```bash
flutter test
```

La definition of done del progetto richiede `analyze` con zero errori e zero warning e tutti i
test verdi.

### Nota su Windows

Se `flutter pub get` termina con `Building with plugins requires symlink support`, la causa è
la creazione dei symlink per i plugin dei target desktop. Questo repository include soltanto
`android/` e `ios/`, quindi il problema non dovrebbe presentarsi. Se compare comunque, abilita
la Modalità sviluppatore da `ms-settings:developers`.

## Struttura

```
lib/
├── main.dart                    # Entry point, setup dei provider
├── app.dart                     # MaterialApp.router, tema, localizzazioni
├── l10n/                        # File .arb (en, it) e generati in gen/
├── core/
│   ├── theme/                   # Token colore, tipografia, ThemeData
│   ├── router/                  # Configurazione GoRouter
│   └── constants/               # TTL, MTU, chiavi di navigazione
├── features/
│   ├── onboarding/              # Welcome, creazione gruppo, scanner QR
│   └── chat/                    # Lista messaggi, bolle, input, stato mesh
└── shared/                      # Modelli e widget riusabili
```

Le quattro rotte sono `/`, `/create`, `/join` e `/chat/:groupId`. Il tema è unicamente dark.
