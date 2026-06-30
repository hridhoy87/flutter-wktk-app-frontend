package my.hobby.walkie_talkie.oprp

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

class PttForegroundService : Service() {
    private val TAG = "PttForegroundService"
    private lateinit var bleInputSource: BleInputSource

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "Starting PTT Foreground Service")
        
        bleInputSource = BleInputSource(this)
        bleInputSource.onEvent = { event ->
            Log.i(TAG, "PTT Event: $event")
            broadcastPttEvent(event)
        }
        
        startForeground(NOTIFICATION_ID, createNotification())
        bleInputSource.start()
    }

    private fun broadcastPttEvent(event: PttEvent) {
        val intent = Intent("my.hobby.walkie_talkie.PTT_EVENT")
        intent.putExtra("event", event.name)
        sendBroadcast(intent)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        return START_STICKY
    }

    override fun onDestroy() {
        Log.d(TAG, "Stopping PTT Foreground Service")
        bleInputSource.dispose()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotification(): Notification {
        val channelId = "ptt_service_channel"
        val channelName = "PTT Remote Service"
        val manager = getSystemService(NotificationManager::class.java)
        
        if (manager != null && manager.getNotificationChannel(channelId) == null) {
            val channel = NotificationChannel(channelId, channelName, NotificationManager.IMPORTANCE_LOW)
            manager.createNotificationChannel(channel)
        }

        return NotificationCompat.Builder(this, channelId)
            .setContentTitle("OPRP Active")
            .setContentText("Listening for PTT remote...")
            .setSmallIcon(android.R.drawable.stat_sys_data_bluetooth)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    companion object {
        private const val NOTIFICATION_ID = 101
    }
}
