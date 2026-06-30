package com.example.walkietalkie.wear

import android.annotation.SuppressLint
import android.bluetooth.*
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.os.ParcelUuid
import android.util.Log
import com.example.walkietalkie.wear.protocol.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlin.random.Random

@SuppressLint("MissingPermission")
class BlePeripheralManager(private val context: Context) {
    private val TAG = "WTRP_Peripheral"

    private val bluetoothManager: BluetoothManager by lazy {
        context.getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
    }

    private val bluetoothAdapter: BluetoothAdapter? by lazy {
        bluetoothManager.adapter
    }

    private var bluetoothGattServer: BluetoothGattServer? = null
    private var bluetoothLeAdvertiser: BluetoothLeAdvertiser? = null
    private var connectedDevice: BluetoothDevice? = null

    // Session State
    private var currentSessionId: Byte = 0
    private var nextSequenceNumber: Int = 0
    private var isReady = false

    private val _connectionState = MutableStateFlow(BleConnectionState.DISCONNECTED)
    val connectionState: StateFlow<BleConnectionState> = _connectionState

    private val gattServerCallback = object : BluetoothGattServerCallback() {
        override fun onConnectionStateChange(device: BluetoothDevice, status: Int, newState: Int) {
            if (newState == BluetoothProfile.STATE_CONNECTED) {
                Log.d(TAG, "Host connected: ${device.address}")
                connectedDevice = device
                _connectionState.value = BleConnectionState.CONNECTED
                resetAndStartHandshake()
                stopAdvertising()
            } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                Log.d(TAG, "Host disconnected")
                connectedDevice = null
                isReady = false
                _connectionState.value = BleConnectionState.DISCONNECTED
                startAdvertising()
            }
        }

        override fun onCharacteristicWriteRequest(
            device: BluetoothDevice,
            requestId: Int,
            characteristic: BluetoothGattCharacteristic,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray
        ) {
            val packet = WtrpPacket.parse(value)
            if (packet?.command == WtrpCommand.HELLO_ACK) {
                Log.i(TAG, "Received HELLO_ACK. Sending READY.")
                sendReady()
            }
            if (responseNeeded) {
                bluetoothGattServer?.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, 0, null)
            }
        }
    }

    private fun resetAndStartHandshake() {
        currentSessionId = Random.nextInt(1, 255).toByte()
        nextSequenceNumber = 0
        isReady = false
        
        // Send HELLO
        // Payload: [ManufacturerID (2b)][HW_Version (1b)][SW_Version (1b)][AuthChallenge (4b)]
        val payload = ByteArray(8)
        val hello = WtrpPacket(
            deviceId = WtrpConstants.CAT_WEAR_OS,
            command = WtrpCommand.HELLO,
            sessionId = currentSessionId,
            sequenceNumber = (nextSequenceNumber++ % 256).toByte(),
            payload = payload
        )
        notifyHost(hello)
    }

    private fun sendReady() {
        val ready = WtrpPacket(
            deviceId = WtrpConstants.CAT_WEAR_OS,
            command = WtrpCommand.READY,
            sessionId = currentSessionId,
            sequenceNumber = (nextSequenceNumber++ % 256).toByte()
        )
        notifyHost(ready)
        isReady = true
    }

    private fun notifyHost(packet: WtrpPacket) {
        val device = connectedDevice ?: return
        val gattServer = bluetoothGattServer ?: return
        val data = packet.toByteArray()
        val characteristic = gattServer.getService(WtrpConstants.SERVICE_UUID)
            ?.getCharacteristic(WtrpConstants.CHARACTERISTIC_UUID)
            
        if (characteristic != null) {
            characteristic.value = data
            gattServer.notifyCharacteristicChanged(device, characteristic, false)
        }
    }

    fun sendPttEvent(pressed: Boolean) {
        if (!isReady) {
            Log.w(TAG, "Cannot send PTT: Handshake not complete.")
            return
        }
        val command = if (pressed) WtrpCommand.PTT_PRESS else WtrpCommand.PTT_RELEASE
        val packet = WtrpPacket(
            deviceId = WtrpConstants.CAT_WEAR_OS,
            command = command,
            sessionId = currentSessionId,
            sequenceNumber = (nextSequenceNumber++ % 256).toByte()
        )
        notifyHost(packet)
    }

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings) {
            _connectionState.value = BleConnectionState.ADVERTISING
        }
    }

    fun start() {
        setupGattServer()
        startAdvertising()
    }

    private fun setupGattServer() {
        bluetoothGattServer = bluetoothManager.openGattServer(context, gattServerCallback)
        val service = BluetoothGattService(WtrpConstants.SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)
        val characteristic = BluetoothGattCharacteristic(
            WtrpConstants.CHARACTERISTIC_UUID,
            BluetoothGattCharacteristic.PROPERTY_NOTIFY or BluetoothGattCharacteristic.PROPERTY_WRITE or BluetoothGattCharacteristic.PROPERTY_READ,
            BluetoothGattCharacteristic.PERMISSION_WRITE or BluetoothGattCharacteristic.PERMISSION_READ
        )
        service.addCharacteristic(characteristic)
        bluetoothGattServer?.addService(service)
    }

    private fun startAdvertising() {
        bluetoothLeAdvertiser = bluetoothAdapter?.bluetoothLeAdvertiser
        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setConnectable(true)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .build()
        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(true)
            .addServiceUuid(ParcelUuid(WtrpConstants.SERVICE_UUID))
            .build()
        bluetoothLeAdvertiser?.startAdvertising(settings, data, advertiseCallback)
    }

    private fun stopAdvertising() {
        bluetoothLeAdvertiser?.stopAdvertising(advertiseCallback)
    }
}
