package com.openptt.protocol

import org.junit.Assert.*
import org.junit.Test

class OprpPacketTest {

    @Test
    fun testSerializationAndParsing() {
        val original = OprpPacket(command = OprpCommand.PTT_PRESS)
        val bytes = original.toByteArray()
        
        // Expected: [0x01, 0x01, 0x00, CRC]
        assertEquals(4, bytes.size)
        assertEquals(0x01.toByte(), bytes[0]) // Version
        assertEquals(0x01.toByte(), bytes[1]) // Command PTT_PRESS
        assertEquals(0x00.toByte(), bytes[2]) // Length
        
        val parsed = OprpPacket.parse(bytes)
        assertNotNull(parsed)
        assertEquals(original, parsed)
    }

    @Test
    fun testWithPayload() {
        val payload = byteArrayOf(0xDE.toByte(), 0xAD.toByte(), 0xBE.toByte(), 0xEF.toByte())
        val original = OprpPacket(command = OprpCommand.DEVICE_INFORMATION, payload = payload)
        val bytes = original.toByteArray()
        
        assertEquals(4 + 4, bytes.size)
        assertEquals(4.toByte(), bytes[2]) // Length 4
        
        val parsed = OprpPacket.parse(bytes)
        assertNotNull(parsed)
        assertEquals(original, parsed)
        assertArrayEquals(payload, parsed?.payload)
    }

    @Test
    fun testInvalidCrc() {
        val original = OprpPacket(command = OprpCommand.PTT_PRESS)
        val bytes = original.toByteArray()
        
        // Corrupt the CRC
        bytes[bytes.size - 1] = (bytes[bytes.size - 1] + 1).toByte()
        
        val parsed = OprpPacket.parse(bytes)
        assertNull(parsed)
    }

    @Test
    fun testInvalidLength() {
        val bytes = byteArrayOf(0x01, 0x01, 0x05, 0x01, 0x02, 0x03) // Length says 5, but only 3 bytes + header
        val parsed = OprpPacket.parse(bytes)
        assertNull(parsed)
    }
}
