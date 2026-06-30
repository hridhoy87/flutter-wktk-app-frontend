package com.example.walkietalkie.wear.protocol

import java.util.UUID

/**
 * WalkieTalkie Remote Protocol (WTRP) v1.0 - FINAL (Peripheral Side)
 */
object WtrpConstants {
    val SERVICE_UUID: UUID = UUID.fromString("3e995977-9f67-42f1-939e-97ba61959700")
    val CHARACTERISTIC_UUID: UUID = UUID.fromString("3e995977-9f67-42f1-939e-97ba61959701")
    
    const val PROTOCOL_VERSION: Byte = 0x01

    // Device Category IDs
    const val CAT_WEAR_OS: Byte = 0x01
    const val CAT_ZEPP_OS: Byte = 0x02
    const val CAT_EMBEDDED: Byte = 0x03
    
    // Manufacturer IDs
    const val MAN_REFERENCE: Short = 0x0001
    const val MAN_WALKIETALKIE: Short = 0x0002
}

/**
 * WTRP v1.0 Commands
 */
enum class WtrpCommand(val code: Byte) {
    PTT_PRESS(0x01),
    PTT_RELEASE(0x02),
    HELLO(0x03),
    HELLO_ACK(0x04),
    READY(0x05),
    HEARTBEAT(0x06),
    ERROR(0x09),
    
    // Reserved
    DOUBLE_PRESS(0x10),
    LONG_PRESS(0x11),
    UNKNOWN(0x00);

    companion object {
        fun fromCode(code: Byte): WtrpCommand = values().find { it.code == code } ?: UNKNOWN
    }
}

/**
 * WTRP Packet Representation
 */
data class WtrpPacket(
    val version: Byte = WtrpConstants.PROTOCOL_VERSION,
    val deviceId: Byte,
    val command: WtrpCommand,
    val sessionId: Byte,
    val sequenceNumber: Byte,
    val payload: ByteArray = byteArrayOf()
) {
    fun toByteArray(): ByteArray {
        val size = 7 + payload.size
        val data = ByteArray(size)
        data[0] = version
        data[1] = deviceId
        data[2] = command.code
        data[3] = sessionId
        data[4] = sequenceNumber
        data[5] = payload.size.toByte()
        System.arraycopy(payload, 0, data, 6, payload.size)
        data[size - 1] = WtrpCrc8.calculate(data, size - 1)
        return data
    }

    companion object {
        fun parse(data: ByteArray): WtrpPacket? {
            if (data.size < 7) return null
            if (data[0] != WtrpConstants.PROTOCOL_VERSION) return null
            val payloadLen = data[5].toInt() and 0xFF
            if (data.size != 7 + payloadLen) return null
            val receivedCrc = data.last()
            if (WtrpCrc8.calculate(data, data.size - 1) != receivedCrc) return null
            return WtrpPacket(
                version = data[0],
                deviceId = data[1],
                command = WtrpCommand.fromCode(data[2]),
                sessionId = data[3],
                sequenceNumber = data[4],
                payload = data.sliceArray(6 until 6 + payloadLen)
            )
        }
    }
}

object WtrpCrc8 {
    fun calculate(data: ByteArray, length: Int): Byte {
        var crc = 0x00
        for (i in 0 until length) {
            crc = crc xor (data[i].toInt() and 0xFF)
            for (j in 0 until 8) {
                if (crc and 0x80 != 0) {
                    crc = (crc shl 1) xor 0x07
                } else {
                    crc = crc shl 1
                }
            }
        }
        return (crc and 0xFF).toByte()
    }
}
