# FlightChat — Fase 4: Modulo Nativo iOS BLE (Swift/CoreBluetooth)

> **Obiettivo:** Implementare il motore BLE Dual Role su iOS in Swift puro con CoreBluetooth, State Restoration per background operation, e comunicazione con Flutter via Method Channel.

## Prerequisiti
- Fase 1 (UI), Fase 2 (SQLite + AES), Fase 3 (Android BLE) completate
- iOS 16+, Xcode 15+
- Nessuna libreria BLE cross-platform — Swift puro con CoreBluetooth

---

## Architettura BLE iOS

### Differenze critiche da Android

| Aspetto | Android (Fase 3) | iOS (Fase 4) |
|---------|-------------------|--------------|
| Peripheral | `BluetoothGattServer` | `CBPeripheralManager` |
| Central | `BluetoothLeScanner` + `BluetoothGatt` | `CBCentralManager` + `CBPeripheral` |
| Background | Foreground Service (sticky) | `CBCentralManager` State Restoration + background mode |
| Advertising | Indefinito con Service UUID | Limitato: solo `CBAdvertisementDataLocalNameKey` + `ServiceUUIDs` overflow |
| Scan in background | Funziona con filtro UUID | Funziona SOLO con filtro `serviceUUIDs` |
| Reconnect | Manuale con backoff | `centralManager.connect(peripheral)` = auto-reconnect |
| MTU | Negoziazione esplicita `requestMtu()` | `peripheral.maximumWriteValueLength(for:)` automatico |
| Dual Role | Thread safety via `Handler(Looper)` | `DispatchQueue` dedicate per Central e Peripheral |

### State Restoration (cruciale per iOS background)

iOS uccide le app in background ma può riavviarle per eventi BLE se State Restoration è configurato:

```swift
// Central
CBCentralManager(delegate: self, queue: bleQueue, 
    options: [CBCentralManagerOptionRestoreIdentifierKey: "FlightChatCentral"])

// Peripheral  
CBPeripheralManager(delegate: self, queue: bleQueue,
    options: [CBPeripheralManagerOptionRestoreIdentifierKey: "FlightChatPeripheral"])
```

Implementare `centralManager(_:willRestoreState:)` e `peripheralManager(_:willRestoreState:)` per recuperare connessioni e servizi dopo un relaunch.

---

## Componenti

### 1. `BleManager` — Orchestratore singleton

- Coordina `CentralManager` + `PeripheralManager`
- Usa `DispatchQueue` seriale dedicata per BLE: `DispatchQueue(label: "com.flightchat.ble", qos: .userInitiated)`
- Gestisce permission flow (richiesta Bluetooth in iOS 13+)
- Espone callback verso Flutter via `FlutterMethodChannel`
- Mantiene `[String: BleNode]` dei nodi connessi

### 2. `CentralManager` — Central Role

- `CBCentralManager` con State Restoration identifier
- **Scan:** `scanForPeripherals(withServices: [flightChatServiceUUID])`
  - In foreground: continuo
  - In background: iOS lo gestisce in batch, ritarda le callback
- **Connect:** `connect(peripheral, options: [CBConnectPeripheralOptionNotifyOnConnectionKey: true])`
  - iOS riconnette automaticamente se il peripheral torna in range
- **Discover Services → Characteristics → Subscribe to NOTIFY**
- **Read `NODE_INFO`** → salva deviceId + nickname
- **Receive:** `peripheral(_:didUpdateValueFor:)` su MESSAGE_NOTIFY → deserializza `MeshPacket`

### 3. `PeripheralManager` — Peripheral Role

- `CBPeripheralManager` con State Restoration identifier
- Crea `CBMutableService` con le 3 characteristics (stessi UUID di Android)
- `peripheralManager(_:didReceiveWrite:)` → riceve pacchetti mesh
- `updateValue(_:for:onSubscribedCentrals:)` → invia notifiche
- Gestisce `peripheralManagerDidUpdateState` per advertising start/stop

### 4. `BleNode` — Struct nodo

```swift
struct BleNode {
    let deviceId: String
    let peripheral: CBPeripheral
    var nickname: String?
    var rssi: Int
    var isConnected: Bool
    var lastSeen: Date
    var writeCharacteristic: CBCharacteristic?  // MESSAGE_WRITE del peer
}
```

### 5. `MeshPacket` — Serializzazione

Stesso formato binario di Android (vedi Fase 3). Implementare `serialize() -> Data` e `init(data: Data) throws` con validazione CRC32.

### 6. `FlightChatPlugin` — Method Channel

Stessa API di Android:
- Flutter → Swift: `startMesh`, `stopMesh`, `getConnectedNodes`, `sendPacket`
- Swift → Flutter: `onPacketReceived`, `onNodeConnected`, `onNodeDisconnected`, `onMeshStateChanged`

Registrare in `AppDelegate.swift` (o `GeneratedPluginRegistrant`).

---

## Info.plist — Chiavi richieste

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>FlightChat uses Bluetooth to create an offline mesh network for messaging between passengers.</string>

<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
    <string>bluetooth-peripheral</string>
</array>

<key>NSBluetoothPeripheralUsageDescription</key>
<string>FlightChat advertises as a Bluetooth peripheral to allow nearby devices to connect.</string>
```

---

## Struttura File

```
ios/Runner/
├── AppDelegate.swift               # MODIFICA: registra FlightChatPlugin
├── Ble/
│   ├── BleManager.swift            # Orchestratore singleton
│   ├── CentralManager.swift        # CBCentralManager wrapper
│   ├── PeripheralManager.swift     # CBPeripheralManager wrapper
│   ├── BleNode.swift               # Struct nodo connesso
│   ├── BleConstants.swift          # UUIDs, timeout constants
│   └── MeshPacket.swift            # Serialize/deserialize pacchetto
└── Channel/
    └── FlightChatPlugin.swift      # Method Channel bridge
```

`lib/core/services/ble_service.dart` — già creato in Fase 3, condiviso iOS/Android (Method Channel è lo stesso).

---

## Vincoli Espliciti Fase 4

1. **NON** modificare il codice Android di Fase 3
2. **NON** usare librerie BLE cross-platform
3. **NON** implementare gossip routing — solo 1-hop diretto
4. **SWIFT PURO** con CoreBluetooth — no Objective-C bridging headers
5. **STATE RESTORATION** obbligatoria per Central e Peripheral
6. **BACKGROUND MODES** `bluetooth-central` + `bluetooth-peripheral` nel Info.plist
7. **STESSI UUID** servizio e characteristics di Android (FC000001-...)
8. **STESSO formato** MeshPacket binario di Android
9. **DISPATCH QUEUE** dedicata per operazioni BLE (no main queue)
10. **OGNI** file deve avere un commento header con path e descrizione breve

---

## Verifiche

### Automatiche
```bash
flutter analyze
flutter test
cd ios && xcodebuild test -workspace Runner.xcworkspace -scheme Runner -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Manuali
- Due dispositivi iOS: mesh funzionante (scan + connect + messaggi)
- iOS + Android: cross-platform mesh (iPhone vede Android e viceversa)
- Chiudi app iOS → aspetta 30s → riapri → connessioni BLE restaurate
- Modalità Aereo con Bluetooth ON → mesh continua

---

## Roadmap

| Fase | Contenuto | Status |
|------|-----------|--------|
| **1** | Setup + UI | ✅ Completata |
| **2** | SQLite + AES-256-GCM + time_delta | ✅ Completata |
| **3** | Android Kotlin BLE | ✅ Completata |
| **4** ← CORRENTE | iOS Swift CoreBluetooth + State Restoration | 🔨 Da fare |
| **5** | Gossip Mesh Routing + L2CAP file transfer | ⏳ Attesa |
