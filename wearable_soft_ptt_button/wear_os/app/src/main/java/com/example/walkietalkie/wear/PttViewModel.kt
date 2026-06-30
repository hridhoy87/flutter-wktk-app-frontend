package com.example.walkietalkie.wear

import android.app.Application
import android.content.Context
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

class PttViewModel(application: Application) : AndroidViewModel(application) {
    private val bleManager = BlePeripheralManager(application)
    private val vibrator = application.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator

    val connectionState: StateFlow<BleConnectionState> = bleManager.connectionState
    
    private val _isPressed = MutableStateFlow(false)
    val isPressed: StateFlow<Boolean> = _isPressed

    init {
        bleManager.start()
    }

    fun togglePtt(pressed: Boolean) {
        if (_isPressed.value == pressed) return
        
        _isPressed.value = pressed
        bleManager.sendPttEvent(pressed)
        
        if (pressed) {
            vibrate(50)
        } else {
            vibrate(20)
        }
    }

    private fun vibrate(duration: Long) {
        if (vibrator.hasVibrator()) {
            vibrator.vibrate(VibrationEffect.createOneShot(duration, VibrationEffect.DEFAULT_AMPLITUDE))
        }
    }
}
