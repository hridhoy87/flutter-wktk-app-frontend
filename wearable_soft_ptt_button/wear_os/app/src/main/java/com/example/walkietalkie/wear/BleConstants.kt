package com.example.walkietalkie.wear

import java.util.UUID

object BleConstants {
    val SERVICE_UUID: UUID = UUID.fromString("A1000000-0000-1000-8000-00805F9B34FB")
    val CHARACTERISTIC_UUID: UUID = UUID.fromString("A1010000-0000-1000-8000-00805F9B34FB")
    
    const val VALUE_RELEASED: Byte = 0x00
    const val VALUE_PRESSED: Byte = 0x01
}
