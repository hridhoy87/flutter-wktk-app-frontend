# Wearable Soft PTT Button

This project contains two native smartwatch applications (Wear OS and watchOS) that act as a Bluetooth Low Energy (BLE) Push-To-Talk remote for the WalkieTalkie phone application.

## BLE Protocol

- **Service UUID:** `A1000000-0000-1000-8000-00805F9B34FB`
- **Characteristic UUID:** `A1010000-0000-1000-8000-00805F9B34FB`
- **Payload:** 1 Byte
    - `0x01`: Pressed
    - `0x00`: Released

## Wear OS (Android)

Located in `./wear_os`.

### Implementation Details:
- **Language:** Kotlin
- **UI:** Jetpack Compose for Wear OS
- **BLE:** Android Bluetooth LE (Central)
- **Features:**
    - Auto-scanning for the phone.
    - Hold-to-talk button using `pointerInteropFilter`.
    - Haptic feedback on press and release.
    - Connection status display.

### Build Instructions:
1. Open the `./wear_os` folder in Android Studio.
2. Sync Gradle.
3. Build and run on a Wear OS device or emulator.

## watchOS (Apple Watch)

Located in `./watch_os`.

### Implementation Details:
- **Language:** Swift
- **UI:** SwiftUI
- **BLE:** Core Bluetooth (Central)
- **Features:**
    - Auto-scanning for the phone.
    - Hold-to-talk button using `DragGesture`.
    - Haptic feedback using `WKInterfaceDevice.current().play()`.
    - Connection status display.

### Build Instructions:
1. Create a new watchOS app project in Xcode named `WatchPTTRemote`.
2. Replace the source files with the ones provided in `./watch_os/WatchPTTRemote`.
3. Ensure `NSBluetoothAlwaysUsageDescription` is in your `Info.plist`.
4. Build and run on an Apple Watch.

## Reliability
Both apps implement an auto-reconnect logic. If the connection is lost while the button is pressed, the apps will attempt to send a "Released" (0x00) event upon the next successful connection to ensure the phone does not stay in a "Talking" state indefinitely.
