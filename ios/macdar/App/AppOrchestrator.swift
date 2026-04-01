import Foundation
import Combine

enum RadarSurface: String, CaseIterable, Identifiable {
    case radar = "Radar"
    case diagnostics = "Diagnostics"

    var id: String { rawValue }
}

enum RenderQualityMode: String {
    case full = "FULL"
    case interaction = "FAST"
}

@MainActor
final class AppOrchestrator: ObservableObject {
    @Published var activeSurface: RadarSurface = .radar
    @Published var renderQuality: RenderQualityMode = .full
    @Published var interactionScale: Double = 1.0

    var renderScaleLabel: String {
        let percentage = Int((interactionScale * 100.0).rounded())
        return "\(renderQuality.rawValue) \(percentage)%"
    }

    var engineSummary: String {
        "Live Level II radar"
    }

    func setInteractionRendering(active: Bool, scale: Double) {
        renderQuality = active ? .interaction : .full
        interactionScale = scale
    }
}
