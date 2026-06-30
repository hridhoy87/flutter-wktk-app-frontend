package my.hobby.walkie_talkie.oprp.protocol

import org.junit.Assert.*
import org.junit.Test

class WtrpPacketTest {

    @Test
    fun testSerializationAndParsing() {
        val original = WtrpPacket(
            deviceId = WtrpConstants.CAT_WEAR_OS,
            command = WtrpCommand.PTT_PRESS,
            sessionId = 0xAB.toByte(),
            sequenceNumber = 123.toByte()
        )
        val bytes = original.toByteArray()
        
        assertEquals(7, bytes.size)
        assertEquals(WtrpConstants.PROTOCOL_VERSION, bytes[0])
        assertEquals(WtrpConstants.CAT_WEAR_OS, bytes[1])
        assertEquals(WtrpCommand.PTT_PRESS.code, bytes[2])
        assertEquals(0xAB.toByte(), bytes[3])
        assertEquals(123.toByte(), bytes[4])
        assertEquals(0.toByte(), bytes[5])
        
        val parsed = WtrpPacket.parse(bytes)
        assertNotNull(parsed)
        assertEquals(original, parsed)
    }

    @Test
    fun testHandshakeHello() {
        // Payload: [ManufacturerID(2)][HW(1)][SW(1)][Auth(4)] = 8 bytes
        val payload = ByteArray(8) { i -> i.toByte() }
        val hello = WtrpPacket(
            deviceId = WtrpConstants.CAT_EMBEDDED,
            command = WtrpCommand.HELLO,
            sessionId = 0x01.toByte(),
            sequenceNumber = 0.toByte(),
            payload = payload
        )
        
        val bytes = hello.toByteArray()
        assertEquals(7 + 8, bytes.size)
        
        val parsed = WtrpPacket.parse(bytes)
        assertNotNull(parsed)
        assertEquals(WtrpCommand.HELLO, parsed?.command)
        assertArrayEquals(payload, parsed?.payload)
    }

    @Test
    fun testInvalidCrc() {
        val packet = WtrpPacket(
            deviceId = WtrpConstants.CAT_WEAR_OS,
            command = WtrpCommand.PTT_PRESS,
            sessionId = 1,
            sequenceNumber = 1
        )
        val bytes = packet.toByteArray()
        bytes[bytes.size - 1] = (bytes[bytes.size - 1] + 1).toByte()
        
        val parsed = WtrpPacket.parse(bytes)
        assertNull("Packet with invalid CRC should not parse", parsed)
    }

    @Test
    fun testWrongVersion() {
        val packet = WtrpPacket(
            deviceId = WtrpConstants.CAT_WEAR_OS,
            command = WtrpCommand.PTT_PRESS,
            sessionId = 1,
            sequenceNumber = 1
        )
        val bytes = packet.toByteArray()
        bytes[0] = 0x99.toByte() // Wrong version
        
        val parsed = WtrpPacket.parse(bytes)
        assertNull("Packet with wrong version should not parse", parsed)
    }

    @Test
    fun testPayloadLengthMismatch() {
        val bytes = byteArrayOf(
            WtrpConstants.PROTOCOL_VERSION,
            WtrpConstants.CAT_WEAR_OS,
            WtrpCommand.PTT_PRESS.code,
            0x01, 0x01, // session, seq
            0x05, // Length says 5
            0x01, 0x02, 0x03, // Only 3 bytes of payload
            0x00 // CRC placeholder
        )
        // Note: CRC will likely fail anyway, but the length check should catch it first.
        val parsed = WtrpPacket.parse(bytes)
        assertNull(parsed)
    }
}
