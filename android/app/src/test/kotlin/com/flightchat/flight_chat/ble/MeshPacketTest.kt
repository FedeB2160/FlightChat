// android/app/src/test/kotlin/com/flightchat/flight_chat/ble/MeshPacketTest.kt
// Unit test JVM sulla serializzazione del pacchetto mesh (vincolo 9 di Fase 3).
package com.flightchat.flight_chat.ble

import java.util.UUID
import java.util.zip.CRC32
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertThrows
import org.junit.Test

class MeshPacketTest {

    private val messageId: UUID = UUID.fromString("11223344-5566-7788-99aa-bbccddeeff00")
    private val senderId: UUID = UUID.fromString("01234567-89ab-cdef-fedc-ba9876543210")

    private fun packet(
        payload: ByteArray = byteArrayOf(1, 2, 3),
        ttl: Int = BleConstants.DEFAULT_TTL,
        timeDelta: Long = 134,
        type: Byte = BleConstants.TYPE_MESSAGE,
    ) = MeshPacket(
        type = type,
        messageId = messageId,
        senderDeviceId = senderId,
        ttl = ttl,
        timeDelta = timeDelta,
        payload = payload,
    )

    // --- round-trip --------------------------------------------------------

    @Test
    fun `round trip preserves every field`() {
        val content = "Ciao dal volo AZ1234".toByteArray()
        val restored = MeshPacket.fromBytes(packet(payload = content).toBytes())

        assertEquals(BleConstants.PROTOCOL_VERSION, restored.version)
        assertEquals(BleConstants.TYPE_MESSAGE, restored.type)
        assertEquals(messageId, restored.messageId)
        assertEquals(senderId, restored.senderDeviceId)
        assertEquals(BleConstants.DEFAULT_TTL, restored.ttl)
        assertEquals(134L, restored.timeDelta)
        assertArrayEquals(content, restored.payload)
    }

    @Test
    fun `round trip works for every known type`() {
        val types = listOf(
            BleConstants.TYPE_MESSAGE,
            BleConstants.TYPE_ACK,
            BleConstants.TYPE_PRESENCE,
        )
        for (type in types) {
            assertEquals(type, MeshPacket.fromBytes(packet(type = type).toBytes()).type)
        }
    }

    @Test
    fun `total size is header plus payload plus crc`() {
        val bytes = packet(payload = ByteArray(100)).toBytes()
        assertEquals(BleConstants.HEADER_BYTES + 100 + BleConstants.CRC_BYTES, bytes.size)
    }

    // --- layout esatto sul filo -------------------------------------------
    // Confronti contro byte attesi scritti a mano, non contro il round-trip:
    // un round-trip passerebbe anche con l'endianness invertita su entrambi i lati.

    @Test
    fun `version and type sit at offsets zero and one`() {
        val bytes = packet(type = BleConstants.TYPE_ACK).toBytes()
        assertEquals(BleConstants.PROTOCOL_VERSION, bytes[0])
        assertEquals(BleConstants.TYPE_ACK, bytes[1])
    }

    @Test
    fun `uuids are written most significant byte first`() {
        val bytes = packet().toBytes()

        // messageId = 11223344-5566-7788-99aa-bbccddeeff00
        assertArrayEquals(
            byteArrayOf(
                0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88.toByte(),
                0x99.toByte(), 0xaa.toByte(), 0xbb.toByte(), 0xcc.toByte(),
                0xdd.toByte(), 0xee.toByte(), 0xff.toByte(), 0x00,
            ),
            bytes.copyOfRange(2, 18),
        )

        // senderDeviceId = 01234567-89ab-cdef-fedc-ba9876543210
        assertArrayEquals(
            byteArrayOf(
                0x01, 0x23, 0x45, 0x67, 0x89.toByte(), 0xab.toByte(), 0xcd.toByte(), 0xef.toByte(),
                0xfe.toByte(), 0xdc.toByte(), 0xba.toByte(), 0x98.toByte(),
                0x76, 0x54, 0x32, 0x10,
            ),
            bytes.copyOfRange(18, 34),
        )
    }

    @Test
    fun `ttl sits at offset thirtyfour`() {
        assertEquals(7.toByte(), packet(ttl = 7).toBytes()[34])
    }

    @Test
    fun `time delta is big endian`() {
        // 0x01020304 deve comparire in quest'ordine, non invertito.
        val bytes = packet(timeDelta = 0x01020304L).toBytes()
        assertEquals(0x01.toByte(), bytes[35])
        assertEquals(0x02.toByte(), bytes[36])
        assertEquals(0x03.toByte(), bytes[37])
        assertEquals(0x04.toByte(), bytes[38])
    }

    @Test
    fun `payload length is big endian`() {
        // 258 = 0x0102
        val bytes = packet(payload = ByteArray(258)).toBytes()
        assertEquals(0x01.toByte(), bytes[39])
        assertEquals(0x02.toByte(), bytes[40])
    }

    @Test
    fun `crc is the last four bytes and covers everything before it`() {
        val bytes = packet(payload = byteArrayOf(4, 5, 6)).toBytes()
        val covered = bytes.size - BleConstants.CRC_BYTES
        val expected = CRC32().apply { update(bytes, 0, covered) }.value

        val declared = ((bytes[covered].toLong() and 0xFF) shl 24) or
            ((bytes[covered + 1].toLong() and 0xFF) shl 16) or
            ((bytes[covered + 2].toLong() and 0xFF) shl 8) or
            (bytes[covered + 3].toLong() and 0xFF)

        assertEquals(expected, declared)
    }

    // --- limiti ------------------------------------------------------------

    @Test
    fun `empty payload is valid`() {
        assertEquals(0, MeshPacket.fromBytes(packet(payload = ByteArray(0)).toBytes()).payload.size)
    }

    @Test
    fun `payload at the exact maximum fills the packet`() {
        val max = ByteArray(BleConstants.MAX_PAYLOAD_BYTES) { it.toByte() }
        val bytes = packet(payload = max).toBytes()

        assertEquals(BleConstants.MAX_PACKET_BYTES, bytes.size)
        assertArrayEquals(max, MeshPacket.fromBytes(bytes).payload)
    }

    @Test
    fun `payload over the maximum is refused when serializing`() {
        val tooBig = ByteArray(BleConstants.MAX_PAYLOAD_BYTES + 1)
        assertThrows(IllegalArgumentException::class.java) { packet(payload = tooBig).toBytes() }
    }

    @Test
    fun `ttl accepts both extremes`() {
        assertEquals(0, MeshPacket.fromBytes(packet(ttl = 0).toBytes()).ttl)
        // 255 non deve tornare come -1: il byte va riletto senza segno.
        assertEquals(255, MeshPacket.fromBytes(packet(ttl = 255).toBytes()).ttl)
    }

    @Test
    fun `time delta accepts the top of uint32`() {
        // Non deve diventare negativo passando per un Int con segno.
        val top = 0xFFFFFFFFL
        assertEquals(top, MeshPacket.fromBytes(packet(timeDelta = top).toBytes()).timeDelta)
    }

    // --- rifiuti -----------------------------------------------------------

    @Test
    fun `crc detects a single flipped bit in the payload`() {
        val bytes = packet(payload = "messaggio integro".toByteArray()).toBytes()
        val target = BleConstants.HEADER_BYTES
        bytes[target] = (bytes[target].toInt() xor 0x01).toByte()

        assertThrows(MeshPacketException::class.java) { MeshPacket.fromBytes(bytes) }
    }

    @Test
    fun `crc detects a flipped bit in the header`() {
        val bytes = packet().toBytes()
        bytes[34] = (bytes[34].toInt() xor 0x01).toByte() // ttl
        assertThrows(MeshPacketException::class.java) { MeshPacket.fromBytes(bytes) }
    }

    @Test
    fun `unknown protocol version is refused`() {
        val bytes = packet().toBytes()
        bytes[0] = 0x02
        recomputeCrc(bytes)
        assertThrows(MeshPacketException::class.java) { MeshPacket.fromBytes(bytes) }
    }

    @Test
    fun `unknown packet type is refused`() {
        val bytes = packet().toBytes()
        bytes[1] = 0x7F
        recomputeCrc(bytes)
        assertThrows(MeshPacketException::class.java) { MeshPacket.fromBytes(bytes) }
    }

    @Test
    fun `buffer shorter than header plus crc is refused`() {
        assertThrows(MeshPacketException::class.java) { MeshPacket.fromBytes(ByteArray(10)) }
        assertThrows(MeshPacketException::class.java) {
            MeshPacket.fromBytes(ByteArray(BleConstants.HEADER_BYTES + BleConstants.CRC_BYTES - 1))
        }
    }

    @Test
    fun `truncated packet is refused`() {
        val bytes = packet(payload = ByteArray(50)).toBytes()
        assertThrows(MeshPacketException::class.java) {
            MeshPacket.fromBytes(bytes.copyOfRange(0, bytes.size - 5))
        }
    }

    @Test
    fun `payload length inconsistent with the buffer is refused`() {
        val bytes = packet(payload = ByteArray(10)).toBytes()
        // Dichiara 20 byte di payload in un buffer che ne contiene 10.
        bytes[39] = 0x00
        bytes[40] = 20
        recomputeCrc(bytes)

        assertThrows(MeshPacketException::class.java) { MeshPacket.fromBytes(bytes) }
    }

    @Test
    fun `payload length over the maximum is refused`() {
        val bytes = packet(payload = ByteArray(10)).toBytes()
        val over = BleConstants.MAX_PAYLOAD_BYTES + 1
        bytes[39] = (over shr 8).toByte()
        bytes[40] = (over and 0xFF).toByte()
        recomputeCrc(bytes)

        assertThrows(MeshPacketException::class.java) { MeshPacket.fromBytes(bytes) }
    }

    // --- equals ------------------------------------------------------------

    @Test
    fun `equality compares the payload by content not by reference`() {
        val a = packet(payload = byteArrayOf(1, 2, 3))
        val b = packet(payload = byteArrayOf(1, 2, 3))
        val c = packet(payload = byteArrayOf(1, 2, 4))

        assertEquals(a, b)
        assertEquals(a.hashCode(), b.hashCode())
        assertNotEquals(a, c)
    }

    /**
     * Ricalcola il CRC dopo aver manomesso l'header, cosi il test verifica il
     * controllo che gli interessa invece di inciampare su quello del CRC.
     * La dimensione del buffer non cambia mai in questi test.
     */
    private fun recomputeCrc(bytes: ByteArray) {
        val covered = bytes.size - BleConstants.CRC_BYTES
        val crc = CRC32().apply { update(bytes, 0, covered) }.value
        bytes[covered] = (crc shr 24).toByte()
        bytes[covered + 1] = (crc shr 16).toByte()
        bytes[covered + 2] = (crc shr 8).toByte()
        bytes[covered + 3] = crc.toByte()
    }
}
