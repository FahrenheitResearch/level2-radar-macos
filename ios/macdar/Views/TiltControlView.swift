import SwiftUI

struct TiltControlView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack(spacing: 8) {
            tiltButton(symbol: "minus", enabled: appState.activeTilt > 0) {
                appState.setTilt(appState.activeTilt - 1)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("TILT")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .tracking(1.1)
                    .foregroundColor(.white.opacity(0.54))
                Text(String(format: "%.1f°", appState.tiltAngle))
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
            }
            .frame(minWidth: 78, alignment: .leading)

            tiltButton(symbol: "plus", enabled: appState.activeTilt < appState.maxTilts - 1) {
                appState.setTilt(appState.activeTilt + 1)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.2))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(radarChromePanelEdge.opacity(0.65), lineWidth: 1)
                )
        )
    }

    private func tiltButton(symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .black))
                .foregroundColor(enabled ? .white : .white.opacity(0.28))
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(enabled ? radarChromeAccent.opacity(0.18) : Color.white.opacity(0.04))
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
