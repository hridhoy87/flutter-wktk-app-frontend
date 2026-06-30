package my.hobby.walkie_talkie.oprp

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Flutter Plugin for WalkieTalkie Remote Protocol (WTRP).
 * Exposes PTT events to the Flutter application.
 */
class WtrpPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    
    private var pttInputSource: PttInputSource? = null

    companion object {
        private var instance: WtrpPlugin? = null
        
        fun emitEvent(event: PttEvent) {
            instance?.eventSink?.success(event.name.lowercase())
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        instance = this
        methodChannel = MethodChannel(binding.binaryMessenger, "com.example.walkie_talkie/wtrp_methods")
        methodChannel.setMethodCallHandler(this)
        
        eventChannel = EventChannel(binding.binaryMessenger, "com.example.walkie_talkie/wtrp_events")
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })

        // Initialize the BLE input source
        pttInputSource = BleInputSource(binding.applicationContext).apply {
            onEvent = { event ->
                emitEvent(event)
            }
            // start() // REMOVED: Do not start scanning automatically on attach to avoid crash
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getProtocolVersion" -> result.success("1.0")
            "startScanning" -> {
                pttInputSource?.start()
                result.success(null)
            }
            "stopScanning" -> {
                pttInputSource?.stop()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        instance = null
        pttInputSource?.dispose()
        pttInputSource = null
    }
}
