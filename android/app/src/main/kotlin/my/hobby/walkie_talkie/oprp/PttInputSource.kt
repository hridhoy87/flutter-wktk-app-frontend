package my.hobby.walkie_talkie.oprp

/**
 * High-level PTT events emitted by any WTRP-compatible input source.
 */
enum class PttEvent {
    PRESSED,
    RELEASED
}

/**
 * Hardware-independent abstraction for PTT input devices.
 */
interface PttInputSource {
    /**
     * Start listening for input events.
     */
    fun start()

    /**
     * Stop listening for input events.
     */
    fun stop()

    /**
     * Clean up resources.
     */
    fun dispose()
    
    /**
     * Callback for PTT events. 
     * Implementations must ensure no duplicate events are emitted.
     */
    var onEvent: ((PttEvent) -> Unit)?
}
