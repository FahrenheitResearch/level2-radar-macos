import SwiftUI

struct SoundingSheetView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            radarChromeBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                header

                detailCard(
                    title: "TARGET POINT",
                    subtitle: "Current cursor point captured from the radar scene."
                ) {
                    valueTile(label: "LAT", value: String(format: "%.3f", appState.cursorLat))
                    valueTile(label: "LON", value: String(format: "%.3f", appState.cursorLon))
                }

                detailCard(
                    title: "CURRENT VIEW",
                    subtitle: "Quick context for the location under your finger."
                ) {
                    pipelineLine("Station: \(appState.activeStationName)")
                    pipelineLine("Location: \(appState.activeStationDetail)")
                    pipelineLine("Scan: \(appState.activeStationScanTime)")
                    pipelineLine("Product: \(appState.productName)")
                    pipelineLine("Render: \(appState.orchestrator.renderScaleLabel)")
                }

                detailCard(
                    title: "NOTE",
                    subtitle: "Keep the selected location handy while you inspect the radar scene."
                ) {
                    pipelineLine("The current cursor coordinates stay in sync with the active radar view.")
                    pipelineLine("Use this sheet as a quick handoff for the point you want to track.")
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 28)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("POINT")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(1.4)
                    .foregroundColor(radarChromeAccent.opacity(0.86))
                Text("Selected point")
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

    private func detailCard<Content: View>(title: String,
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

    private func valueTile(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(1.0)
                .foregroundColor(.white.opacity(0.52))
                .frame(width: 84, alignment: .leading)

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            Spacer(minLength: 0)
        }
    }

    private func pipelineLine(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
