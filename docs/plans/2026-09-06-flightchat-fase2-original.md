# FlightChat — Fase 2: SQLite + AES-256-GCM + Logica time_delta

> **Obiettivo:** Persistenza locale dei messaggi, crittografia end-to-end del payload, e gestione corretta del Mission Time.

## Prerequisiti
- Fase 1 completata e funzionante
- Nessun modulo BLE — Fase 2 usa ancora dati mock per la rete

---

## Componenti

### 1. Database Locale (SQLite via `sqflite`)

#### Schema
```sql
-- Tabella gruppi
CREATE TABLE groups (
  group_id TEXT PRIMARY KEY,
  group_name TEXT,
  encryption_key TEXT NOT NULL,   -- hex 64 chars
  t0 INTEGER NOT NULL,            -- unix timestamp creazione
  created_at INTEGER NOT NULL,
  role TEXT NOT NULL DEFAULT 'member'  -- 'captain' | 'member'
);

-- Tabella messaggi  
CREATE TABLE messages (
  message_id TEXT PRIMARY KEY,
  group_id TEXT NOT NULL,
  sender_device_id TEXT NOT NULL,
  sender_name TEXT NOT NULL,
  sender_avatar_icon_index INTEGER NOT NULL DEFAULT 0,
  content_encrypted BLOB NOT NULL,   -- AES-256-GCM ciphertext
  time_delta INTEGER NOT NULL,       -- secondi da t0
  status TEXT NOT NULL DEFAULT 'sent', -- 'sending'|'sent'|'delivered'
  is_mine INTEGER NOT NULL DEFAULT 0,
  FOREIGN KEY (group_id) REFERENCES groups(group_id)
);

-- Tabella profili utente (locale + altri nodi visti)
CREATE TABLE user_profiles (
  device_id TEXT PRIMARY KEY,
  nickname TEXT NOT NULL,
  avatar_icon_index INTEGER NOT NULL DEFAULT 0,
  last_seen_delta INTEGER           -- ultimo time_delta visto
);

-- Indici
CREATE INDEX idx_messages_group ON messages(group_id, time_delta);
CREATE INDEX idx_messages_dedup ON messages(message_id);
```

#### Repository Pattern
- `DatabaseService` — singleton, gestisce apertura/migrazione DB
- `GroupRepository` — CRUD gruppi, salva dati QR al join/create
- `MessageRepository` — insert, query per gruppo (paginati), deduplicazione per `message_id`
- `UserProfileRepository` — CRUD profili, query per device_id

### 2. Crittografia AES-256-GCM

#### Libreria: `pointycastle` + `encrypt`
- **Encrypt:** `AES-256-GCM(key, nonce, plaintext)` → `nonce || ciphertext || tag`
- **Decrypt:** split nonce (12 bytes) + ciphertext + tag (16 bytes) → plaintext
- **Key derivation:** La chiave hex dal QR viene convertita in `Uint8List` 32 bytes
- **Nonce:** random 12 bytes per ogni messaggio (GCM standard)
- Classe `CryptoService` con metodi `encrypt(String plaintext, String hexKey)` → `Uint8List` e `decrypt(Uint8List ciphertext, String hexKey)` → `String`

### 3. Logica Mission Time

- `MissionTimeService`:
  - Riceve `t0` dal `GroupInvite`
  - `int currentTimeDelta()` → `(DateTime.now().millisecondsSinceEpoch ~/ 1000) - t0`
  - `String formatDelta(int delta)` → `T+HH:MM:SS`
  - Usato per timestampare ogni messaggio inviato

### 4. Integrazione con UI Esistente

- `ChatNotifier` aggiornato:
  - Legge messaggi da `MessageRepository` invece di mock
  - Inserisce messaggi locali cifrati nel DB
  - Espone stream/lista aggiornata alla UI
- `CreateGroupNotifier`: salva gruppo nel DB dopo generazione QR
- `JoinGroupNotifier`: salva gruppo nel DB dopo scan QR
- `UserProfileRepository`: persiste il profilo locale creato all'onboarding

---

## Nuove Dipendenze

```yaml
  sqflite: ^2.4.0              # SQLite per Flutter
  path: ^1.9.0                 # Path per DB file
  pointycastle: ^3.9.0         # AES-256-GCM primitives
  encrypt: ^5.0.0              # High-level crypto API
```

## Struttura File Nuovi

```
lib/
├── core/
│   └── services/
│       ├── database_service.dart       # Singleton SQLite
│       ├── crypto_service.dart         # AES-256-GCM encrypt/decrypt
│       └── mission_time_service.dart   # t0 + time_delta logic
├── features/
│   ├── chat/
│   │   └── data/
│   │       └── message_repository.dart # CRUD messaggi + dedup
│   └── onboarding/
│       └── data/
│           ├── group_repository.dart   # CRUD gruppi
│           └── user_profile_repository.dart # CRUD profili
```

---

## Vincoli Espliciti Fase 2

1. **NON** implementare BLE — rete mesh è ancora mock
2. **NON** cambiare la struttura UI/widget della Fase 1
3. **OGNI** messaggio salvato deve essere cifrato con AES-256-GCM
4. **DEDUPLICAZIONE** per `message_id` nel DB (idempotent insert)
5. **MIGRATION:** Schema versioning per upgrade futuri
6. **TEST:** Unit test per `CryptoService` (encrypt → decrypt round-trip), `MissionTimeService`, e repository

---

## Verifiche

### Automatiche
```bash
flutter analyze
flutter test
```

### Manuali
- Crea gruppo → chiudi app → riapri → gruppo persiste
- Invia messaggio → verifica record cifrato nel DB (non leggibile in chiaro)
- Decrypt round-trip: `decrypt(encrypt(msg)) == msg`
- `time_delta` calcolato correttamente rispetto a `t0`

---

## Roadmap

| Fase | Contenuto | Status |
|------|-----------|--------|
| **1** | Setup + UI | ✅ Completata |
| **2** ← CORRENTE | SQLite + AES-256-GCM + time_delta | 🔨 Da fare |
| **3** | Android Kotlin BLE | ⏳ Attesa |
| **4** | iOS Swift CoreBluetooth | ⏳ Attesa |
| **5** | Gossip Mesh + L2CAP | ⏳ Attesa |
