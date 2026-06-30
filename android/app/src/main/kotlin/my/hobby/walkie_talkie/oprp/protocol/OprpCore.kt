package my.hobby.walkie_talkie.oprp.protocol

import java.util.UUID

/**
 * Constants used by the OpenPTT Remote Protocol.
 */
object OprpConstants {
    /**
     * The primary BLE Service UUID for OPRP.
     */
    val SERVICE_UUID: UUID = UUID.fromString("3e995977-9f67-42f1-939e-97ba61959700")
    
    /**
     * The BLE Characteristic UUID for OPRP packet transmission.
     */
    val CHARACTERISTIC_UUID: UUID = UUID.fromString("3e995977-9f67-42f1-939e-97ba61959701")
    
    /**
     * Current protocol version.
     */
    const val PROTOCOL_VERSION: Byte = 0x01
}

/**
 * Command identifiers for OPRP.
 */
enum class OprpCommand(val code: Byte) {
    PTT_PRESS(0x01),
    PTT_RELEASE(0x02),
    HEARTBEAT(0x03),
    BATTERY_LEVEL(0x04),
    DEVICE_INFORMATION(0x05),
    PING(0x06),
    PONG(0x07),
    KEEP_ALIVE(0x08),
    ERROR(0x09);

    companion object {
        fun fromCode(code: Byte): OprpCommand? = values().find { it.code == code }
    }
}

/**
 * Represents a single OPRP packet.
 * 
 * Packet Layout:
 * [Version] [Command] [Payload Length] [Payload...] [CRC8]
 */
data class OprpPacket(
    val version: Byte = OprpConstants.PROTOCOL_VERSION,
    val command: OprpCommand,
    val payload: ByteArray = byteArrayOf()
) {
    /**
     * Serializes the packet into a byte array for transmission.
     */
    fun toByteArray(): ByteArray {
        val packet = mutableListOf<Byte>()
        packet.add(version)
        packet.add(command.code)
        packet.add(payload.size.toByte())
        packet.addAll(payload.toList())
        
        val crc = Crc8.calculate(packet.toByteArray())
        packet.add(crc)
        
        return packet.toByteArray()
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is OprpPacket) return false
        if (version != other.version) return false
        if (command != other.command) return false
        if (!payload.contentEquals(other.payload)) return false
        return true
    }

    override fun hashCode(): Int {
        var result = version.toInt()
        result = 31 * result + command.hashCode()
        result = 31 * result + payload.contentHashCode()
        return result
    }

    companion object {
        /**
         * Parses a byte array into an OprpPacket.
         * Validates version, length, and CRC8.
         * @return OprpPacket if valid, null otherwise.
         */
        fun parse(data: ByteArray): OprpPacket? {
            if (data.size < 4) return null
            
            val version = data[0]
            val commandCode = data[1]
            val length = data[2].toInt() and 0xFF
            
            if (data.size != length + 4) return null
            
            val payload = data.sliceArray(3 until 3 + length)
            val receivedCrc = data.last()
            
            val dataForCrc = data.sliceArray(0 until data.size - 1)
            if (Crc8.calculate(dataForCrc) != receivedCrc) return null
            
            val command = OprpCommand.fromCode(commandCode) ?: return null
            
            return OprpPacket(version, command, payload)
        }
    }
}

object Crc8 {
    fun calculate(data: ByteArray): Byte {
        var crc = 0x00
        for (b in data) {
            crc = crc xor (b.toInt() and 0xFF)
            for (i in 0 until 8) {
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
