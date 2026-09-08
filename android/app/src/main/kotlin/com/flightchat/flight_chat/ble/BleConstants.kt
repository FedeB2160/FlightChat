// android/app/src/main/kotlin/com/flightchat/flight_chat/ble/BleConstants.kt
// UUID del servizio GATT FlightChat, budget del pacchetto mesh e tempi della radio.
package com.flightchat.flight_chat.ble

import java.util.UUID

/**
 * Costanti del protocollo BLE. Nessun import `android.*`: questo file va letto
 * anche dagli unit test JVM, e il modulo non ha `testOptions`, quindi qualunque
 * classe del framework Android farebbe fallire i test con "Method not mocked".
 */
object BleConstants {

    // --- Servizio GATT -----------------------------------------------------

    val SERVICE_UUID: UUID = UUID.fromString("FC000001-0000-1000-8000-00805F9B34FB")

    /** Write Without Response: ingresso dei pacchetti mesh dagli altri nodi. */
    val MESSAGE_WRITE_UUID: UUID = UUID.fromString("FC000002-0000-1000-8000-00805F9B34FB")

    /** Notify: uscita dei pacchetti mesh verso i nodi connessi. */
    val MESSAGE_NOTIFY_UUID: UUID = UUID.fromString("FC000003-0000-1000-8000-00805F9B34FB")

    /** Read: deviceId, nickname e hash del groupId del nodo. */
    val NODE_INFO_UUID: UUID = UUID.fromString("FC000004-0000-1000-8000-00805F9B34FB")

    // --- Budget del pacchetto ---------------------------------------------
    //
    // Derivato qui una volta sola. Il lato Dart ne ricava il limite dell'input
    // in AppConstants: se questi numeri cambiano, va aggiornato anche quello.

    /** Dimensione massima di un pacchetto: coincide con l'MTU richiesto. */
    const val MAX_PACKET_BYTES = 512

    /** version(1) + type(1) + messageId(16) + senderDeviceId(16) + ttl(1) + timeDelta(4) + payloadLength(2) */
    const val HEADER_BYTES = 41

    /** CRC32 in coda al pacchetto. */
    const val CRC_BYTES = 4

    /** Byte disponibili al payload cifrato: 512 - 41 - 4 = 467. */
    const val MAX_PAYLOAD_BYTES = MAX_PACKET_BYTES - HEADER_BYTES - CRC_BYTES

    const val PROTOCOL_VERSION: Byte = 0x01

    const val TYPE_MESSAGE: Byte = 0x01
    const val TYPE_ACK: Byte = 0x02
    const val TYPE_PRESENCE: Byte = 0x03

    /** Hop limit del gossip protocol. Il routing arriva in Fase 5. */
    const val DEFAULT_TTL = 3

    // --- MTU ---------------------------------------------------------------

    /** Richiesta di MTU; il valore effettivo e quello che il peer concede. */
    const val MTU_REQUEST = 512

    /** MTU tipico prima della negoziazione. */
    const val MTU_DEFAULT = 185

    // --- Tempi della radio -------------------------------------------------

    /** Duty cycle dello scan: risparmio batteria durante un volo lungo. */
    const val SCAN_WINDOW_MS = 10_000L
    const val SCAN_PAUSE_MS = 5_000L

    /** Backoff esponenziale del reconnect: 1s, 2s, 4s, 8s, 16s, poi fisso a 30s. */
    const val RECONNECT_BASE_MS = 1_000L
    const val RECONNECT_MAX_MS = 30_000L

    /** Il payload di advertising BLE ha 31 byte: il nome va troncato. */
    const val ADVERTISED_NAME_MAX_CHARS = 8

    /** Nodi massimi per gruppo, come da architettura del progetto. */
    const val MAX_GROUP_SIZE = 30
}
