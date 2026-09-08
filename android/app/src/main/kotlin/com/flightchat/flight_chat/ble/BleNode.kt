// android/app/src/main/kotlin/com/flightchat/flight_chat/ble/BleNode.kt
// Nodo della mesh visto da questo dispositivo.
package com.flightchat.flight_chat.ble

/**
 * Un nodo con cui esiste o e esistita una connessione GATT.
 *
 * `deviceId`, `nickname` e `groupIdHash` arrivano dalla caratteristica NODE_INFO
 * e restano nulli finche non e stata letta: un nodo appena scoperto e noto solo
 * per il suo indirizzo BLE.
 *
 * Nessun import `android.*`, cosi la classe resta leggibile dagli unit test JVM.
 */
data class BleNode(
    /** Indirizzo hardware BLE. Chiave di identita finche NODE_INFO non risponde. */
    val address: String,
    val deviceId: String? = null,
    val nickname: String? = null,
    /** Hash del groupId dichiarato dal nodo. Non identifica il gruppo di un pacchetto: quello lo fa la decifratura. */
    val groupIdHash: String? = null,
    val rssi: Int? = null,
    val mtu: Int = BleConstants.MTU_DEFAULT,
) {
    /** Mappa per il Method Channel verso Flutter. */
    fun toMap(): Map<String, Any?> = mapOf(
        "address" to address,
        "deviceId" to deviceId,
        "nickname" to nickname,
        "groupIdHash" to groupIdHash,
        "rssi" to rssi,
        "mtu" to mtu,
    )
}
