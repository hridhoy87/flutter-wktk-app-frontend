# Migration Notes: OPRP v1 to WTRP v1.0

This document outlines the breaking changes and architectural improvements when moving from the initial OpenPTT Remote Protocol (OPRP) to the production-grade WalkieTalkie Remote Protocol (WTRP).

## 1. Protocol Name & Versioning
- **Old Name**: OpenPTT Remote Protocol
- **New Name**: WalkieTalkie Remote Protocol (WTRP)
- **Version**: 1.0

## 2. Packet Structure Changes
The packet header has been expanded to support device identification and session management.

| Field | OPRP (Old) | WTRP (New) | Reason |
| :--- | :--- | :--- | :--- |
| Version | Byte 0 | Byte 0 | No change |
| Device ID | - | Byte 1 | Identify hardware type (Watch, ESP32, etc.) |
| Command | Byte 1 | Byte 2 | Shifted |
| Session ID | - | Byte 3 | Prevent stale packets after reconnect |
| Seq Number | - | Byte 4 | Duplicate suppression |
| Payload Len | Byte 2 | Byte 5 | Shifted |
| Payload | Byte 3..N | Byte 6..N | Shifted |
| CRC8 | Final Byte | Final Byte | Checksum covers new fields |

## 3. Communication Pattern
- **OPRP**: Used Android Broadcast Intents for event delivery.
- **WTRP**: Uses Flutter Platform Channels (`MethodChannel` and `EventChannel`).
- **Benefit**: Cleaner decoupling, no system-wide leaking of PTT events, easier to handle in Flutter BLoCs.

## 4. Session Management
- **OPRP**: State was tied only to the physical BLE connection.
- **WTRP**: Introduced a random `Session ID`. If the connection drops and reconnects, the Session ID changes. The host discards any incoming packets carrying the old Session ID.

## 5. Sequence Numbers
- **OPRP**: No sequence tracking.
- **WTRP**: Every packet increments a sequence number. The host ignores duplicate sequence numbers to prevent multi-triggering from retries or transport-level echoes.

## 6. Commands
- Added Handshake/Negotiation commands: `HELLO`, `CAPABILITIES`, `ACK`.
- Added Reserved commands for future expansion: `DOUBLE_PRESS`, `VOLUME_UP`, `EMERGENCY`, etc.

## 7. Codebase Refactoring
- `OprpCore.kt` renamed/replaced by `WtrpCore.kt`.
- `BleInputSource` now manages sessions and sequence numbers internally.
- `WtrpPlugin` introduced as the bridge to Flutter.
- Android `MainActivity` now registers the `WtrpPlugin` directly.
