import Foundation
import WatchKit
import SwiftUI

class PttViewModel: ObservableObject {
    @Published var bluetoothManager = BluetoothManager()
    @Published var isPressed: Bool = false

    func togglePtt(pressed: Bool) {
        if isPressed == pressed { return }
        isPressed = pressed
        bluetoothManager.sendPttEvent(pressed: pressed)

        if pressed {
            WKInterfaceDevice.current().play(.directionUp)
        } else {
            WKInterfaceDevice.current().play(.directionDown)
        }
    }
}
