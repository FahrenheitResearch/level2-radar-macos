import SwiftUI

struct ArchiveLoopView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    private var archive: RadarArchiveStatus? {
        appState.archiveStatus
    }

    var body: some View {
        ZStack {
            radarChromeBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    if let archive, archive.active {
                        activeLoopCard(archive)
                    } else {
                        introCard
                    }

                    presetSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
        }
        .onAppear {
            appState.syncFromEngine()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("LOOP ARCHIVE")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.4)
                    .foregroundColor(radarChromeAccent.opacity(0.86))
                Text("Radar playback")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }

            Spacer()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(radarChromePanelEdge.opacity(0.7), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var introCard: some View {
        sectionCard(
            title: "START A LOOP",
            subtitle: "Load one of the built-in archive events to scrub, play, and inspect radar frames on iPhone."
        ) {
            Text("Archive playback keeps the same radar shell active while the engine downloads and decodes a preset Level II range in the background.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white.opacity(0.72))
        }
    }

    private func activeLoopCard(_ archive: RadarArchiveStatus) -> some View {
        sectionCard(
            title: archive.loading ? "DOWNLOADING" : "ACTIVE LOOP",
            subtitle: archive.label.isEmpty ? "Archive playback" : archive.label
        ) {
            statRow(label: "Station", value: archive.station.isEmpty ? appState.activeStationName : archive.station)
            statRow(label: "Frame", value: archive.frameTimestamp.isEmpty ? "Pending" : radarTimestampLabel(archive.frameTimestamp))
            statRow(label: "Status", value: archiveStatusText(archive))

            if archive.loading {
                let progress = archive.totalFrames > 0
                    ? Double(archive.downloadedFrames) / Double(max(archive.totalFrames, 1))
                    : 0.0

                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(value: progress)
                        .tint(radarChromeAccent)
                    Text("\(archive.downloadedFrames) of \(max(archive.totalFrames, 0)) frames ready")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.62))
                }
            }

            if !archive.errorMessage.isEmpty {
                Text(archive.errorMessage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(red: 1.0, green: 0.55, blue: 0.46))
            }

            if archive.loaded && archive.totalFrames > 0 {
                HStack(spacing: 10) {
                    actionButton(title: archive.playing ? "PAUSE" : "PLAY") {
                        appState.engine.toggleArchivePlayback()
                        appState.syncFromEngine()
                    }

                    actionButton(title: "LIVE") {
                        appState.engine.returnToLiveRadar()
                        appState.syncFromEngine()
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("SPEED")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(1.0)
                            .foregroundColor(.white.opacity(0.56))
                        Spacer()
                        Text("\(Int(archive.playbackFPS.rounded())) FPS")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }

                    Slider(value: playbackSpeedBinding(for: archive), in: 1...15, step: 1)
                        .tint(radarChromeAccent)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("FRAME")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .tracking(1.0)
                            .foregroundColor(.white.opacity(0.56))
                        Spacer()
                        Text("\(archive.currentFrame + 1) / \(max(archive.totalFrames, 1))")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                    }

                    Slider(value: archiveFrameBinding(for: archive),
                           in: 0...Double(max(archive.totalFrames - 1, 0)),
                           step: 1)
                        .tint(radarChromeWarm)
                }
            }
        }
    }

    private var presetSection: some View {
        sectionCard(
            title: "PRESET EVENTS",
            subtitle: "Quick-start archive loops tuned for storm-scale playback."
        ) {
            LazyVStack(spacing: 10) {
                ForEach(Array(appState.historicEvents.enumerated()), id: \.offset) { index, event in
                    eventRow(index: index, event: event)
                }
            }
        }
    }

    private func eventRow(index: Int, event: RadarHistoricEventInfo) -> some View {
        let isActive = archive?.active == true && archive?.label == event.name

        return Button(action: {
            appState.engine.loadHistoricEvent(Int32(index))
            appState.syncFromEngine()
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    Text(event.station)
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)

                    if isActive {
                        Text("ACTIVE")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .tracking(1.0)
                            .foregroundColor(radarChromeWarm)
                    }

                    Spacer(minLength: 0)

                    Text(formattedEventDate(event))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.58))
                }

                Text(event.name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Text(event.eventDescription)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.64))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(formattedWindow(event))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(radarChromeAccent.opacity(0.82))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isActive ? radarChromeAccent.opacity(0.16) : Color.black.opacity(0.18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(isActive ? radarChromeAccent.opacity(0.9) : radarChromePanelEdge.opacity(0.68),
                                    lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func sectionCard<Content: View>(title: String,
                                            subtitle: String,
                                            @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(radarChromeWarm.opacity(0.82))
                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.56))
            }

            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(radarChromePanel.opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(radarChromePanelEdge.opacity(0.78), lineWidth: 1)
                )
        )
    }

    private func statRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(1.0)
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 80, alignment: .leading)

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            Spacer(minLength: 0)
        }
    }

    private func actionButton(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .tracking(1.0)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
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

    private func playbackSpeedBinding(for archive: RadarArchiveStatus) -> Binding<Double> {
        Binding(
            get: { Double(appState.archiveStatus?.playbackFPS ?? archive.playbackFPS) },
            set: { newValue in
                appState.engine.setArchivePlaybackSpeed(Float(newValue))
                appState.syncFromEngine()
            }
        )
    }

    private func archiveFrameBinding(for archive: RadarArchiveStatus) -> Binding<Double> {
        Binding(
            get: { Double(appState.archiveStatus?.currentFrame ?? archive.currentFrame) },
            set: { newValue in
                appState.engine.setArchivePlaying(false)
                appState.engine.setArchiveFrame(Int32(newValue.rounded()))
                appState.syncFromEngine()
            }
        )
    }

    private func archiveStatusText(_ archive: RadarArchiveStatus) -> String {
        if archive.loading {
            return "Downloading"
        }
        return archive.playing ? "Playing" : "Paused"
    }

    private func formattedEventDate(_ event: RadarHistoricEventInfo) -> String {
        String(format: "%04d-%02d-%02d", event.year, event.month, event.day)
    }

    private func formattedWindow(_ event: RadarHistoricEventInfo) -> String {
        String(format: "%02d:%02d-%02d:%02d UTC",
               event.startHour, event.startMinute,
               event.endHour, event.endMinute)
    }
}
