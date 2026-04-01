import SwiftUI

let radarChromeBackground = Color(red: 0.03, green: 0.05, blue: 0.08)
let radarChromePanel = Color(red: 0.06, green: 0.09, blue: 0.14)
let radarChromePanelEdge = Color(red: 0.18, green: 0.27, blue: 0.34)
let radarChromeAccent = Color(red: 0.32, green: 0.82, blue: 0.84)
let radarChromeWarm = Color(red: 0.97, green: 0.74, blue: 0.31)

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showStationPicker = false
    @State private var showSettings = false
    @State private var showDiagnostics = false
    @State private var showLoop = false
    @State private var showSounding = false

    private var quickAccessStations: [RadarStationInfo] {
        var seen = Set<String>()
        let stations = (appState.favoriteStations + appState.recentStations).filter { station in
            guard station.icao != appState.activeStationName else { return false }
            guard !seen.contains(station.icao) else { return false }
            seen.insert(station.icao)
            return true
        }
        return Array(stations.prefix(4))
    }

    var body: some View {
        ZStack {
            RadarMapView()
                .ignoresSafeArea()

            LinearGradient(
                colors: [Color.black.opacity(0.0), radarChromeBackground.opacity(0.78)],
                startPoint: .center,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                topHud
                Spacer()
                bottomDock
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 14)
        }
        .background(radarChromeBackground)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showStationPicker) {
            StationPickerSheet()
                .environmentObject(appState)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(appState)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showDiagnostics) {
            DiagnosticsView()
                .environmentObject(appState)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showLoop) {
            ArchiveLoopView()
                .environmentObject(appState)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(28)
        }
        .sheet(isPresented: $showSounding) {
            SoundingSheetView()
                .environmentObject(appState)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(28)
        }
    }

    private var topHud: some View {
        HStack(alignment: .top, spacing: 12) {
            HStack(spacing: 8) {
                Button(action: { showStationPicker = true }) {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(radarChromeAccent)
                                .frame(width: 8, height: 8)
                            Text(appState.activeStationName)
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }

                        Text(appState.activeStationDetail)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white.opacity(0.64))

                        Text(appState.activeStationScanTime.uppercased())
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(1.0)
                            .foregroundColor(radarChromeAccent.opacity(0.88))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(chromePanel(fill: radarChromePanel.opacity(0.92)))
                }
                .buttonStyle(.plain)

                if appState.activeStationInfo != nil {
                    chromeIconButton(symbol: appState.activeStationInfo.map { appState.isFavorite($0) } == true ? "star.fill" : "star") {
                        appState.toggleFavoriteCurrentStation()
                    }
                }
            }

            VStack(spacing: 8) {
                metricTile(label: "WARN", value: "\(appState.warningCount)")
                metricTile(label: "DL", value: "\(appState.stationsDownloading)")
            }

            VStack(spacing: 8) {
                chromeIconButton(symbol: "arrow.clockwise") {
                    appState.engine.refreshData()
                }
                chromeIconButton(symbol: "slider.horizontal.3") {
                    showSettings = true
                }
            }
        }
    }

    private var bottomDock: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let archive = appState.archiveStatus, archive.active {
                archiveStrip(archive)
            }

            if appState.archiveStatus?.active != true,
               let liveLoop = appState.liveLoopStatus,
               liveLoop.enabled,
               (liveLoop.loading || liveLoop.availableFrames > 0) {
                liveLoopStrip(liveLoop)
            }

            HStack(alignment: .center, spacing: 10) {
                compactProductBadge
                if appState.maxTilts > 1 {
                    TiltControlView()
                }
            }

            ProductPickerView()
            controlStrip
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(chromePanel(fill: radarChromePanel.opacity(0.9)))
    }

    private var controlStrip: some View {
        HStack(spacing: 8) {
            inlineBadge(label: "QUAL", value: appState.orchestrator.renderQuality.rawValue)
            inlineBadge(label: "SWEEPS", value: "\(appState.activeStationSweepCount)")

            Spacer(minLength: 0)

            chromeTextButton(title: "ARCHIVE") {
                showLoop = true
            }
            chromeTextButton(title: "INFO") {
                showDiagnostics = true
            }
            chromeTextButton(title: "POINT") {
                showSounding = true
            }
        }
    }

    private var compactProductBadge: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("PRODUCT")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(1.2)
                .foregroundColor(radarChromeWarm.opacity(0.88))

            Text(appState.productName)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(radarChromeWarm.opacity(0.35), lineWidth: 1)
                )
        )
    }

    private func archiveStrip(_ archive: RadarArchiveStatus) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("ARCHIVE LOOP")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(radarChromeWarm.opacity(0.9))

                Text(archive.label.isEmpty ? "Preset archive playback" : archive.label)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(archiveStatusLine(archive))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.62))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            chromeTextButton(title: archive.playing ? "PAUSE" : "PLAY") {
                appState.engine.toggleArchivePlayback()
                appState.syncFromEngine()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(radarChromeWarm.opacity(0.35), lineWidth: 1)
                )
        )
    }

    private func archiveStatusLine(_ archive: RadarArchiveStatus) -> String {
        if archive.loading {
            if archive.totalFrames > 0 {
                return "LOADING \(archive.downloadedFrames)/\(archive.totalFrames)"
            }
            return "LOADING"
        }

        let frameLabel = archive.frameTimestamp.isEmpty ? "FRAME --:--:--" : "FRAME \(archive.frameTimestamp)"
        let modeLabel = archive.playing ? "PLAYING" : "PAUSED"
        return "\(modeLabel)  \(frameLabel)"
    }

    private func liveLoopStrip(_ liveLoop: RadarLiveLoopStatus) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("LIVE LOOP")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(radarChromeWarm.opacity(0.9))

                Text(liveLoopLabel(liveLoop))
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(liveLoopStatusLine(liveLoop))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.62))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            chromeTextButton(title: liveLoop.playing ? "PAUSE" : "PLAY") {
                appState.engine.toggleLiveLoopPlayback()
                appState.syncFromEngine()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.22))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(radarChromeWarm.opacity(0.35), lineWidth: 1)
                )
        )
    }

    private func liveLoopLabel(_ liveLoop: RadarLiveLoopStatus) -> String {
        if liveLoop.viewingHistory && !liveLoop.label.isEmpty {
            return radarTimestampLabel(liveLoop.label)
        }
        if liveLoop.availableFrames > 0 {
            return "Realtime playback"
        }
        return "Building recent frames"
    }

    private func liveLoopStatusLine(_ liveLoop: RadarLiveLoopStatus) -> String {
        if liveLoop.loading {
            let frameCount = max(liveLoop.availableFrames, 0)
            return "BACKFILLING \(frameCount)/8"
        }

        let modeLabel = liveLoop.playing ? "PLAYING" : "READY"
        let frameCount = max(liveLoop.availableFrames, 0)
        return "\(modeLabel)  \(frameCount) FRAMES"
    }

    private func metricTile(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(1.2)
                .foregroundColor(.white.opacity(0.56))
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .frame(width: 72, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(radarChromePanelEdge.opacity(0.7), lineWidth: 1)
                )
        )
    }

    private func chromeIconButton(symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.black.opacity(0.24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(radarChromePanelEdge.opacity(0.75), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func chromeTextButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(1.0)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.black.opacity(0.24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(radarChromePanelEdge.opacity(0.75), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private func signalPill(label: String, value: Int, tint: Color) -> some View {
        Text("\(label) \(value)")
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .tracking(0.9)
            .foregroundColor(tint)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.14))
            )
    }

    private func inlineBadge(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .tracking(1.0)
                .foregroundColor(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(radarChromePanelEdge.opacity(0.66), lineWidth: 1)
                )
        )
    }

    private func chromePanel(fill: Color) -> some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(radarChromePanelEdge.opacity(0.82), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.22), radius: 18, x: 0, y: 10)
    }
}
