# FlightChat — Fase 5: Gossip Mesh Routing + L2CAP File Transfer

> **Obiettivo:** Trasformare la rete BLE 1-hop (Fasi 3-4) in una vera mesh multi-hop con Gossip Protocol, TTL-based flooding, deduplicazione, e trasferimento file via L2CAP CoC.

## Prerequisiti
- Fasi 1-4 completate: UI, SQLite, AES, Android BLE, iOS BLE tutti funzionanti
- Interoperabilità cross-platform iOS↔Android verificata
- Connessioni BLE dirette (1-hop) stabili

---

## Architettura Mesh

### Gossip Protocol — Come funziona

```
Nodo A invia messaggio M1:
  1. A crea MeshPacket con TTL=3, message_id=UUID
  2. A invia M1 a tutti i suoi vicini diretti (1-hop): B, C
  3. B riceve M1:
     - Controlla dedup_cache: M1 è nuovo → processa
     - Salva message_id in dedup_cache
     - Se TTL > 1: crea copia con TTL-1 → ritrasmette a D, E (ma NON a A)
  4. C riceve M1: stessa logica
  5. D riceve M1 da B con TTL=1:
     - Processa messaggio
     - TTL=1 → NON ritrasmette
  6. Se D riceve M1 anche da C: dedup_cache lo blocca → scarto silenzioso
```

```
  A ──── B ──── D
  │      │
  └──── C ──── E
  
  TTL=3: M1 raggiunge tutti i nodi fino a 3 hop di distanza
  Dedup: nessun messaggio viene processato due volte
```

### Componenti del Routing Layer

1. **MeshRouter** — logica di routing
2. **DeduplicationCache** — cache LRU per message_id visti
3. **PacketQueue** — coda prioritizzata per invio
4. **L2CAPManager** — transfer file grandi via L2CAP CoC

---

## Componenti

### 1. `MeshRouter`

Logica centrale di routing gossip. Platform-independent dove possibile.

#### Algoritmo di ricezione pacchetto
```
onPacketReceived(packet, fromNode):
  1. if dedup.has(packet.messageId) → return (già visto)
  2. dedup.add(packet.messageId)
  3. if packet.type == MESSAGE:
     a. Decifra payload con AES-256-GCM
     b. Salva in SQLite (MessageRepository)
     c. Notifica UI (ChatNotifier)
  4. if packet.type == ACK:
     a. Aggiorna status messaggio originale → "delivered"
     b. Notifica UI
  5. if packet.type == PRESENCE:
     a. Aggiorna lista nodi conosciuti (non solo connessi diretti)
  6. if packet.ttl > 1:
     a. Crea copia con ttl = packet.ttl - 1
     b. Enqueue per ritrasmissione a tutti i vicini TRANNE fromNode
```

#### Algoritmo di invio messaggio locale
```
sendMessage(content, groupId):
  1. Cifra content con AES-256-GCM
  2. Crea MeshPacket: type=MESSAGE, ttl=DEFAULT_TTL (3), timeDelta da MissionTime
  3. Salva in SQLite con status "sending"
  4. dedup.add(packet.messageId) — previeni eco
  5. Enqueue per invio a tutti i vicini
  6. Al primo ACK ricevuto → status "sent"
  7. Dopo N ACK (soglia configurabile) → status "delivered"
```

### 2. `DeduplicationCache`

- **Struttura:** LRU cache con dimensione massima 10.000 message_id
- **TTL interno:** Ogni entry scade dopo 5 minuti (per voli lunghi, non troppo aggressivo)
- **Implementazione:**
  - Kotlin: `LinkedHashMap` con `removeEldestEntry`
  - Swift: `NSCache` o `Dictionary` con cleanup timer
  - Dart: `LinkedHashMap` (per test)
- **Thread safety:** accesso sincronizzato (lock o dispatch queue)

### 3. `PacketQueue`

- Coda prioritizzata per pacchetti in uscita
- **Priorità:** ACK > MESSAGE > PRESENCE
- **Rate limiting:** max 20 pacchetti/secondo per evitare flooding
- **Retry:** se invio a un nodo fallisce, re-enqueue con backoff
- **Batch:** se più pacchetti in coda, invia in sequenza rispettando MTU

### 4. `L2CAPManager` — File Transfer (Manifest → Stream)

Per payload > MTU (immagini, file), L2CAP CoC permette un canale stream-oriented:

#### Protocollo Manifest
```
Step 1: Sender invia MANIFEST via GATT (nel payload MeshPacket):
  {
    "type": "file_manifest",
    "file_id": "UUID",
    "file_name": "photo.jpg",
    "file_size": 245760,       // bytes
    "chunk_count": 120,
    "mime_type": "image/jpeg",
    "checksum_sha256": "abc..."
  }

Step 2: Receiver riceve manifest → apre canale L2CAP:
  - iOS: CBL2CAPChannel via peripheral.openL2CAPChannel(PSM)
  - Android: BluetoothSocket via createL2capChannel(PSM)

Step 3: Sender trasmette file in streaming sul canale L2CAP
  - Header per chunk: [chunk_index:4][chunk_size:2][data:N]
  - Flow control: aspetta ACK ogni 10 chunks

Step 4: Receiver verifica checksum SHA-256 → invia ACK finale
```

#### Fallback GATT Chunking
Se L2CAP non disponibile (vecchi firmware, incompatibilità):
- Split file in chunk da 400 bytes (MTU - header)
- Ogni chunk come `MeshPacket` separato con `file_id` + `chunk_index`
- Receiver riassembla in ordine
- Molto più lento ma universalmente compatibile

---

## Struttura File

### Kotlin (Android)
```
android/app/src/main/kotlin/com/flightchat/flight_chat/
├── mesh/
│   ├── MeshRouter.kt              # Logica gossip routing
│   ├── DeduplicationCache.kt      # LRU cache message_id
│   └── PacketQueue.kt             # Coda prioritizzata invio
├── l2cap/
│   └── L2CAPManager.kt            # L2CAP CoC file transfer
```

### Swift (iOS)
```
ios/Runner/
├── Mesh/
│   ├── MeshRouter.swift            # Logica gossip routing
│   ├── DeduplicationCache.swift    # LRU cache message_id
│   └── PacketQueue.swift           # Coda prioritizzata invio
├── L2CAP/
│   └── L2CAPManager.swift          # L2CAP CoC file transfer
```

### Dart (Flutter)
```
lib/
├── core/
│   └── services/
│       └── mesh_service.dart       # Orchestratore Dart-side mesh
├── features/
│   └── chat/
│       ├── presentation/
│       │   └── widgets/
│       │       └── file_transfer_indicator.dart  # Progress UI
│       └── models/
│           └── file_manifest.dart   # Modello manifest file
```

---

## Vincoli Espliciti Fase 5

1. **TTL default = 3** — configurabile ma mai > 10 (previeni storm)
2. **Dedup cache** max 10.000 entries con TTL 5 minuti
3. **Rate limit** max 20 pacchetti/secondo per nodo
4. **MAI ritrasmettere** al nodo da cui hai ricevuto il pacchetto
5. **L2CAP** è il metodo primario per file > MTU; GATT chunking è fallback
6. **SHA-256** checksum obbligatorio per file transfer
7. **NON** implementare routing intelligente (shortest path, etc.) — gossip flooding è sufficiente per 10-30 nodi
8. **OGNI** file deve avere un commento header con path e descrizione breve
9. **TEST:** Unit test per MeshRouter (scenari: dedup, TTL decrement, fan-out exclusion)
10. **TEST:** Integration test L2CAP con file piccolo (~10KB)

---

## Verifiche

### Automatiche
```bash
flutter analyze
flutter test
cd android && ./gradlew testDebugUnitTest
cd ios && xcodebuild test -workspace Runner.xcworkspace -scheme Runner
```

### Manuali — Scenario Mesh Multi-Hop
1. **3 dispositivi A, B, C** disposti in linea (A↔B, B↔C, A≠C)
2. A invia messaggio → B lo riceve (1-hop) → B ritrasmette → C lo riceve (2-hop)
3. C invia ACK → percorso inverso → A vede "delivered"
4. Verificare che A non riceva il suo stesso messaggio (dedup)

### Manuali — File Transfer
1. A invia immagine (200KB) → manifest via GATT → L2CAP stream → B riceve
2. Verifica checksum SHA-256 corretto
3. Se L2CAP fallisce → fallback GATT chunking automatico

### Manuali — Stress Test
1. 5+ dispositivi → tutti inviano messaggi simultaneamente
2. Verificare: nessun messaggio perso, nessun duplicato, TTL rispettato
3. Mesh Status Bar mostra conteggio nodi accurato

---

## Roadmap Finale

| Fase | Contenuto | Status |
|------|-----------|--------|
| **1** | Setup + UI | ✅ Completata |
| **2** | SQLite + AES-256-GCM + time_delta | ✅ Completata |
| **3** | Android Kotlin BLE | ✅ Completata |
| **4** | iOS Swift CoreBluetooth | ✅ Completata |
| **5** ← CORRENTE | Gossip Mesh Routing + L2CAP file transfer | 🔨 Da fare |

---

## Post-Fase 5: Feature Opzionali (Non Implementare Ora)

- **Typing indicators** via PRESENCE packet
- **Read receipts** per messaggio
- **Gruppi multipli** simultanei
- **File caching** — non ri-scaricare file già ricevuti
- **Compressione** payload con zlib prima di AES
- **Adaptive TTL** — aumenta TTL se mesh grande, riduci se piccola
- **Signal strength routing** — preferisci nodi con RSSI migliore
