import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            radarChromeBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    metricGrid

                    sectionCard(
                        title: "DATA",
                        subtitle: "The app is tuned for fast single-station radar viewing with a clean local scene."
                    ) {
                        pipelineRow(label: "Radar source", value: "NEXRAD Level II")
                        pipelineRow(label: "Display", value: appState.productName)
                        pipelineRow(label: "Station", value: appState.activeStationName)
                        pipelineRow(label: "Location", value: appState.activeStationDetail)
                        pipelineRow(label: "Scan", value: appState.activeStationScanTime)
                        pipelineRow(label: "Downloads", value: "\(appState.stationsDownloading)")
                    }

                    sectionCard(
                        title: "SCENE",
                        subtitle: "Quick details for the current view and tap point."
                    ) {
                        pipelineRow(label: "Station", value: appState.activeStationName)
                        pipelineRow(label: "Cursor", value: formattedLatLon(appState.cursorLat, appState.cursorLon))
                        pipelineRow(label: "Render quality", value: appState.orchestrator.renderScaleLabel)
                        pipelineRow(label: "Center", value: formattedLatLon(appState.centerLat, appState.centerLon))
                        if let archive = appState.archiveStatus, archive.active {
                            pipelineRow(label: "Archive", value: archive.label.isEmpty ? "Active loop" : archive.label)
                        }
                    }

                    sectionCard(
                        title: "STATION SIGNAL",
                        subtitle: "Engine-backed health and severe-weather feature counts for the active site."
                    ) {
                        pipelineRow(label: "Sweeps", value: "\(appState.activeStationSweepCount)")
                        pipelineRow(label: "Lowest tilt", value: String(format: "%.1f°", appState.activeStationLowestElevation))
                        pipelineRow(label: "TDS", value: "\(appState.activeStationTDSCount)")
                        pipelineRow(label: "Hail", value: "\(appState.activeStationHailCount)")
                        pipelineRow(label: "Meso", value: "\(appState.activeStationMesoCount)")
                        pipelineRow(label: "Warnings", value: "\(appState.warningCount)")
                        if !appState.activeStationErrorMessage.isEmpty {
                            pipelineRow(label: "Status", value: appState.activeStationErrorMessage)
                        }
                    }

                    sectionCard(
                        title: "PIPELINE",
                        subtitle: "Stage timings from the live single-radar runtime."
                    ) {
                        pipelineRow(label: "Decode", value: stageMs(appState.activeStationDecodeMs))
                        pipelineRow(label: "Parse", value: stageMs(appState.activeStationParseMs))
                        pipelineRow(label: "Sweep build", value: stageMs(appState.activeStationSweepBuildMs))
                        pipelineRow(label: "Preprocess", value: stageMs(appState.activeStationPreprocessMs))
                        pipelineRow(label: "Detect", value: stageMs(appState.activeStationDetectionMs))
                        pipelineRow(label: "Upload", value: stageMs(appState.activeStationUploadMs))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("DIAGNOSTICS")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.4)
                    .foregroundColor(radarChromeAccent.opacity(0.86))
                Text("Radar overview")
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

    private var metricGrid: some View {
        let metrics = [
            ("QUALITY", appState.orchestrator.renderQuality.rawValue),
            ("SCALE", "\(Int((appState.orchestrator.interactionScale * 100).rounded()))%"),
            ("SWEEPS", "\(appState.activeStationSweepCount)"),
            ("WARN", "\(appState.warningCount)")
        ]

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(metrics, id: \.0) { metric in
                VStack(alignment: .leading, spacing: 4) {
                    Text(metric.0)
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .tracking(1.1)
                        .foregroundColor(.white.opacity(0.56))
                    Text(metric.1)
                        .font(.system(size: 18, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(radarChromePanel.opacity(0.96))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(radarChromePanelEdge.opacity(0.78), lineWidth: 1)
                        )
                )
            }
        }
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

    private func pipelineRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(1.0)
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 112, alignment: .leading)

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            Spacer(minLength: 0)
        }
    }

    private func formattedLatLon(_ lat: Double, _ lon: Double) -> String {
        String(format: "%.3f, %.3f", lat, lon)
    }

    private func stageMs(_ value: Float) -> String {
        value > 0 ? String(format: "%.1f ms", value) : "—"
    }
}
