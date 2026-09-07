# FlightChat — Fase 3: Modulo Nativo Android BLE (Kotlin)

> **Obiettivo:** Implementare il motore BLE Dual Role su Android in Kotlin puro, con GATT Server, Scanner, Advertiser, e Foreground Service per operazione in background.

## Prerequisiti
- Fase 1 (UI) e Fase 2 (SQLite + AES-256-GCM) completate
- Android SDK 31+ (Android 12+)
- Nessuna libreria BLE cross-platform — Kotlin puro con Android Bluetooth API

---

## Architettura BLE Android

### Dual Role: Peripheral + Central contemporaneamente

Ogni dispositivo Android deve funzionare sia come **GATT Server** (Peripheral/Advertiser) che come **GATT Scanner** (Central) contemporaneamente. Questo è il cuore della mesh.

```
┌─────────────────────────────────────────┐
│              FlightChat App             │
│                                         │
│  ┌──────────────┐  ┌────────────────┐   │
│  │ Flutter UI   │  │ Method Channel │   │
│  └──────┬───────┘  └───────┬────────┘   │
│         │                  │            │
│  ═══════╪══════════════════╪════════════╡
│         │    Kotlin Native │            │
│  ┌──────┴──────────────────┴────────┐   │
│  │        BleManager (Singleton)     │   │
│  │                                   │   │
│  │  ┌─────────────┐ ┌────────────┐  │   │
│  │  │ GattServer  │ │ BleScanner │  │   │
│  │  │ (Peripheral)│ │ (Central)  │  │   │
│  │  └──────┬──────┘ └─────┬──────┘  │   │
│  │         │              │         │   │
│  │  ┌──────┴──────┐ ┌─────┴──────┐  │   │
│  │  │ Advertiser  │ │ Connector  │  │   │
│  │  └─────────────┘ └────────────┘  │   │
│  └──────────────────────────────────┘   │
│                                         │
│  ┌──────────────────────────────────┐   │
│  │    Foreground Service (sticky)    │   │
│  │    Notification: "Mesh attiva"    │   │
│  └──────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

### Servizio GATT FlightChat

```
Service UUID: "FC000001-0000-1000-8000-00805F9B34FB"

Characteristics:
├── MESSAGE_WRITE (Write Without Response)
│   UUID: "FC000002-..."
│   Proprietà: WRITE_NO_RESPONSE
│   Uso: Ricevi pacchetti mesh da altri nodi
│
├── MESSAGE_NOTIFY (Notify)
│   UUID: "FC000003-..."
│   Proprietà: NOTIFY
│   Uso: Invia pacchetti mesh verso nodi connessi
│
└── NODE_INFO (Read)
    UUID: "FC000004-..."
    Proprietà: READ
    Uso: Device info (deviceId, nickname, groupId hash)
```

---

## Componenti

### 1. `BleManager` — Orchestratore singleton

- Inizializza `BluetoothAdapter`, verifica permessi
- Avvia/ferma `GattServer` + `BleScanner` + `Advertiser`
- Mantiene mappa dei nodi connessi: `Map<String, BleNode>`
- Gestisce reconnect automatico
- Espone callback verso Flutter via `MethodChannel`

### 2. `GattServer` — Peripheral Role

- Crea `BluetoothGattServer` con il servizio FlightChat
- Gestisce `onCharacteristicWriteRequest` → riceve pacchetti mesh
- Gestisce `onNotificationSent` → conferma invio
- Gestisce `onConnectionStateChange` → traccia nodi connessi/disconnessi
- Buffer di invio con MTU negotiation (max 512 bytes, default 185)

### 3. `BleScanner` — Central Role

- Scan BLE con filtro per Service UUID FlightChat
- `ScanSettings`: LOW_LATENCY durante discovery iniziale, poi LOW_POWER
- Duty cycle: 10s scan / 5s pausa (risparmio batteria in aereo)
- Al discovery: connect → discover services → subscribe a NOTIFY → exchange NODE_INFO
- Gestisce disconnessioni e retry (backoff esponenziale: 1s, 2s, 4s, max 30s)

### 4. `BleAdvertiser`

- Advertise con Service UUID FlightChat
- Include nome device troncato (max 8 chars per BLE adv payload)
- `AdvertiseSettings`: LOW_LATENCY, connectable = true
- Riavvio automatico se advertising fallisce (Android limita a 5 advertiser simultanei)

### 5. `BleForegroundService`

- `Service` sticky con notifica persistente "FlightChat — Mesh attiva"
- Mantiene `BleManager` vivo anche con app in background
- Notification channel: "FlightChat Mesh" con priorità LOW
- `startForeground()` con tipo CONNECTED_DEVICE (Android 14+)
- Gestisce `onTaskRemoved` → restart service

### 6. `FlightChatMethodChannel` — Bridge Flutter ↔ Kotlin

```kotlin
// Canale: "com.flightchat/ble"
// Flutter → Kotlin:
"startMesh"        → avvia BleManager + Foreground Service
"stopMesh"         → ferma tutto
"getConnectedNodes" → lista nodi [{deviceId, nickname, rssi}]
"sendPacket"       → invia pacchetto mesh (bytes)

// Kotlin → Flutter:
"onPacketReceived"  → pacchetto mesh ricevuto (bytes)
"onNodeConnected"   → nuovo nodo nella mesh
"onNodeDisconnected" → nodo perso
"onMeshStateChanged" → stato mesh (scanning/advertising/connected/error)
```

---

## Permessi Android

```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.BLUETOOTH_ADVERTISE" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />

<uses-feature android:name="android.hardware.bluetooth_le" android:required="true" />
```

---

## Struttura File

```
android/app/src/main/kotlin/com/flightchat/flight_chat/
├── MainActivity.kt                    # Entry point, registra MethodChannel
├── ble/
│   ├── BleManager.kt                 # Orchestratore singleton
│   ├── GattServer.kt                 # GATT Server (peripheral role)
│   ├── BleScanner.kt                 # BLE Scanner (central role)
│   ├── BleAdvertiser.kt              # BLE Advertiser
│   ├── BleNode.kt                    # Data class nodo connesso
│   └── BleConstants.kt               # UUIDs, MTU, timeout constants
├── service/
│   └── BleForegroundService.kt        # Foreground Service sticky
└── channel/
    └── FlightChatMethodChannel.kt     # Method Channel bridge

lib/
├── core/
│   └── services/
│       └── ble_service.dart           # Flutter-side Method Channel wrapper
```

---

## Pacchetto Mesh (Formato binario)

```
Offset  Size  Field
0       1     version (0x01)
1       1     type (0x01=message, 0x02=ack, 0x03=presence)
2       16    message_id (UUID bytes)
18      16    sender_device_id (UUID bytes)  
34      1     ttl (0-255, default 3)
35      4     time_delta (uint32 big-endian, secondi da t0)
39      2     payload_length (uint16 big-endian)
41      N     payload (encrypted AES-256-GCM bytes)
41+N    4     crc32 (integrità pacchetto)
```

Max pacchetto: 512 bytes (MTU). Se payload > 467 bytes → chunking (Fase 5 con L2CAP).

---

## Vincoli Espliciti Fase 3

1. **NON** implementare iOS — quello è Fase 4
2. **NON** usare librerie BLE cross-platform (flutter_blue, reactive_ble, etc.)
3. **NON** implementare gossip routing — solo invio/ricezione diretta tra nodi connessi
4. **GATT Server** e **Scanner** devono funzionare contemporaneamente (dual role)
5. **Foreground Service** obbligatorio per operazione in background
6. **MTU** negoziazione: richiedi 512, fallback a valore negoziato
7. **Reconnect** automatico con backoff esponenziale
8. **OGNI** file deve avere un commento header con path e descrizione breve
9. **TEST:** Unit test Kotlin per serializzazione/deserializzazione pacchetto mesh

---

## Verifiche

### Automatiche
```bash
flutter analyze
flutter test
cd android && ./gradlew testDebugUnitTest
```

### Manuali
- Due dispositivi Android: uno crea gruppo, l'altro scansiona QR → si vedono nella mesh
- Mesh Status Bar mostra conteggio nodi reale (non mock)
- Invio messaggio → appare sull'altro dispositivo (cifrato in transito)
- Chiudi app → Foreground Service mantiene la mesh → riapri → messaggi ricevuti visibili
- Attiva Modalità Aereo con Bluetooth ON → mesh continua a funzionare

---

## Roadmap

| Fase | Contenuto | Status |
|------|-----------|--------|
| **1** | Setup + UI | ✅ Completata |
| **2** | SQLite + AES-256-GCM + time_delta | ✅ Completata |
| **3** ← CORRENTE | Android Kotlin BLE Dual Role + Foreground Service | 🔨 Da fare |
| **4** | iOS Swift CoreBluetooth | ⏳ Attesa |
| **5** | Gossip Mesh Routing + L2CAP | ⏳ Attesa |
