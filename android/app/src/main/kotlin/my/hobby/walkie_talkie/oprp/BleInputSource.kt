package my.hobby.walkie_talkie.oprp

import android.annotation.SuppressLint
import android.bluetooth.*
import android.bluetooth.le.*
import android.content.Context
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.util.Log
import my.hobby.walkie_talkie.oprp.protocol.*

@SuppressLint("MissingPermission")
class BleInputSource(private val context: Context) : PttInputSource {
    private val TAG = "WTRP_Host"
    
    override var onEvent: ((PttEvent) -> Unit)? = null
    
    private val bluetoothManager: BluetoothManager by lazy {
        context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    }
    
    private val bluetoothAdapter: BluetoothAdapter? by lazy {
        bluetoothManager.adapter
    }
    
    private var bluetoothGatt: BluetoothGatt? = null
    private val handler = Handler(Looper.getMainLooper())
    private var isRunning = false
    
    // Handshake State
    private enum class HandshakeState { IDLE, HELLO_RECEIVED, READY }
    private var handshakeState = HandshakeState.IDLE
    
    // Session Tracking
    private var currentSessionId: Byte = 0
    private var lastSequenceNumber: Int = -1
    private var lastEmittedEvent: PttEvent? = null

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            Log.d(TAG, "Device discovered: ${result.device.address}")
            stopScan()
            connectToDevice(result.device)
        }
    }

    private val gattCallback = object : BluetoothGattCallback() {
        override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                Log.i(TAG, "GATT Connected. Discovering services...")
                gatt.discoverServices()
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                Log.w(TAG, "GATT Disconnected.")
                handleDisconnect()
                if (isRunning) handler.postDelayed({ startScan() }, 3000)
            }
        }

        override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                val service = gatt.getService(WtrpConstants.SERVICE_UUID)
                val characteristic = service?.getCharacteristic(WtrpConstants.CHARACTERISTIC_UUID)
                
                if (characteristic != null) {
                    Log.d(TAG, "WTRP Characteristic found. Enabling notifications.")
                    gatt.setCharacteristicNotification(characteristic, true)
                    
                    val descriptor = characteristic.getDescriptor(
                        java.util.UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")
                    )
                    if (descriptor != null) {
                        descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                        gatt.writeDescriptor(descriptor)
                    }
                }
            }
        }

        override fun onCharacteristicChanged(gatt: BluetoothGatt, characteristic: BluetoothGattCharacteristic) {
            val data = characteristic.value ?: return
            val packet = WtrpPacket.parse(data) ?: return
            processIncomingPacket(packet)
        }
    }

    private fun processIncomingPacket(packet: WtrpPacket) {
        // Handshake Logic
        when (packet.command) {
            WtrpCommand.HELLO -> {
                Log.i(TAG, "Received HELLO from Device ${packet.deviceId}. Starting Handshake.")
                currentSessionId = packet.sessionId
                lastSequenceNumber = packet.sequenceNumber.toInt() and 0xFF
                handshakeState = HandshakeState.HELLO_RECEIVED
                sendHelloAck(packet)
                return
            }
            WtrpCommand.READY -> {
                Log.i(TAG, "Received READY. Handshake complete.")
                handshakeState = HandshakeState.READY
                return
            }
            else -> {}
        }

        // Operational Logic
        if (handshakeState != HandshakeState.READY) {
            Log.w(TAG, "Discarding packet: Handshake not complete.")
            return
        }

        if (packet.sessionId != currentSessionId) {
            Log.w(TAG, "Discarding packet: Session mismatch (Expected $currentSessionId, Got ${packet.sessionId})")
            return
        }

        val seq = packet.sequenceNumber.toInt() and 0xFF
        if (!isNewSequence(seq)) return
        lastSequenceNumber = seq

        when (packet.command) {
            WtrpCommand.PTT_PRESS -> emitEvent(PttEvent.PRESSED)
            WtrpCommand.PTT_RELEASE -> emitEvent(PttEvent.RELEASED)
            WtrpCommand.HEARTBEAT -> Log.d(TAG, "Heartbeat from ${packet.deviceId}")
            else -> Log.d(TAG, "Unhandled command: ${packet.command}")
        }
    }

    private fun isNewSequence(seq: Int): Boolean {
        val diff = (seq - lastSequenceNumber + 256) % 256
        return diff in 1..127 // Valid range for new packets
    }

    private fun sendHelloAck(helloPacket: WtrpPacket) {
        val gatt = bluetoothGatt ?: return
        val service = gatt.getService(WtrpConstants.SERVICE_UUID)
        val char = service?.getCharacteristic(WtrpConstants.CHARACTERISTIC_UUID) ?: return

        // Payload: [AuthResponse (4b)][Capabilities (2b)]
        val payload = ByteArray(6) // Auth placeholders
        val ack = WtrpPacket(
            deviceId = WtrpConstants.CAT_COMPANION_APP,
            command = WtrpCommand.HELLO_ACK,
            sessionId = currentSessionId,
            sequenceNumber = 0,
            payload = payload
        )

        char.value = ack.toByteArray()
        gatt.writeCharacteristic(char)
    }

    private fun emitEvent(event: PttEvent) {
        if (lastEmittedEvent == event) return
        lastEmittedEvent = event
        onEvent?.invoke(event)
    }

    private fun handleDisconnect() {
        if (lastEmittedEvent == PttEvent.PRESSED) emitEvent(PttEvent.RELEASED)
        handshakeState = HandshakeState.IDLE
        bluetoothGatt?.close()
        bluetoothGatt = null
        lastSequenceNumber = -1
    }

    override fun start() {
        if (isRunning) return
        isRunning = true
        startScan()
    }

    override fun stop() {
        isRunning = false
        stopScan()
        bluetoothGatt?.disconnect()
    }

    override fun dispose() {
        stop()
        onEvent = null
    }

    private fun startScan() {
        val scanner = bluetoothAdapter?.bluetoothLeScanner ?: return
        val filter = ScanFilter.Builder()
            .setServiceUuid(ParcelUuid(WtrpConstants.SERVICE_UUID))
            .build()
        val settings = ScanSettings.Builder()
            .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
            .build()
        
        Log.d(TAG, "Scanning for WTRP peripherals...")
        scanner.startScan(listOf(filter), settings, scanCallback)
    }

    private fun stopScan() {
        bluetoothAdapter?.bluetoothLeScanner?.stopScan(scanCallback)
    }

    private fun connectToDevice(device: BluetoothDevice) {
        bluetoothGatt = device.connectGatt(context, false, gattCallback)
    }
}
