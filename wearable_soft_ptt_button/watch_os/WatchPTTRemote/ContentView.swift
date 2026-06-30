import SwiftUI

struct ContentView: View {
    @StateObject var viewModel = PttViewModel()

    var body: some View {
        VStack {
            Text(statusText)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(statusColor)

            Spacer()

            Circle()
                .fill(buttonColor)
                .overlay(
                    Text("PTT")
                        .font(.system(size: 30, weight: .black))
                        .foregroundColor(.white)
                )
                .frame(width: 140, height: 140)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if viewModel.bluetoothManager.connectionState == .connected {
                                viewModel.togglePtt(pressed: true)
                            }
                        }
                        .onEnded { _ in
                            viewModel.togglePtt(pressed: false)
                        }
                )

            if viewModel.bluetoothManager.connectionState != .connected {
                Text("Scan for phone...")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    private var statusText: String {
        switch viewModel.bluetoothManager.connectionState {
        case .searching: return "SEARCHING..."
        case .connecting: return "CONNECTING..."
        case .connected: return viewModel.isPressed ? "TALKING" : "READY"
        case .disconnected: return "DISCONNECTED"
        }
    }

    private var statusColor: Color {
        if viewModel.bluetoothManager.connectionState == .connected {
            return viewModel.isPressed ? .red : .green
        }
        return .gray
    }

    private var buttonColor: Color {
        if viewModel.bluetoothManager.connectionState == .connected {
            return viewModel.isPressed ? .red : .gray.opacity(0.3)
        }
        return .black
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
