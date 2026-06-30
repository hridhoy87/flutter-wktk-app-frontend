# WalkieTalkie Remote Protocol (WTRP) v1.0 - FINAL

WTRP is a production-grade, transport-independent protocol for remote Push-To-Talk control. Version 1.0 is now **frozen**.

## Status
- **Protocol Version**: 1.0 (Frozen)
- **Compliance**: RFC-style specification implemented.
- **Handshake**: 3-way handshake (HELLO -> HELLO_ACK -> READY) implemented.
- **Latency**: < 20ms target validated in design.

## Documentation
- [**WTRP v1.0 Specification**](./WTRP_v1_Specification.md) - Final Technical Spec.
- [**WTRP Architecture**](./WTRP_Architecture.md) - System design and sequence diagrams.
- [**Migration Guide**](./Migration_Notes_OPRP_to_WTRP.md) - From OPRP to WTRP v1.0.

## Reference Code
- **WtrpCore.kt**: Unified packet parser and constants.
- **WtrpPacketTest.kt**: Comprehensive unit tests for the protocol logic.
- **Host (Android)**: `BleInputSource.kt` with session management and handshake.
- **Peripheral (Wear OS)**: `BlePeripheralManager.kt` with advertising and handshake.

## Integration Note
The Flutter application consumes WTRP events via the `WtrpService` which communicates with the `WtrpPlugin` on the Android side. The native side handles all protocol state (handshake, sequence validation, safety release) and emits only high-level `pressed`/`released` events to Flutter.
