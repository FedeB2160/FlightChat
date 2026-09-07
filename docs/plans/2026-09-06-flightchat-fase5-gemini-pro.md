# FlightChat — Piano Fase 5 (Adattato per Gemini 3.1 Pro · Effort: HIGH)

> **Istruzioni per il modello:** Questo documento è un piano di implementazione autosufficiente. Contiene TUTTO il contesto necessario. NON fare assunzioni al di fuori di ciò che è scritto qui. Segui ogni sezione nell'ordine esatto. Produci codice completo e funzionante per ogni file — nessun placeholder, nessun `// TODO`, nessun `...`. Ogni file deve compilare senza errori. Se trovi ambiguità, scegli l'opzione più robusta e documenta la scelta con un commento `// DECISION:`.

---

## 🎯 Obiettivo

Implementare la **Fase 5** di FlightChat: trasformare la rete BLE 1-hop (Fasi 3-4) in una **mesh multi-hop** con Gossip Protocol, TTL-based flooding, deduplicazione per `message_id`, e **L2CAP CoC** per trasferimento file grandi. Questa è la fase finale che completa l'app.

---

## 📐 Contesto (da Fasi 1-4)

### Cosa esiste già
- App Flutter completa con UI, SQLite, AES-256-GCM
- Android BLE: `BleManager` + `GattServer` + `BleScanner` + `BleAdvertiser` + `BleForegroundService`
- iOS BLE: `BleManager` + `CentralManagerHandler` + `PeripheralManagerHandler` con State Restoration
- `BleService` Flutter-side con Method Channel condiviso
- `MeshPacket` con formato binario: `[version][type][messageId][senderDeviceId][ttl][timeDelta][payloadLen][payload][crc32]`
- Connessioni 1-hop funzionanti: un nodo invia → solo i nodi direttamente connessi ricevono

### Cosa manca
- **Multi-hop:** Pacchetti devono essere ritrasmessi ai vicini (gossip flooding)
- **Deduplicazione:** Cache per `message_id` per prevenire loop e duplicati
- **ACK propagation:** Status messaggio `sent` → `delivered` via ACK multi-hop
- **L2CAP:** Transfer file > MTU via canale stream-oriented
- **File manifest:** Protocollo per annunciare e trasferire file

---

## 📁 Struttura File (Crea ESATTAMENTE questi file)

### Kotlin (Android) — File Nuovi
```
android/app/src/main/kotlin/com/flightchat/flight_chat/
├── mesh/
│   ├── MeshRouter.kt              # Logica gossip: ricevi, dedup, decrementa TTL, ritrasmetti
│   ├── DeduplicationCache.kt      # LRU LinkedHashMap, max 10000 entries, TTL 5 minuti
│   └── PacketQueue.kt             # Coda prioritizzata: ACK > MESSAGE > PRESENCE, rate limit 20/s
├── l2cap/
│   └── L2CAPManager.kt            # L2CAP CoC: apri canale, streaming, fallback GATT chunking
```

### Swift (iOS) — File Nuovi
```
ios/Runner/
├── Mesh/
│   ├── MeshRouter.swift            # Stessa logica di Android
│   ├── DeduplicationCache.swift    # Stessa logica di Android
│   └── PacketQueue.swift           # Stessa logica di Android
├── L2CAP/
│   └── L2CAPManager.swift          # L2CAP CoC con CBL2CAPChannel
```

### Dart (Flutter) — File Nuovi
```
lib/
├── core/
│   └── services/
│       └── mesh_service.dart           # Orchestratore Dart: integra BleService + routing info
├── features/
│   └── chat/
│       ├── presentation/
│       │   └── widgets/
│       │       └── file_transfer_indicator.dart  # Widget progress bar transfer
│       └── models/
│           └── file_manifest.dart       # Modello manifest per file transfer
```

### File da MODIFICARE
- `android/.../ble/BleManager.kt` — integra `MeshRouter` nel flusso pacchetti
- `ios/.../Ble/BleManager.swift` — integra `MeshRouter` nel flusso pacchetti
- `lib/core/services/ble_service.dart` — aggiungi metodi per file transfer
- `lib/features/chat/presentation/notifiers/chat_notifier.dart` — gestisci ACK multi-hop + file
- `lib/features/chat/presentation/widgets/message_input.dart` — bottone attach file

---

## 📄 Specifica Dettagliata per Componente

### `MeshRouter` (Kotlin + Swift — stessa logica)

```
class MeshRouter {
    private val dedupCache: DeduplicationCache
    private val packetQueue: PacketQueue
    
    // Callback verso BleManager per invio
    var sendToNodes: ((MeshPacket, excludeNodeId: String?) -> Unit)?
    
    // Callback verso Flutter per messaggi processati
    var onMessageProcessed: ((MeshPacket) -> Unit)?
    var onAckProcessed: ((String) -> Unit)?  // message_id dell'ACK
    
    fun onPacketReceived(packet: MeshPacket, fromNodeDeviceId: String) {
        // 1. Dedup check
        if (dedupCache.contains(packet.messageId)) return
        dedupCache.add(packet.messageId)
        
        // 2. Process based on type
        when (packet.type) {
            MESSAGE -> {
                onMessageProcessed?.invoke(packet)
                // Genera ACK
                val ack = MeshPacket(
                    type = ACK,
                    messageId = generateUUID(),
                    senderDeviceId = localDeviceId,
                    ttl = DEFAULT_TTL,
                    timeDelta = currentTimeDelta(),
                    payload = packet.messageId  // ACK contiene l'ID del messaggio originale
                )
                packetQueue.enqueue(ack, priority = HIGH)
            }
            ACK -> {
                // Estrai message_id originale dal payload
                onAckProcessed?.invoke(extractOriginalMessageId(packet.payload))
            }
            PRESENCE -> {
                // Aggiorna mappa nodi conosciuti
            }
        }
        
        // 3. Gossip: ritrasmetti se TTL > 1
        if (packet.ttl > 1) {
            val forwarded = packet.copy(ttl = packet.ttl - 1)
            packetQueue.enqueue(forwarded, priority = NORMAL, excludeNode = fromNodeDeviceId)
        }
    }
    
    fun sendLocalMessage(packet: MeshPacket) {
        dedupCache.add(packet.messageId)  // Previeni eco
        packetQueue.enqueue(packet, priority = NORMAL, excludeNode = null)
    }
}
```

### `DeduplicationCache`

```kotlin
// Kotlin
class DeduplicationCache(
    private val maxSize: Int = 10_000,
    private val ttlMs: Long = 5 * 60 * 1000  // 5 minuti
) {
    private data class Entry(val timestamp: Long)
    
    // LinkedHashMap con accessOrder = true per LRU
    private val cache = object : LinkedHashMap<String, Entry>(maxSize, 0.75f, true) {
        override fun removeEldestEntry(eldest: Map.Entry<String, Entry>): Boolean {
            return size > maxSize
        }
    }
    
    @Synchronized
    fun contains(messageId: String): Boolean {
        cleanup()
        return cache.containsKey(messageId)
    }
    
    @Synchronized
    fun add(messageId: String) {
        cache[messageId] = Entry(System.currentTimeMillis())
    }
    
    @Synchronized
    private fun cleanup() {
        val now = System.currentTimeMillis()
        cache.entries.removeIf { now - it.value.timestamp > ttlMs }
    }
}
```

```swift
// Swift — stessa logica
class DeduplicationCache {
    private let maxSize = 10_000
    private let ttlSeconds: TimeInterval = 300 // 5 minuti
    private var cache: [String: Date] = [:]
    private let lock = NSLock()
    
    func contains(_ messageId: String) -> Bool {
        lock.lock(); defer { lock.unlock() }
        cleanup()
        return cache[messageId] != nil
    }
    
    func add(_ messageId: String) {
        lock.lock(); defer { lock.unlock() }
        cache[messageId] = Date()
        if cache.count > maxSize {
            // Rimuovi entry più vecchia
            if let oldest = cache.min(by: { $0.value < $1.value })?.key {
                cache.removeValue(forKey: oldest)
            }
        }
    }
    
    private func cleanup() {
        let cutoff = Date().addingTimeInterval(-ttlSeconds)
        cache = cache.filter { $0.value > cutoff }
    }
}
```

### `PacketQueue`

```
class PacketQueue {
    // Priorità: ACK (3) > MESSAGE (2) > PRESENCE (1)
    // Rate limit: max 20 pacchetti/secondo
    // Thread: dispatch su BLE queue
    
    fun enqueue(packet: MeshPacket, priority: Priority, excludeNode: String? = null)
    fun processNext()  // chiamato da timer ogni 50ms (= 20/s)
    
    // Internal: PriorityQueue ordinata per priority DESC, poi FIFO
}
```

### `L2CAPManager`

#### Android (Kotlin)

```kotlin
class L2CAPManager(private val bleManager: BleManager) {
    // PSM (Protocol/Service Multiplexer) per L2CAP CoC
    companion object {
        const val L2CAP_PSM = 0x0025  // Dynamic PSM range
    }
    
    // Server side: ascolta connessioni L2CAP
    fun startListening() {
        val serverSocket = bluetoothAdapter.listenUsingL2capChannel()
        // serverSocket.psm → comunicare al peer via GATT NODE_INFO
        thread {
            val socket = serverSocket.accept()
            handleIncomingTransfer(socket)
        }
    }
    
    // Client side: connetti e invia file
    fun sendFile(device: BluetoothDevice, psm: Int, fileData: ByteArray, manifest: FileManifest) {
        val socket = device.createL2capChannel(psm)
        socket.connect()
        val outputStream = socket.outputStream
        
        // Invia in chunks con header
        val chunkSize = 2048  // L2CAP supporta chunk grandi
        var offset = 0
        var chunkIndex = 0
        while (offset < fileData.size) {
            val end = minOf(offset + chunkSize, fileData.size)
            val chunk = fileData.copyOfRange(offset, end)
            // Header: [chunkIndex:4][chunkSize:2][data:N]
            outputStream.write(encodeChunkHeader(chunkIndex, chunk.size))
            outputStream.write(chunk)
            offset = end
            chunkIndex++
            
            // Flow control: ogni 10 chunk aspetta ACK
            if (chunkIndex % 10 == 0) {
                val ack = socket.inputStream.read()
                if (ack != 0x06) throw IOException("Transfer failed")
            }
        }
        socket.close()
    }
}
```

#### iOS (Swift)

```swift
class L2CAPManager: NSObject {
    private var l2capChannel: CBL2CAPChannel?
    
    // Publish PSM per ricevere connessioni
    func startListening(peripheralManager: CBPeripheralManager) {
        peripheralManager.publishL2CAPChannel(withEncryption: false)
    }
    
    // Callback: peripheralManager(_:didPublishL2CAPChannel:error:)
    // → comunicare PSM al peer via GATT NODE_INFO
    
    // Callback: peripheralManager(_:didOpen:error:)
    // → l2capChannel = channel → handleIncomingTransfer(channel)
    
    // Client: openL2CAPChannel per inviare file
    func sendFile(to peripheral: CBPeripheral, psm: CBL2CAPPSM, data: Data, manifest: FileManifest) {
        peripheral.openL2CAPChannel(psm)
        // Callback: peripheral(_:didOpen:error:)
        // → write data in streaming con flow control
    }
}
```

### `lib/features/chat/models/file_manifest.dart`

```dart
class FileManifest {
  final String fileId;      // UUID
  final String fileName;
  final int fileSize;       // bytes
  final int chunkCount;
  final String mimeType;
  final String checksumSha256;
  
  FileManifest({...});
  
  Map<String, dynamic> toJson() => {...};
  factory FileManifest.fromJson(Map<String, dynamic> json) => ...;
}
```

### `lib/features/chat/presentation/widgets/file_transfer_indicator.dart`

- Progress bar lineare con percentuale
- Nome file + dimensione
- Colore: `AppColors.accent` (verde) per upload, `AppColors.secondary` (indigo) per download
- Animazione smooth sulla progress bar
- Icona file type based on mime type
- Stato: "Sending..." / "Receiving..." / "Complete" / "Failed"

---

## 🔧 Modifiche ai File Esistenti

### Android `BleManager.kt`
- `onCharacteristicWriteRequest` → passa pacchetto a `MeshRouter.onPacketReceived(packet, fromNode)`
- `MeshRouter.sendToNodes` → callback che chiama `sendPacket` per ogni nodo (esclude originatore)
- Avvia `L2CAPManager.startListening()` all'avvio mesh

### iOS `BleManager.swift`
- Stessa integrazione di Android con `MeshRouter`
- `L2CAPManager` integrato con `PeripheralManagerHandler`

### Flutter `ble_service.dart`
- Nuovi metodi Method Channel:
  - `"sendFile"` → `{deviceId, manifest, data}`
  - `"onFileReceived"` → `{manifest, data}`
  - `"onFileProgress"` → `{fileId, progress: 0.0-1.0, direction: "up"|"down"}`

### Flutter `ChatNotifier`
- `void onAckReceived(String messageId)` → aggiorna status messaggio nel DB
- `void sendFile(File file)` → crea manifest, invoca `ble_service.sendFile`
- Gestisci `onFileReceived` → salva in storage locale, crea messaggio con attachment

### Flutter `message_input.dart`
- Aggiungi bottone attach (icona `Icons.attach_file`) a sinistra del TextField
- Al tap: mostra picker file/immagine
- Al selection: chiama `ChatNotifier.sendFile`

---

## ✅ Ordine di Implementazione (Segui esattamente)

### Parte A: Gossip Routing
1. Crea `android/.../mesh/DeduplicationCache.kt`
2. Crea `android/.../mesh/PacketQueue.kt`
3. Crea `android/.../mesh/MeshRouter.kt`
4. Modifica `android/.../ble/BleManager.kt` — integra MeshRouter
5. Crea `ios/.../Mesh/DeduplicationCache.swift`
6. Crea `ios/.../Mesh/PacketQueue.swift`
7. Crea `ios/.../Mesh/MeshRouter.swift`
8. Modifica `ios/.../Ble/BleManager.swift` — integra MeshRouter
9. Crea `lib/core/services/mesh_service.dart`
10. Modifica `ChatNotifier` — gestisci ACK e status updates

### Parte B: L2CAP File Transfer
11. Crea `android/.../l2cap/L2CAPManager.kt`
12. Crea `ios/.../L2CAP/L2CAPManager.swift`
13. Crea `lib/features/chat/models/file_manifest.dart`
14. Crea `lib/features/chat/presentation/widgets/file_transfer_indicator.dart`
15. Modifica `ble_service.dart` — metodi file transfer
16. Modifica `message_input.dart` — bottone attach
17. Modifica `ChatNotifier` — sendFile + receiveFile

### Parte C: Test e Verifica
18. Unit test `DeduplicationCache` (Kotlin + Swift)
19. Unit test `MeshRouter` (scenari: dedup, TTL, fan-out)
20. Unit test `PacketQueue` (priority, rate limit)
21. `flutter analyze` — ZERO errori
22. `flutter test` — tutti passano
23. `cd android && ./gradlew testDebugUnitTest`
24. Test manuale multi-hop (3+ dispositivi)
25. Test manuale file transfer

---

## ⚠️ Vincoli Espliciti

1. **TTL default = 3** — costante in `AppConstants`, configurabile ma MAI > 10
2. **Dedup cache** max 10.000 entries, TTL 5 minuti per entry
3. **Rate limit** max 20 pacchetti/secondo per nodo in uscita
4. **MAI ritrasmettere** al nodo da cui hai ricevuto il pacchetto (fan-out esclusione)
5. **L2CAP** metodo primario per file > 400 bytes; GATT chunking come fallback
6. **SHA-256** checksum obbligatorio per ogni file transfer
7. **Flow control** L2CAP: ACK ogni 10 chunk
8. **NON** implementare routing intelligente — gossip flooding sufficiente per 10-30 nodi
9. **OGNI** file deve avere un commento header con path e descrizione breve
10. **STESSA logica** MeshRouter in Kotlin e Swift — nessuna divergenza comportamentale

---

## 📋 Roadmap Finale

| Fase | Contenuto | Status |
|------|-----------|--------|
| **1** | Setup + UI | ✅ Completata |
| **2** | SQLite + AES-256-GCM + time_delta | ✅ Completata |
| **3** | Android Kotlin BLE | ✅ Completata |
| **4** | iOS Swift CoreBluetooth | ✅ Completata |
| **5** ← CORRENTE | Gossip Mesh Routing + L2CAP file transfer | 🔨 Da fare |
