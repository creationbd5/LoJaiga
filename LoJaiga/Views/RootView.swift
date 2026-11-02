import SwiftUI

struct RootView: View {
    @State private var tab = 0
    var body: some View {
        TabView(selection: $tab) {
            HomeView(goto: { tab = $0 }).tabItem { Label("Home", systemImage: "house.fill") }.tag(0)
            OfferView().tabItem { Label("Analyze", systemImage: "checkmark.shield") }.tag(1)
            HistoryView().tabItem { Label("History", systemImage: "clock.arrow.circlepath") }.tag(2)
            VoiceView().tabItem { Label("Voice", systemImage: "mic.fill") }.tag(3)
            SettingsView().tabItem { Label("Settings", systemImage: "slider.horizontal.3") }.tag(4)
        }
        .tint(LJ.teal)
    }
}

struct HomeView: View {
    @EnvironmentObject var store: TripStore
    @EnvironmentObject var voice: VoiceCommandEngine
    let goto: (Int) -> Void

    private var today: TripStore.Stats { store.stats(since: Calendar.current.startOfDay(for: Date())) }
    private var listening: Bool { voice.mode == .listening }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Image("Logo").resizable().scaledToFit().frame(height: 170)
                    Text("Amar Boss-e Khaise Loss!")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(LJ.gold)

                    HStack(spacing: 8) {
                        Image(systemName: "hand.raised.fill").foregroundStyle(LJ.gold)
                        Text("Manual mode — Lo Jaiga is not connected to Uber")
                            .font(.footnote).foregroundStyle(LJ.secondary)
                    }
                    .padding(10).frame(maxWidth: .infinity)
                    .background(LJ.panel, in: Capsule())

                    // Voice
                    Surface {
                        VStack(spacing: 10) {
                            Button {
                                if listening { voice.stopListening() } else { voice.startListening() }
                            } label: {
                                Image(systemName: listening ? "waveform" : "mic.fill")
                                    .font(.system(size: 38))
                                    .foregroundStyle(LJ.bg)
                                    .frame(width: 92, height: 92)
                                    .background(listening ? LJ.gold : LJ.teal, in: Circle())
                                    .shadow(color: (listening ? LJ.gold : LJ.teal).opacity(0.4), radius: 14)
                            }
                            Text(listening ? "Listening — say a command" : "Tap to start voice commands")
                                .font(.headline).foregroundStyle(LJ.gold)
                            Text(voice.heard.isEmpty ? "e.g. “Lo Jaiga”, “Baad Dey”, “Koi Jamu”" : voice.heard)
                                .font(.footnote).foregroundStyle(LJ.secondary).multilineTextAlignment(.center)
                            if let msg = voice.permissionMessage {
                                Text(msg).font(.footnote).foregroundStyle(LJ.coral).multilineTextAlignment(.center)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }

                    // Quick actions
                    HStack(spacing: 10) {
                        tile("Analyze", "checkmark.shield") { goto(1) }
                        tile("History", "clock.arrow.circlepath") { goto(2) }
                        tile("Places", "mappin.and.ellipse") { goto(4) }
                    }

                    // Today
                    Surface {
                        Text("Today (trips you logged as taken)").font(.caption).foregroundStyle(LJ.secondary)
                        HStack {
                            stat("\(today.count)", "Trips")
                            Divider().frame(height: 36)
                            stat(today.fare.formatted(.currency(code: LJ.currency)), "Fares")
                            Divider().frame(height: 36)
                            stat(today.net.formatted(.currency(code: LJ.currency)), "Est. net")
                        }
                    }
                }
                .padding(18)
            }
            .background(LJ.bg)
            .navigationTitle("Lo Jaiga")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func tile(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.title2).foregroundStyle(LJ.teal)
                Text(title).font(.footnote.weight(.semibold)).foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
            .background(LJ.panel, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).foregroundStyle(LJ.mint)
                .minimumScaleFactor(0.7).lineLimit(1)
            Text(label).font(.caption2).foregroundStyle(LJ.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
