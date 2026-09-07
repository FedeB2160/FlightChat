# FlightChat — Piano Fase 3 (Adattato per Gemini 3.1 Pro · Effort: HIGH)

> **Istruzioni per il modello:** Questo documento è un piano di implementazione autosufficiente. Contiene TUTTO il contesto necessario. NON fare assunzioni al di fuori di ciò che è scritto qui. Segui ogni sezione nell'ordine esatto. Produci codice completo e funzionante per ogni file — nessun placeholder, nessun `// TODO`, nessun `...`. Ogni file deve compilare senza errori. Se trovi ambiguità, scegli l'opzione più robusta e documenta la scelta con un commento `// DECISION:`.

---

## 🎯 Obiettivo

Implementare la **Fase 3** di FlightChat: il motore BLE nativo Android in **Kotlin puro** usando le Android Bluetooth API. Il modulo deve supportare **Dual Role** (Peripheral + Central simultaneamente), un **Foreground Service** per operazione in background, e comunicazione con Flutter via **Method Channel**. NON implementare gossip routing — questa fase copre solo connessione diretta e scambio pacchetti tra nodi adiacenti.

---

## 📐 Contesto (da Fasi 1-2)

### Cosa esiste già
- App Flutter con 4 schermate, design system, i18n
- SQLite con tabelle `groups`, `messages`, `user_profiles`
- AES-256-GCM encrypt/decrypt funzionante
- `ChatNotifier` legge/scrive dal DB
- `MeshStatusBar` mostra conteggio nodi (attualmente mock hardcoded 4)

### Cosa va collegato
- `MeshStatusBar` → conteggio nodi reale da BLE
- `ChatNotifier` → invia pacchetti mesh via Method Channel
- `ChatNotifier` → riceve pacchetti mesh da Method Channel, decripta, salva in DB

---

## 📦 Dipendenze

### Android (build.gradle — NON aggiungere librerie BLE esterne)
```groovy
// Nessuna dipendenza BLE aggiuntiva — usa solo android.bluetooth.*
// Assicurati compileSdk = 34 e minSdk = 31
```

### Flutter (pubspec.yaml — aggiungi solo se non presente)
```yaml
  # Nessuna nuova dipendenza Flutter per questa fase
```

---

## 📁 Struttura File (Crea ESATTAMENTE questi file)

### File Kotlin Nuovi
```
android/app/src/main/kotlin/com/flightchat/flight_chat/
├── MainActivity.kt                         # MODIFICA: registra FlightChatMethodChannel
├── ble/
│   ├── BleManager.kt                      # Orchestratore singleton
│   ├── GattServer.kt                      # GATT Server (peripheral)
│   ├── BleScanner.kt                      # Scanner + Connector (central)
│   ├── BleAdvertiser.kt                   # BLE Advertiser
│   ├── BleNode.kt                         # Data class nodo connesso
│   ├── BleConstants.kt                    # UUIDs servizio, MTU, timeouts
│   └── MeshPacket.kt                      # Serializzazione/deserializzazione pacchetto
├── service/
│   └── BleForegroundService.kt            # Foreground Service sticky
└── channel/
    └── FlightChatMethodChannel.kt         # Method Channel bridge
```

### File Dart Nuovi
```
lib/
├── core/
│   └── services/
│       └── ble_service.dart               # Flutter-side Method Channel wrapper
```

### File Dart da MODIFICARE
- `lib/features/chat/presentation/notifiers/chat_notifier.dart` — integra BleService
- `lib/features/chat/presentation/widgets/mesh_status_bar.dart` — nodi reali

### File XML da MODIFICARE
- `android/app/src/main/AndroidManifest.xml` — permessi + service

---

## 📄 Specifica Dettagliata per File

### `ble/BleConstants.kt`

```kotlin
// COPIA ESATTAMENTE
object BleConstants {
    const val SERVICE_UUID = "FC000001-0000-1000-8000-00805F9B34FB"
    const val CHAR_MESSAGE_WRITE_UUID = "FC000002-0000-1000-8000-00805F9B34FB"
    const val CHAR_MESSAGE_NOTIFY_UUID = "FC000003-0000-1000-8000-00805F9B34FB"
    const val CHAR_NODE_INFO_UUID = "FC000004-0000-1000-8000-00805F9B34FB"
    
    const val MTU_REQUESTED = 512
    const val MTU_DEFAULT = 185
    const val SCAN_DURATION_MS = 10_000L    // 10s scan
    const val SCAN_PAUSE_MS = 5_000L        // 5s pausa
    const val RECONNECT_BASE_MS = 1_000L    // backoff base
    const val RECONNECT_MAX_MS = 30_000L    // backoff max
    const val METHOD_CHANNEL = "com.flightchat/ble"
    
    const val NOTIFICATION_CHANNEL_ID = "flightchat_mesh"
    const val NOTIFICATION_ID = 1001
    const val FOREGROUND_SERVICE_TYPE = 0x00000010 // CONNECTED_DEVICE
}
```

### `ble/MeshPacket.kt`

```kotlin
// Formato pacchetto binario:
// [version:1][type:1][messageId:16][senderDeviceId:16][ttl:1][timeDelta:4][payloadLen:2][payload:N][crc32:4]

data class MeshPacket(
    val version: Byte = 0x01,
    val type: PacketType,
    val messageId: ByteArray,      // 16 bytes UUID
    val senderDeviceId: ByteArray, // 16 bytes UUID
    val ttl: Int,                  // 0-255
    val timeDelta: Int,            // secondi da t0
    val payload: ByteArray         // encrypted content
) {
    enum class PacketType(val value: Byte) {
        MESSAGE(0x01), ACK(0x02), PRESENCE(0x03)
    }
    
    fun serialize(): ByteArray { /* ... big-endian, append CRC32 */ }
    
    companion object {
        fun deserialize(data: ByteArray): MeshPacket { /* ... validate CRC32 */ }
    }
}
```

### `ble/BleNode.kt`

```kotlin
data class BleNode(
    val deviceId: String,
    val address: String,           // MAC address BLE
    val nickname: String?,
    val rssi: Int,
    val isConnected: Boolean,
    val lastSeenMs: Long,
    val negotiatedMtu: Int = BleConstants.MTU_DEFAULT
)
```

### `ble/BleManager.kt`

- **Singleton** — `companion object { @Volatile private var instance: BleManager? = null }`
- `fun start(context: Context, groupId: String)` — avvia scanner + advertiser + gatt server
- `fun stop()` — ferma tutto, disconnetti tutti i nodi
- `fun sendPacket(packet: MeshPacket)` — invia a TUTTI i nodi connessi (fan-out)
- `fun getConnectedNodes(): List<BleNode>` — snapshot nodi correnti
- `var onPacketReceived: ((MeshPacket) -> Unit)?` — callback per pacchetti ricevuti
- `var onNodeChanged: ((List<BleNode>) -> Unit)?` — callback per cambi topologia
- Gestisce permessi runtime: `BLUETOOTH_SCAN`, `BLUETOOTH_ADVERTISE`, `BLUETOOTH_CONNECT`

### `ble/GattServer.kt`

- Crea `BluetoothGattServer` con:
  - Servizio UUID `FC000001-...`
  - Caratteristica `MESSAGE_WRITE` (WRITE_NO_RESPONSE)
  - Caratteristica `MESSAGE_NOTIFY` (NOTIFY) con descriptor CCCD
  - Caratteristica `NODE_INFO` (READ)
- `onCharacteristicWriteRequest` → deserializza `MeshPacket` → callback `onPacketReceived`
- `onCharacteristicReadRequest` su NODE_INFO → rispondi con deviceId + nickname JSON
- `sendNotification(device, packet)` → write su NOTIFY per tutti i subscriber
- Gestisce MTU negoziazione in `onMtuChanged`

### `ble/BleScanner.kt`

- `startScan()` — `BluetoothLeScanner.startScan()` con filtro Service UUID
- `ScanSettings.Builder()`:
  - `.setScanMode(SCAN_MODE_LOW_LATENCY)` per primi 10s
  - Poi `.setScanMode(SCAN_MODE_LOW_POWER)` per risparmio batteria
- Duty cycle con `Handler.postDelayed`: 10s scan → 5s pausa → repeat
- Al discovery di un nuovo device:
  1. `connectGatt(context, false, gattCallback)` con `TRANSPORT_LE`
  2. `discoverServices()`
  3. Leggi `NODE_INFO` → ottieni deviceId + nickname
  4. Attiva notifiche su `MESSAGE_NOTIFY` (write CCCD)
  5. Aggiungi a lista nodi in `BleManager`
- `onConnectionStateChange` → gestisce disconnessione con retry backoff esponenziale

### `ble/BleAdvertiser.kt`

- `BluetoothLeAdvertiser.startAdvertising()`:
  - `AdvertiseSettings`: LOW_LATENCY, connectable = true, timeout = 0 (indefinito)
  - `AdvertiseData`: include Service UUID FC000001
- Callback `onStartSuccess` / `onStartFailure` con retry su errore
- `stop()` → `stopAdvertising()`

### `service/BleForegroundService.kt`

- Estende `Service`, tipo `FOREGROUND_SERVICE_CONNECTED_DEVICE`
- `onStartCommand` → `startForeground(NOTIFICATION_ID, notification)` 
- Notification: canale "FlightChat Mesh", priorità LOW, icona `ic_stat_mesh`
- Mantiene reference a `BleManager`, lo avvia in `onCreate`
- `onTaskRemoved` → `START_STICKY` per auto-restart
- `onDestroy` → `BleManager.stop()`

### `channel/FlightChatMethodChannel.kt`

- Registra `MethodChannel("com.flightchat/ble")` in `MainActivity`
- **Flutter → Kotlin:**
  - `"startMesh"` args: `{groupId: String}` → avvia `BleForegroundService` + `BleManager`
  - `"stopMesh"` → ferma servizio
  - `"getConnectedNodes"` → ritorna `List<Map>` con `{deviceId, nickname, rssi, isConnected}`
  - `"sendPacket"` args: `{data: Uint8List}` → `BleManager.sendPacket(MeshPacket.deserialize(data))`
- **Kotlin → Flutter (via EventChannel o invokeMethod):**
  - `"onPacketReceived"` → `{data: Uint8List}` pacchetto serializzato
  - `"onNodeConnected"` → `{deviceId, nickname, rssi}`
  - `"onNodeDisconnected"` → `{deviceId}`
  - `"onMeshStateChanged"` → `{state: "scanning"|"advertising"|"connected"|"error", message: String?}`

### `lib/core/services/ble_service.dart` (Flutter side)

```dart
class BleService extends ChangeNotifier {
  static const _channel = MethodChannel('com.flightchat/ble');
  
  List<Map<String, dynamic>> _connectedNodes = [];
  String _meshState = 'idle';
  
  List<Map<String, dynamic>> get connectedNodes => _connectedNodes;
  String get meshState => _meshState;
  int get nodeCount => _connectedNodes.length;
  
  BleService() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }
  
  Future<void> startMesh(String groupId) async {
    await _channel.invokeMethod('startMesh', {'groupId': groupId});
  }
  
  Future<void> stopMesh() async {
    await _channel.invokeMethod('stopMesh');
  }
  
  Future<void> sendPacket(Uint8List data) async {
    await _channel.invokeMethod('sendPacket', {'data': data});
  }
  
  Function(Uint8List)? onPacketReceived;
  
  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onPacketReceived':
        onPacketReceived?.call(call.arguments['data']);
        break;
      case 'onNodeConnected':
        _connectedNodes.add(Map<String, dynamic>.from(call.arguments));
        notifyListeners();
        break;
      case 'onNodeDisconnected':
        _connectedNodes.removeWhere((n) => n['deviceId'] == call.arguments['deviceId']);
        notifyListeners();
        break;
      case 'onMeshStateChanged':
        _meshState = call.arguments['state'];
        notifyListeners();
        break;
    }
  }
}
```

---

## 📱 AndroidManifest.xml — Modifiche

```xml
<!-- Dentro <manifest>, prima di <application> -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"
    android:usesPermissionFlags="neverForLocation" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<uses-feature android:name="android.hardware.bluetooth_le" android:required="true" />

<!-- Dentro <application> -->
<service
    android:name=".service.BleForegroundService"
    android:enabled="true"
    android:exported="false"
    android:foregroundServiceType="connectedDevice" />
```

---

## ✅ Ordine di Implementazione (Segui esattamente)

1. Modifica `AndroidManifest.xml` — permessi e service declaration
2. Crea `ble/BleConstants.kt`
3. Crea `ble/MeshPacket.kt` con serialize/deserialize
4. Crea `ble/BleNode.kt`
5. Crea `ble/GattServer.kt`
6. Crea `ble/BleScanner.kt`
7. Crea `ble/BleAdvertiser.kt`
8. Crea `ble/BleManager.kt` — orchestra i 3 componenti sopra
9. Crea `service/BleForegroundService.kt`
10. Crea `channel/FlightChatMethodChannel.kt`
11. Modifica `MainActivity.kt` — registra method channel
12. Crea `lib/core/services/ble_service.dart` — wrapper Flutter
13. Modifica `ChatNotifier` — integra `BleService` per invio/ricezione
14. Modifica `MeshStatusBar` — leggi conteggio nodi reale da `BleService`
15. Crea unit test Kotlin per `MeshPacket` serialize/deserialize
16. `flutter analyze` — ZERO errori accettati
17. `cd android && ./gradlew testDebugUnitTest` — test Kotlin passano
18. Test manuale su 2 dispositivi Android

---

## ⚠️ Vincoli Espliciti

1. **NON** implementare iOS — quello è Fase 4
2. **NON** usare librerie BLE cross-platform (`flutter_blue`, `reactive_ble`, `flutter_ble_peripheral`, etc.)
3. **NON** implementare gossip/flood routing — solo invio/ricezione diretta 1-hop
4. **NON** implementare chunking L2CAP — quello è Fase 5
5. **KOTLIN PURO** con `android.bluetooth.*` API
6. **DUAL ROLE** obbligatorio: GATT Server + Scanner contemporanei
7. **FOREGROUND SERVICE** obbligatorio per operazione in background
8. **MTU** negoziazione: richiedi 512, usa valore negoziato
9. **RECONNECT** automatico con backoff esponenziale (1s → 2s → 4s → max 30s)
10. **OGNI** file deve avere un commento header con path e descrizione breve

---

## 📋 Roadmap

| Fase | Contenuto | Status |
|------|-----------|--------|
| **1** | Setup + UI | ✅ Completata |
| **2** | SQLite + AES-256-GCM + time_delta | ✅ Completata |
| **3** ← CORRENTE | Android Kotlin BLE Dual Role + Foreground Service | 🔨 Da fare |
| **4** | iOS Swift CoreBluetooth (State Restoration + Background) | ⏳ Attesa |
| **5** | Gossip Mesh Routing + L2CAP file transfer | ⏳ Attesa |
