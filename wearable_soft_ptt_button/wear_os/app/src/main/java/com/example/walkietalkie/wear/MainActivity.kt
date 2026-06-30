package com.example.walkietalkie.wear

import android.os.Bundle
import android.view.MotionEvent
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.input.pointer.pointerInteropFilter
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.wear.compose.material.*

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            PttApp()
        }
    }
}

@OptIn(ExperimentalComposeUiApi::class)
@Composable
fun PttApp() {
    val viewModel: PttViewModel = viewModel()
    val connectionState by viewModel.connectionState.collectAsState()
    val isPressed by viewModel.isPressed.collectAsState()

    MaterialTheme {
        Scaffold(
            modifier = Modifier.fillMaxSize()
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .background(Color.Black),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                Text(
                    text = when (connectionState) {
                        BleConnectionState.SEARCHING -> "SEARCHING..."
                        BleConnectionState.CONNECTING -> "CONNECTING..."
                        BleConnectionState.CONNECTED -> if (isPressed) "TALKING" else "READY"
                        BleConnectionState.DISCONNECTED -> "DISCONNECTED"
                    },
                    color = when (connectionState) {
                        BleConnectionState.CONNECTED -> if (isPressed) Color.Red else Color.Green
                        else -> Color.Gray
                    },
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Bold
                )

                Spacer(modifier = Modifier.height(8.dp))

                Box(
                    modifier = Modifier
                        .size(140.dp)
                        .background(
                            color = if (connectionState == BleConnectionState.CONNECTED) {
                                if (isPressed) Color.Red else Color.DarkGray
                            } else {
                                Color.Black
                            },
                            shape = CircleShape
                        )
                        .pointerInteropFilter {
                            if (connectionState != BleConnectionState.CONNECTED) return@pointerInteropFilter false
                            when (it.action) {
                                MotionEvent.ACTION_DOWN -> {
                                    viewModel.togglePtt(true)
                                    true
                                }
                                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                                    viewModel.togglePtt(false)
                                    true
                                }
                                else -> false
                            }
                        },
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "PTT",
                        color = Color.White,
                        fontSize = 32.sp,
                        fontWeight = FontWeight.Black
                    )
                }
                
                if (connectionState != BleConnectionState.CONNECTED) {
                    Text(
                        text = "Scan for phone...",
                        color = Color.LightGray,
                        fontSize = 10.sp,
                        modifier = Modifier.padding(top = 8.dp)
                    )
                }
            }
        }
    }
}
