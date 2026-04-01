import SwiftUI

struct ProductPickerView: View {
    @EnvironmentObject var appState: AppState

    let products = [
        (0, "REF", "Reflectivity"),
        (1, "VEL", "Velocity"),
        (2, "SW", "Spectrum Width"),
        (3, "ZDR", "Diff. Reflectivity"),
        (4, "CC", "Correlation Coeff"),
        (5, "KDP", "Specific Diff Phase"),
        (6, "PHI", "Diff. Phase"),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(products, id: \.0) { idx, short, long in
                    let isActive = appState.activeProduct == idx
                    Button(action: { appState.setProduct(idx) }) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(short)
                                .font(.system(size: 15, weight: .bold, design: .monospaced))
                            Text(long.uppercased())
                                .font(.system(size: 7, weight: .black, design: .monospaced))
                                .tracking(0.8)
                                .lineLimit(1)
                                .opacity(isActive ? 0.62 : 0.0)
                        }
                        .foregroundColor(isActive ? .white : .white.opacity(0.82))
                        .frame(width: 94, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(isActive ? radarChromeAccent.opacity(0.22) : Color.black.opacity(0.18))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(isActive ? radarChromeAccent.opacity(0.9) : radarChromePanelEdge.opacity(0.65),
                                                lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }
}
