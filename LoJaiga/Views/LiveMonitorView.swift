import SwiftUI
import ReplayKit
import UserNotifications

struct LiveMonitorView: View {
    @State private var permissionStatus = "Notification permission not checked"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 52))
                        .foregroundStyle(.mint)
                    Text("Live OCR Test")
                        .font(.title2.bold())
                    Text("EXPERIMENTAL: Start a screen broadcast, select Lo Jaiga Broadcast, then switch to Uber Driver. Offer detection and notifications are not guaranteed on this unsigned test build.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                    BroadcastPicker()
                        .frame(width: 68, height: 68)
                    Text("Tap the broadcast button and choose Lo Jaiga Broadcast")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                    Button("Allow Offer Notifications") {
                        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
                            DispatchQueue.main.async {
                                permissionStatus = error?.localizedDescription ?? (granted ? "Notifications allowed" : "Notifications disabled")
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    Text(permissionStatus).font(.caption).foregroundStyle(.secondary)
                    Label("No screenshot, video, or full OCR text is stored", systemImage: "lock.shield")
                        .font(.caption).foregroundStyle(.mint)
                    Text("This first test only notifies that a candidate offer/fare was recognized. Good/Bad rules and reliable delivery are NOT connected yet. No Uber button is clicked.")
                        .font(.footnote).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
            }
            .navigationTitle("Broadcast Test")
        }
    }
}

private struct BroadcastPicker: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 68, height: 68))
        picker.preferredExtension = "com.lojaiga.app.broadcast"
        picker.showsMicrophoneButton = false
        return picker
    }
    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}
