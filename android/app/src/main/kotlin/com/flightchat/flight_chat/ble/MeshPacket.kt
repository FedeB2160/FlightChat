// android/app/src/main/kotlin/com/flightchat/flight_chat/ble/MeshPacket.kt
// Formato binario del pacchetto mesh: serializzazione, parsing e CRC32.
package com.flightchat.flight_chat.ble

import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.UUID
import java.util.zip.CRC32

/** Pacchetto malformato: versione, lunghezze o CRC non validi. */
class MeshPacketException(message: String) : Exception(message)

/**
 * Un pacchetto mesh sul filo.
 *
 * ```
 * offset  size  campo
 * 0       1     version (0x01)
 * 1       1     type (0x01 message, 0x02 ack, 0x03 presence)
 * 2       16    message_id (UUID)
 * 18      16    sender_device_id (UUID)
 * 34      1     ttl
 * 35      4     time_delta (uint32 big-endian, secondi da t0)
 * 39      2     payload_length (uint16 big-endian)
 * 41      N     payload (ciphertext AES-256-GCM)
 * 41+N    4     crc32 di tutto cio che precede
 * ```
 *
 * DECISION: questo file non e nella lista del piano di Fase 3, ma il vincolo 9
 * richiede unit test Kotlin sulla serializzazione, quindi il formato deve vivere
 * in una classe Kotlin. Ed e Kotlin a possedere la cornice, non Dart: il
 * MeshRouter di Fase 5 e Dart e lavora sui campi, non sui byte, cosi esiste un
 * solo serializzatore invece di due da tenere allineati a mano.
 *
 * Nessun import `android.*`: il modulo non ha `testOptions`, e con il default
 * AGP qualunque classe del framework farebbe fallire i test JVM.
 */
data class MeshPacket(
    val type: Byte,
    val messageId: UUID,
    val senderDeviceId: UUID,
    /** 0..255. Il gossip che lo decrementa arriva in Fase 5. */
    val ttl: Int,
    /** uint32: secondi dal t0 del gruppo. In Long perche non entra in un Int con segno. */
    val timeDelta: Long,
    val payload: ByteArray,
    val version: Byte = BleConstants.PROTOCOL_VERSION,
) {

    fun toBytes(): ByteArray {
        require(payload.size <= BleConstants.MAX_PAYLOAD_BYTES) {
            "payload di ${payload.size} byte oltre il massimo di ${BleConstants.MAX_PAYLOAD_BYTES}"
        }
        require(ttl in 0..255) { "ttl $ttl fuori dall'intervallo 0..255" }
        require(timeDelta in 0..UINT32_MAX) { "timeDelta $timeDelta fuori da uint32" }

        val size = BleConstants.HEADER_BYTES + payload.size + BleConstants.CRC_BYTES
        val buffer = ByteBuffer.allocate(size).order(ByteOrder.BIG_ENDIAN)

        buffer.put(version)
        buffer.put(type)
        buffer.putUuid(messageId)
        buffer.putUuid(senderDeviceId)
        buffer.put(ttl.toByte())
        buffer.putInt(timeDelta.toInt())
        buffer.putShort(payload.size.toShort())
        buffer.put(payload)

        val bytes = buffer.array()
        val crc = crc32(bytes, BleConstants.HEADER_BYTES + payload.size)
        buffer.putInt(crc.toInt())

        return bytes
    }

    // Il data class confronterebbe `payload` per riferimento.

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is MeshPacket) return false
        return type == other.type &&
            messageId == other.messageId &&
            senderDeviceId == other.senderDeviceId &&
            ttl == other.ttl &&
            timeDelta == other.timeDelta &&
            version == other.version &&
            payload.contentEquals(other.payload)
    }

    override fun hashCode(): Int {
        var result = type.toInt()
        result = 31 * result + messageId.hashCode()
        result = 31 * result + senderDeviceId.hashCode()
        result = 31 * result + ttl
        result = 31 * result + timeDelta.hashCode()
        result = 31 * result + version
        result = 31 * result + payload.contentHashCode()
        return result
    }

    companion object {
        private const val UINT32_MAX = 0xFFFFFFFFL
        private const val MIN_PACKET_BYTES = BleConstants.HEADER_BYTES + BleConstants.CRC_BYTES

        private val KNOWN_TYPES = setOf(
            BleConstants.TYPE_MESSAGE,
            BleConstants.TYPE_ACK,
            BleConstants.TYPE_PRESENCE,
        )

        /**
         * Parsa un pacchetto ricevuto dalla radio.
         *
         * Rifiuta con [MeshPacketException] tutto cio che non torna: un pacchetto
         * corrotto va scartato, non interpretato a meta.
         */
        fun fromBytes(bytes: ByteArray): MeshPacket {
            if (bytes.size < MIN_PACKET_BYTES) {
                throw MeshPacketException(
                    "pacchetto di ${bytes.size} byte, minimo $MIN_PACKET_BYTES"
                )
            }

            val buffer = ByteBuffer.wrap(bytes).order(ByteOrder.BIG_ENDIAN)

            val version = buffer.get()
            if (version != BleConstants.PROTOCOL_VERSION) {
                throw MeshPacketException("versione di protocollo $version non supportata")
            }

            val type = buffer.get()
            if (type !in KNOWN_TYPES) {
                throw MeshPacketException("tipo di pacchetto $type sconosciuto")
            }

            val messageId = buffer.getUuid()
            val senderDeviceId = buffer.getUuid()
            val ttl = buffer.get().toInt() and 0xFF
            val timeDelta = buffer.int.toLong() and UINT32_MAX
            val payloadLength = buffer.short.toInt() and 0xFFFF

            if (payloadLength > BleConstants.MAX_PAYLOAD_BYTES) {
                throw MeshPacketException(
                    "payload_length $payloadLength oltre il massimo di ${BleConstants.MAX_PAYLOAD_BYTES}"
                )
            }
            val expectedSize = BleConstants.HEADER_BYTES + payloadLength + BleConstants.CRC_BYTES
            if (bytes.size != expectedSize) {
                throw MeshPacketException(
                    "payload_length $payloadLength incoerente: attesi $expectedSize byte, ricevuti ${bytes.size}"
                )
            }

            val payload = ByteArray(payloadLength)
            buffer.get(payload)

            val declaredCrc = buffer.int.toLong() and UINT32_MAX
            val actualCrc = crc32(bytes, BleConstants.HEADER_BYTES + payloadLength)
            if (declaredCrc != actualCrc) {
                throw MeshPacketException("CRC32 non corrisponde: atteso $actualCrc, dichiarato $declaredCrc")
            }

            return MeshPacket(
                type = type,
                messageId = messageId,
                senderDeviceId = senderDeviceId,
                ttl = ttl,
                timeDelta = timeDelta,
                payload = payload,
                version = version,
            )
        }

        private fun crc32(bytes: ByteArray, length: Int): Long =
            CRC32().apply { update(bytes, 0, length) }.value

        private fun ByteBuffer.putUuid(uuid: UUID): ByteBuffer =
            putLong(uuid.mostSignificantBits).putLong(uuid.leastSignificantBits)

        private fun ByteBuffer.getUuid(): UUID = UUID(long, long)
    }
}
