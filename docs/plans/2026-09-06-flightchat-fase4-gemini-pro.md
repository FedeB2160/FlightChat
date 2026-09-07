# FlightChat — Piano Fase 4 (Adattato per Gemini 3.1 Pro · Effort: HIGH)

> **Istruzioni per il modello:** Questo documento è un piano di implementazione autosufficiente. Contiene TUTTO il contesto necessario. NON fare assunzioni al di fuori di ciò che è scritto qui. Segui ogni sezione nell'ordine esatto. Produci codice completo e funzionante per ogni file — nessun placeholder, nessun `// TODO`, nessun `...`. Ogni file deve compilare senza errori. Se trovi ambiguità, scegli l'opzione più robusta e documenta la scelta con un commento `// DECISION:`.

---

## 🎯 Obiettivo

Implementare la **Fase 4** di FlightChat: il motore BLE nativo iOS in **Swift puro** usando CoreBluetooth. Il modulo deve supportare **Dual Role** (CBPeripheralManager + CBCentralManager simultaneamente), **State Restoration** per operazione in background, e comunicazione con Flutter via **Method Channel** identico a quello Android.

---

## 📐 Contesto

### Cosa esiste già
- App Flutter completa con UI, SQLite, AES-256-GCM (Fasi 1-2)
- Modulo Android BLE funzionante con GATT Server + Scanner (Fase 3)
- `BleService` Flutter-side con Method Channel `"com.flightchat/ble"` — condiviso
- Formato binario `MeshPacket` definito (Fase 3)
- Service UUID `FC000001-0000-1000-8000-00805F9B34FB` e 3 characteristics

### API Method Channel (identica ad Android)
```
Flutter → Native:
  "startMesh"         {groupId: String}
  "stopMesh"          
  "getConnectedNodes" 
  "sendPacket"        {data: Uint8List}

Native → Flutter:
  "onPacketReceived"    {data: Uint8List}
  "onNodeConnected"     {deviceId, nickname, rssi}
  "onNodeDisconnected"  {deviceId}
  "onMeshStateChanged"  {state, message}
```

---

## 📁 Struttura File (Crea ESATTAMENTE questi file)

```
ios/Runner/
├── AppDelegate.swift                    # MODIFICA: registra FlightChatPlugin
├── Ble/
│   ├── BleManager.swift                # Orchestratore singleton
│   ├── CentralManagerHandler.swift     # CBCentralManager + State Restoration
│   ├── PeripheralManagerHandler.swift  # CBPeripheralManager + State Restoration
│   ├── BleNode.swift                   # Struct nodo connesso
│   ├── BleConstants.swift              # UUIDs servizio, timeout constants
│   └── MeshPacket.swift                # Serialize/deserialize (stesso formato Android)
└── Channel/
    └── FlightChatPlugin.swift          # FlutterMethodChannel bridge
```

Nessun file Dart nuovo — `ble_service.dart` è già stato creato in Fase 3 ed è cross-platform.

---

## 📄 Specifica Dettagliata per File

### `Ble/BleConstants.swift`

```swift
// COPIA ESATTAMENTE — stessi UUID di Android
import CoreBluetooth

enum BleConstants {
    static let serviceUUID = CBUUID(string: "FC000001-0000-1000-8000-00805F9B34FB")
    static let charMessageWriteUUID = CBUUID(string: "FC000002-0000-1000-8000-00805F9B34FB")
    static let charMessageNotifyUUID = CBUUID(string: "FC000003-0000-1000-8000-00805F9B34FB")
    static let charNodeInfoUUID = CBUUID(string: "FC000004-0000-1000-8000-00805F9B34FB")
    
    static let centralRestoreId = "FlightChatCentral"
    static let peripheralRestoreId = "FlightChatPeripheral"
    static let bleQueueLabel = "com.flightchat.ble"
}
```

### `Ble/BleNode.swift`

```swift
import CoreBluetooth

struct BleNode {
    let deviceId: String
    let peripheral: CBPeripheral
    var nickname: String?
    var rssi: Int
    var isConnected: Bool
    var lastSeen: Date
    var writeCharacteristic: CBCharacteristic?
    
    func toMap() -> [String: Any] {
        return [
            "deviceId": deviceId,
            "nickname": nickname ?? "",
            "rssi": rssi,
            "isConnected": isConnected
        ]
    }
}
```

### `Ble/MeshPacket.swift`

- Stessa struttura binaria di Android (Fase 3, `MeshPacket.kt`)
- `func serialize() -> Data` — big-endian, append CRC32
- `init(data: Data) throws` — valida CRC32, parsa campi
- Usa `Data`, `withUnsafeBytes`, `UInt32(bigEndian:)` per serializzazione

### `Ble/CentralManagerHandler.swift`

- `CBCentralManagerDelegate`
- Init: `CBCentralManager(delegate: self, queue: bleQueue, options: [CBCentralManagerOptionRestoreIdentifierKey: BleConstants.centralRestoreId])`
- **State Restoration:** `centralManager(_:willRestoreState:)` → recupera peripherals da `CBCentralManagerRestoredStatePeripheralsKey`
- **Scan:** `scanForPeripherals(withServices: [BleConstants.serviceUUID])` — filtro UUID obbligatorio per background
- **Connect:** `connect(peripheral, options: [CBConnectPeripheralOptionNotifyOnConnectionKey: true])` — auto-reconnect iOS
- **Discover:** servizi → characteristics → subscribe NOTIFY → read NODE_INFO
- **Receive:** `peripheral(_:didUpdateValueFor:)` → MeshPacket → callback
- **Send:** write su `MESSAGE_WRITE` characteristic del peer (`.withoutResponse`)

### `Ble/PeripheralManagerHandler.swift`

- `CBPeripheralManagerDelegate`
- Init: `CBPeripheralManager(delegate: self, queue: bleQueue, options: [CBPeripheralManagerOptionRestoreIdentifierKey: BleConstants.peripheralRestoreId])`
- **State Restoration:** `peripheralManager(_:willRestoreState:)` → recupera servizi pubblicati
- **Advertising:** `startAdvertising([CBAdvertisementDataServiceUUIDsKey: [BleConstants.serviceUUID]])`
  - ⚠️ In background iOS tronca l'advertising: solo `serviceUUIDs` sopravvive (no nome)
- **Receive writes:** `peripheralManager(_:didReceiveWrite:)` → MeshPacket → callback, respond `CBATTError.success`
- **Send notifications:** `updateValue(_:for:onSubscribedCentrals:)` — gestisci `peripheralManagerIsReady(toUpdateSubscribers:)` per flow control

### `Ble/BleManager.swift`

- **Singleton:** `static let shared = BleManager()`
- Possiede `CentralManagerHandler` + `PeripheralManagerHandler`
- `DispatchQueue` seriale: `DispatchQueue(label: BleConstants.bleQueueLabel, qos: .userInitiated)`
- `func start(groupId: String)` — avvia central scan + peripheral advertising
- `func stop()` — ferma scan, stop advertising, disconnetti tutti
- `func sendPacket(_ packet: MeshPacket)` — fan-out a tutti i nodi connessi (write su characteristic)
- `var connectedNodes: [String: BleNode]` — thread-safe access
- Callbacks: `onPacketReceived`, `onNodeChanged`

### `Channel/FlightChatPlugin.swift`

```swift
import Flutter

class FlightChatPlugin: NSObject, FlutterPlugin {
    private let channel: FlutterMethodChannel
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.flightchat/ble", 
                                           binaryMessenger: registrar.messenger())
        let instance = FlightChatPlugin(channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    init(channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()
        setupBleCallbacks()
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startMesh":
            guard let args = call.arguments as? [String: Any],
                  let groupId = args["groupId"] as? String else {
                result(FlutterError(code: "ARGS", message: "Missing groupId", details: nil))
                return
            }
            BleManager.shared.start(groupId: groupId)
            result(nil)
        case "stopMesh":
            BleManager.shared.stop()
            result(nil)
        case "getConnectedNodes":
            let nodes = BleManager.shared.connectedNodes.values.map { $0.toMap() }
            result(Array(nodes))
        case "sendPacket":
            guard let args = call.arguments as? [String: Any],
                  let data = args["data"] as? FlutterStandardTypedData else {
                result(FlutterError(code: "ARGS", message: "Missing data", details: nil))
                return
            }
            let packet = try? MeshPacket(data: data.data)
            if let packet = packet {
                BleManager.shared.sendPacket(packet)
                result(nil)
            } else {
                result(FlutterError(code: "PARSE", message: "Invalid packet", details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func setupBleCallbacks() {
        BleManager.shared.onPacketReceived = { [weak self] packet in
            DispatchQueue.main.async {
                self?.channel.invokeMethod("onPacketReceived", 
                    arguments: ["data": FlutterStandardTypedData(bytes: packet.serialize())])
            }
        }
        // ... onNodeConnected, onNodeDisconnected, onMeshStateChanged
    }
}
```

### `AppDelegate.swift` — Modifiche

```swift
// Aggiungere in application(_:didFinishLaunchingWithOptions:)
FlightChatPlugin.register(with: self.registrar(forPlugin: "FlightChatPlugin")!)
```

---

## 📱 Info.plist — Chiavi richieste

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>FlightChat uses Bluetooth to create an offline mesh network for messaging between passengers.</string>

<key>UIBackgroundModes</key>
<array>
    <string>bluetooth-central</string>
    <string>bluetooth-peripheral</string>
</array>
```

---

## ✅ Ordine di Implementazione (Segui esattamente)

1. Modifica `Info.plist` — background modes + bluetooth usage description
2. Crea `Ble/BleConstants.swift`
3. Crea `Ble/MeshPacket.swift` con serialize/deserialize (stesso formato Android)
4. Crea `Ble/BleNode.swift`
5. Crea `Ble/PeripheralManagerHandler.swift` con State Restoration
6. Crea `Ble/CentralManagerHandler.swift` con State Restoration
7. Crea `Ble/BleManager.swift` — orchestra Central + Peripheral
8. Crea `Channel/FlightChatPlugin.swift`
9. Modifica `AppDelegate.swift` — registra plugin
10. Test manuale: 2 dispositivi iOS → mesh funzionante
11. Test cross-platform: iOS + Android → interoperabilità
12. `flutter analyze` — ZERO errori accettati

---

## ⚠️ Vincoli Espliciti

1. **NON** modificare codice Android (Fase 3)
2. **NON** modificare codice Flutter Dart (tranne se strettamente necessario per iOS-only bugs)
3. **NON** usare librerie BLE cross-platform
4. **SWIFT PURO** con CoreBluetooth — no Objective-C, no bridging headers custom
5. **STATE RESTORATION** obbligatoria per `CBCentralManager` e `CBPeripheralManager`
6. **BACKGROUND MODES** `bluetooth-central` + `bluetooth-peripheral`
7. **STESSI UUID** servizio e characteristics di Android
8. **STESSO formato** MeshPacket binario di Android
9. **DISPATCH QUEUE** dedicata (no main queue per BLE)
10. **OGNI** file deve avere un commento header con path e descrizione breve

---

## 📋 Roadmap

| Fase | Contenuto | Status |
|------|-----------|--------|
| **1** | Setup + UI | ✅ Completata |
| **2** | SQLite + AES-256-GCM + time_delta | ✅ Completata |
| **3** | Android Kotlin BLE | ✅ Completata |
| **4** ← CORRENTE | iOS Swift CoreBluetooth + State Restoration | 🔨 Da fare |
| **5** | Gossip Mesh Routing + L2CAP file transfer | ⏳ Attesa |
