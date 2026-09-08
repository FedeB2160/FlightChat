> **Non seguito.** Per le Fasi 3-5 si segue solo il piano `-original` corrispondente,
> su decisione dell'utente. Questo documento resta nel repository per tracciabilita:
> i corpi delle PR #1 e #3 lo citano per numero di riga come motivazione di diversi
> commenti `// DECISION:` nel codice, e spostarlo o eliminarlo renderebbe quei
> riferimenti irraggiungibili.

# FlightChat — Piano Fase 2 (Adattato per Gemini 3.1 Pro · Effort: HIGH)

> **Istruzioni per il modello:** Questo documento è un piano di implementazione autosufficiente. Contiene TUTTO il contesto necessario. NON fare assunzioni al di fuori di ciò che è scritto qui. Segui ogni sezione nell'ordine esatto. Produci codice completo e funzionante per ogni file — nessun placeholder, nessun `// TODO`, nessun `...`. Ogni file deve compilare senza errori. Se trovi ambiguità, scegli l'opzione più robusta e documenta la scelta con un commento `// DECISION:`.

---

## 🎯 Obiettivo

Implementare la **Fase 2** di FlightChat: persistenza locale via SQLite, crittografia AES-256-GCM per i payload dei messaggi, e logica Mission Time (`t0` + `time_delta`). La rete mesh è ancora mock — NON implementare BLE. L'UI Fase 1 rimane invariata, si cambia solo il backend dati.

---

## 📐 Contesto (da Fase 1)

### Cosa esiste già
- App Flutter funzionante con 4 schermate (Welcome, Create, Join, Chat)
- Design system completo (AppColors, AppTheme, AppTypography)
- Modelli: `GroupInvite`, `ChatMessage`, `UserProfile`
- Notifiers: `ChatNotifier`, `CreateGroupNotifier`, `JoinGroupNotifier`
- Router GoRouter con Provider per route
- `MultiProvider` nel `main.dart` (vuoto, predisposto)
- 13 test passing, 0 analyze issues

### Cosa va modificato
- `ChatNotifier` → legge/scrive messaggi dal DB cifrati, non più mock hardcoded
- `CreateGroupNotifier` → salva gruppo nel DB
- `JoinGroupNotifier` → salva gruppo nel DB
- `main.dart` → inizializza `DatabaseService` prima di `runApp`
- `pubspec.yaml` → nuove dipendenze

---

## 📦 Dipendenze (da aggiungere a pubspec.yaml)

```yaml
  sqflite: ^2.4.0              # SQLite per Flutter
  path: ^1.9.0                 # Path utils per DB file location
  pointycastle: ^3.9.0         # AES-256-GCM crypto primitives
  encrypt: ^5.0.0              # High-level encrypt/decrypt API
```

---

## 📁 Struttura File Nuovi (Crea ESATTAMENTE questi file)

```
lib/
├── core/
│   └── services/
│       ├── database_service.dart       # Singleton SQLite, schema, migrations
│       ├── crypto_service.dart         # AES-256-GCM encrypt/decrypt
│       └── mission_time_service.dart   # t0-based time_delta calculation
├── features/
│   ├── chat/
│   │   └── data/
│   │       └── message_repository.dart # CRUD messaggi + dedup
│   └── onboarding/
│       └── data/
│           ├── group_repository.dart   # CRUD gruppi
│           └── user_profile_repository.dart # CRUD profili utente
```

### File da MODIFICARE (NON ricreare)
- `lib/main.dart` — inizializzazione DB
- `lib/core/router/app_router.dart` — passare repositories ai notifiers
- `lib/features/chat/presentation/notifiers/chat_notifier.dart` — leggere da DB
- `lib/features/onboarding/presentation/notifiers/create_group_notifier.dart` — salvare su DB
- `lib/features/onboarding/presentation/notifiers/join_group_notifier.dart` — salvare su DB
- `pubspec.yaml` — aggiungere dipendenze

---

## 📄 Specifica Dettagliata per File

### `core/services/database_service.dart`

```dart
// COPIA ESATTAMENTE questo schema SQL
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._();
  factory DatabaseService() => _instance;
  DatabaseService._();
  
  Database? _db;
  
  Future<Database> get database async {
    _db ??= await _initDb();
    return _db!;
  }
  
  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'flightchat.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
    );
  }
  
  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE groups (
        group_id TEXT PRIMARY KEY,
        group_name TEXT,
        encryption_key TEXT NOT NULL,
        t0 INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        role TEXT NOT NULL DEFAULT 'member'
      )
    ''');
    
    await db.execute('''
      CREATE TABLE messages (
        message_id TEXT PRIMARY KEY,
        group_id TEXT NOT NULL,
        sender_device_id TEXT NOT NULL,
        sender_name TEXT NOT NULL,
        sender_avatar_icon_index INTEGER NOT NULL DEFAULT 0,
        content_encrypted BLOB NOT NULL,
        time_delta INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'sent',
        is_mine INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (group_id) REFERENCES groups(group_id)
      )
    ''');
    
    await db.execute('''
      CREATE TABLE user_profiles (
        device_id TEXT PRIMARY KEY,
        nickname TEXT NOT NULL,
        avatar_icon_index INTEGER NOT NULL DEFAULT 0,
        last_seen_delta INTEGER
      )
    ''');
    
    await db.execute('CREATE INDEX idx_messages_group ON messages(group_id, time_delta)');
    await db.execute('CREATE INDEX idx_messages_dedup ON messages(message_id)');
  }
}
```

### `core/services/crypto_service.dart`

- Classe `CryptoService` con metodi statici
- `static Uint8List encrypt(String plaintext, String hexKey)`:
  1. Converti `hexKey` (64 chars) in `Uint8List` 32 bytes
  2. Genera nonce random 12 bytes (`SecureRandom`)
  3. Cifra con AES-256-GCM → ottieni ciphertext + auth tag (16 bytes)
  4. Ritorna `nonce (12) || ciphertext || tag (16)` come `Uint8List`
- `static String decrypt(Uint8List data, String hexKey)`:
  1. Split: nonce = data[0:12], ciphertext+tag = data[12:]
  2. Decifra con AES-256-GCM
  3. Ritorna plaintext UTF-8

### `core/services/mission_time_service.dart`

- Classe `MissionTimeService`
- Constructor: `MissionTimeService({required int t0})`
- `int currentTimeDelta()` → `(DateTime.now().millisecondsSinceEpoch ~/ 1000) - t0`
- `static String formatDelta(int delta)` → `T+HH:MM:SS` (riusa logica di `ChatMessage.formattedTime`)
- Validazione: se `delta < 0`, ritorna `T+00:00:00`

### `features/chat/data/message_repository.dart`

- `MessageRepository({required DatabaseService db, required CryptoService crypto})`
- `Future<void> insertMessage(ChatMessage msg, String groupId, String hexKey)`:
  1. Cifra `msg.content` con `crypto.encrypt(content, hexKey)`
  2. Insert in DB (ON CONFLICT IGNORE per dedup)
- `Future<List<ChatMessage>> getMessages(String groupId, String hexKey, {int limit = 50, int offset = 0})`:
  1. Query ordinata per `time_delta ASC`
  2. Decifra ogni `content_encrypted` con `crypto.decrypt`
  3. Ritorna lista `ChatMessage`
- `Future<bool> messageExists(String messageId)` — per deduplicazione gossip

### `features/onboarding/data/group_repository.dart`

- `GroupRepository({required DatabaseService db})`
- `Future<void> saveGroup(GroupInvite invite, String role, {String? groupName})`
- `Future<GroupInvite?> getGroup(String groupId)`
- `Future<List<GroupInvite>> getAllGroups()`
- `Future<String?> getEncryptionKey(String groupId)` — per decryptare messaggi

### `features/onboarding/data/user_profile_repository.dart`

- `UserProfileRepository({required DatabaseService db})`
- `Future<void> saveProfile(UserProfile profile)`
- `Future<UserProfile?> getProfile(String deviceId)`
- `Future<UserProfile?> getLocalProfile()` — query per profilo con deviceId locale
- `Future<void> updateLastSeen(String deviceId, int timeDelta)`

---

## 🔧 Modifiche ai File Esistenti

### `main.dart`
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = DatabaseService();
  await db.database; // Ensure DB is created
  
  runApp(
    MultiProvider(
      providers: [
        Provider<DatabaseService>.value(value: db),
        Provider<GroupRepository>(create: (_) => GroupRepository(db: db)),
        Provider<MessageRepository>(create: (_) => MessageRepository(db: db)),
        Provider<UserProfileRepository>(create: (_) => UserProfileRepository(db: db)),
      ],
      child: const FlightChatApp(),
    ),
  );
}
```

### `app_router.dart`
- Route `/create`: `CreateGroupNotifier` riceve `GroupRepository` e `UserProfileRepository` dal context
- Route `/join`: `JoinGroupNotifier` riceve `GroupRepository` e `UserProfileRepository` dal context
- Route `/chat/:groupId`: `ChatNotifier` riceve `MessageRepository`, `GroupRepository`, legge `encryptionKey` dal DB

### `ChatNotifier` (modificare, non ricreare)
- Constructor: `ChatNotifier({required groupId, required MessageRepository messageRepo, required GroupRepository groupRepo, UserProfile? localProfile})`
- `_loadMessages()` — carica da DB (decripta), NOT mock
- `sendMessage(String text)` — cifra, salva in DB, notifica
- Mantieni `_loadMockMessages()` come fallback se il gruppo non esiste nel DB (prima volta)

### `CreateGroupNotifier` (modificare)
- Dopo `generateQr()`: salva gruppo in `GroupRepository` con ruolo `'captain'`
- Salva `UserProfile` locale in `UserProfileRepository`

### `JoinGroupNotifier` (modificare)
- Dopo `processScan()` + `createProfile()`: salva gruppo in `GroupRepository` con ruolo `'member'`
- Salva `UserProfile` locale in `UserProfileRepository`

---

## ✅ Ordine di Implementazione (Segui esattamente)

1. Aggiungi dipendenze a `pubspec.yaml`
2. `flutter pub get`
3. Crea `core/services/database_service.dart`
4. Crea `core/services/crypto_service.dart`
5. Crea `core/services/mission_time_service.dart`
6. Crea `features/onboarding/data/group_repository.dart`
7. Crea `features/onboarding/data/user_profile_repository.dart`
8. Crea `features/chat/data/message_repository.dart`
9. Modifica `main.dart` — init DB + providers
10. Modifica `app_router.dart` — passa repositories ai notifiers
11. Modifica `CreateGroupNotifier` — salva su DB
12. Modifica `JoinGroupNotifier` — salva su DB
13. Modifica `ChatNotifier` — leggi/scrivi da DB con crypto
14. Crea unit test per `CryptoService` (encrypt/decrypt round-trip)
15. Crea unit test per `MissionTimeService`
16. Crea unit test per repositories (usando in-memory SQLite)
17. `flutter analyze` — ZERO errori accettati
18. `flutter test` — tutti i test devono passare

---

## 🔍 Criteri di Accettazione

- [ ] `flutter analyze` → 0 errori, 0 warning
- [ ] `flutter test` → tutti i test passano
- [ ] Messaggio inviato → salvato cifrato nel DB → riapri app → messaggio decifrato e visibile
- [ ] `encrypt(plaintext) → decrypt() == plaintext` per stringhe ASCII e Unicode
- [ ] Deduplicazione: inserire due volte lo stesso `message_id` → nessun duplicato
- [ ] `time_delta` calcolato = `now - t0` in secondi, formato `T+HH:MM:SS`
- [ ] Gruppo creato/joinato persiste alla chiusura app
- [ ] Profilo utente locale persiste alla chiusura app

---

## ⚠️ Vincoli Espliciti

1. **NON** implementare BLE, networking, o discovery — quelli sono Fasi 3-5
2. **NON** cambiare la struttura UI/widget della Fase 1 (schermate, colori, layout)
3. **NON** aggiungere dipendenze non elencate sopra
4. **NON** usare `setState` nei widget screen — mantieni Provider/ChangeNotifier
5. **OGNI** file deve avere un commento header con path e descrizione breve
6. **OGNI** messaggio nel DB deve essere cifrato — MAI salvare plaintext
7. **DEDUPLICAZIONE** per `message_id` con `ON CONFLICT IGNORE`
8. **NONCE** random 12 bytes per ogni encrypt — MAI riusare nonce
9. **GENERA** la chiave AES come `Uint8List.fromList(hexKey.toBytes())` — non hash, conversione diretta
10. **USA** `CryptoService` come classe con metodi statici — non come Provider

---

## 📋 Roadmap

| Fase | Contenuto | Status |
|------|-----------|--------|
| **1** | Setup + UI | ✅ Completata |
| **2** ← CORRENTE | SQLite + AES-256-GCM + time_delta | 🔨 Da fare |
| **3** | Android Kotlin BLE (GATT Server + Scanner + Foreground Service) | ⏳ Attesa |
| **4** | iOS Swift CoreBluetooth (State Restoration + Background) | ⏳ Attesa |
| **5** | Gossip Mesh Routing + L2CAP file transfer | ⏳ Attesa |
