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
            LiveMonitorView().tabItem { Label("Live OCR", systemImage: "viewfinder") }.tag(5)
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
                VStack(spacing: 18) {
                    // Use a second named image set to avoid collision with a root-level
                    // project folder named Logo, and render with an explicit fixed frame.
                    VStack(spacing: 6) {
                        Image("BrandMascot")
                            .resizable().scaledToFit()
                            .frame(maxWidth: 270).frame(height: 230)
                            .accessibilityLabel("Lo Jaiga smiling driver mascot")
                        Text("Amar Boss-e Khaise Loss!")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(LJ.gold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)

                    HStack(spacing: 9) {
                        Image(systemName: "shield.lefthalf.filled")
                            .foregroundStyle(LJ.gold)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("MANUAL TEST MODE")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .tracking(1.1).foregroundStyle(LJ.gold)
                            Text("Not connected to Uber Driver. Import screenshots to analyze offers.")
                                .font(.system(size: 13)).foregroundStyle(LJ.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(15)
                    .background(LJ.panel, in: RoundedRectangle(cornerRadius: 17))

                    Surface {
                        HStack {
                            VStack(alignment: .leading, spacing: 7) {
                                Text("TODAY'S LOGGED FARES").font(.system(size: 11, weight: .semibold)).tracking(1).foregroundStyle(LJ.secondary)
                                Text(today.fare, format: .currency(code: LJ.currency))
                                    .font(.system(size: 38, weight: .bold, design: .rounded)).foregroundStyle(LJ.mint)
                                    .minimumScaleFactor(0.6).lineLimit(1)
                                Text("Estimated net " + today.net.formatted(.currency(code: LJ.currency)))
                                    .font(.footnote).foregroundStyle(LJ.secondary)
                            }
                            Spacer(minLength: 8)
                            VStack(spacing: 3) {
                                Text("\(today.count)").font(.system(size: 30, weight: .bold, design: .rounded))
                                Text("Trips logged").font(.caption2).foregroundStyle(LJ.secondary)
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        actionTile("Analyze offer", "viewfinder", subtitle: "OCR screenshot", color: LJ.teal) { goto(1) }
                        actionTile("Trip history", "clock.arrow.circlepath", subtitle: "Saved on phone", color: LJ.mint) { goto(2) }
                    }
                    HStack(spacing: 10) {
                        actionTile("Voice commands", "mic.fill", subtitle: listening ? "Listening" : "Tap to start", color: LJ.gold) { goto(3) }
                        actionTile("Places & rules", "mappin.and.ellipse", subtitle: "Match filters", color: LJ.teal) { goto(4) }
                    }

                    Surface {
                        HStack(spacing: 12) {
                            Image(systemName: "waveform")
                                .font(.system(size: 25, weight: .medium)).foregroundStyle(LJ.teal)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("VOICE ASSISTANT").font(.caption.weight(.bold)).foregroundStyle(LJ.secondary)
                                Text(listening ? "Listening for your words" : "Voice commands paused")
                                    .font(.headline)
                                Text(voice.heard.isEmpty ? "Lo Jaiga • Baad Dey • Koi Jamu" : voice.heard)
                                    .font(.caption).foregroundStyle(LJ.secondary)
                            }
                            Spacer(minLength: 0)
                            Button {
                                if listening { voice.stopListening() } else { voice.startListening() }
                            } label: {
                                Image(systemName: listening ? "stop.fill" : "mic.fill")
                                    .font(.title3).foregroundStyle(LJ.bg)
                                    .frame(width: 48, height: 48)
                                    .background(LJ.teal, in: Circle())
                            }
                            .accessibilityLabel(listening ? "Stop voice listening" : "Start voice listening")
                        }
                        if let msg = voice.permissionMessage {
                            Text(msg).font(.footnote).foregroundStyle(LJ.coral)
                        }
                    }
                    Text("Drive safely. Analyze offers and change settings only while parked.")
                        .font(.caption).foregroundStyle(LJ.secondary).multilineTextAlignment(.center)
                }
                .padding(18)
            }
            .background(LJ.bg)
            .navigationTitle("Lo Jaiga")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func actionTile(_ title: String, _ symbol: String, subtitle: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: symbol).font(.system(size: 24)).foregroundStyle(color)
                Text(title).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                Text(subtitle).font(.caption).foregroundStyle(LJ.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 95, alignment: .leading)
            .padding(15)
            .background(LJ.panel, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}
