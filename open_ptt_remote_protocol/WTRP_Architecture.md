# WTRP Architecture

## System Diagram: Multiple Device Support

```mermaid
graph TD
    subgraph "WTRP Remotes (Peripherals)"
        WOS[Wear OS Watch] -- "WTRP over BLE" --> Host
        ZOS[Zepp OS Watch] -- "WTRP over BLE" --> Host
        ESP[ESP32 Button] -- "WTRP over BLE/Serial" --> Host
        USB[USB Foot Pedal] -- "WTRP over HID" --> Host
    end

    subgraph "Android Phone (Host / Central)"
        Host[WTRP Host Service]
        Host --> Transport[BLE Transport Manager]
        Transport --> Parser[WTRP Packet Parser]
        Parser --> Handshake[3-Way Handshake Manager]
        Handshake --> Session[Session & Seq Validator]
        Session --> HAL[PttInputSource Interface]
    end

    subgraph "Flutter Application"
        HAL -- "EventChannel" --> FlutterPlugin[WtrpPlugin]
        FlutterPlugin --> PttBloc[PTT Business Logic]
        PttBloc --> WebRTC[Audio Stream Manager]
    end
```

## Sequence Diagram: Finalized Handshake & PTT

```mermaid
sequenceDiagram
    participant Remote as WTRP Remote (Peripheral)
    participant Host as WTRP Host (Central)
    participant App as Flutter App

    Note over Remote, Host: BLE Connection Established
    
    Remote->>Host: HELLO (SessionID=0xAB, ManufID=0x0001, Challenge=...)
    Host->>Host: Validate Device ID & Manufacturer
    Host->>Remote: HELLO_ACK (Response=..., Capabilities=0xFFFF)
    Remote->>Remote: Verify Response
    Remote->>Host: READY
    Note over Remote, Host: Handshake Complete - Operational Mode
    
    User->>Remote: Press PTT
    Remote->>Host: PTT_PRESS (Session=0xAB, Seq=1)
    Host->>Host: Validate Session & Seq
    Host->>App: Event: 'pressed'
    
    User->>Remote: Release PTT
    Remote->>Host: PTT_RELEASE (Session=0xAB, Seq=2)
    Host->>Host: Validate Session & Seq
    Host->>App: Event: 'released'

    Note over Remote, Host: BLE Disconnect
    Host->>Host: Check State: Was Pressed?
    Host->>App: Event: 'released' (Safety Fallback)
```

## Latency Breakdown
- **Peripheral Sensing**: ~2ms
- **BLE Transmission**: ~7.5ms - 15ms (Negotiated Interval)
- **Host Parsing**: ~1ms
- **Flutter UI update**: ~2ms
- **Total**: ~12.5ms - 20ms
