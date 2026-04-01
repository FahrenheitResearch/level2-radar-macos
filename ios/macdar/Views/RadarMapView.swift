import SwiftUI
import MetalKit
import UIKit

extension Notification.Name {
    static let radarStationChanged = Notification.Name("radarStationChanged")
}

final class StationOverlayView: UIView {
    private var stations: [RadarStationInfo] = []
    private var activeStationIndex: Int = -1
    private var centerLat: Double = 39.0
    private var centerLon: Double = -98.0
    private var zoom: Double = 28.0
    private var renderScale: CGFloat = 1.0

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(stations: [RadarStationInfo],
                activeStationIndex: Int,
                centerLat: Double,
                centerLon: Double,
                zoom: Double,
                renderScale: CGFloat) {
        self.stations = stations
        self.activeStationIndex = activeStationIndex
        self.centerLat = centerLat
        self.centerLon = centerLon
        self.zoom = zoom
        self.renderScale = max(renderScale, 0.5)
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext(), zoom > 0 else { return }

        let midX = bounds.midX
        let midY = bounds.midY
        let labelZoomThreshold = 90.0
        let scale = max(Double(contentScaleFactor), 1.0)
        let effectiveScale = scale * max(Double(renderScale), 0.5)
        let pointsZoom = zoom / effectiveScale

        for station in stations {
            let x = (Double(station.displayLon) - centerLon) * pointsZoom + midX
            let y = (centerLat - Double(station.displayLat)) * pointsZoom + midY

            if x < -24 || x > bounds.width + 24 || y < -24 || y > bounds.height + 24 {
                continue
            }

            let isActive = Int(station.index) == activeStationIndex
            let isLoaded = station.loaded
            let dotRadius: CGFloat = isActive ? 4.5 : 2.5

            let dotColor: UIColor
            if isActive {
                dotColor = UIColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 0.95)
            } else if isLoaded {
                dotColor = UIColor(red: 0.46, green: 0.82, blue: 0.84, alpha: 0.9)
            } else {
                dotColor = UIColor(white: 0.62, alpha: 0.55)
            }

            ctx.setFillColor(dotColor.cgColor)
            ctx.fillEllipse(in: CGRect(x: x - dotRadius, y: y - dotRadius,
                                       width: dotRadius * 2, height: dotRadius * 2))

            if isActive {
                ctx.setStrokeColor(UIColor(red: 0.46, green: 0.82, blue: 0.84, alpha: 0.75).cgColor)
                ctx.setLineWidth(1.0)
                ctx.strokeEllipse(in: CGRect(x: x - 10, y: y - 10, width: 20, height: 20))
            }

            let showLabel = isActive || pointsZoom >= labelZoomThreshold || isLoaded
            guard showLabel else { continue }
            let icao = station.icao

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: isActive ? 11 : 9,
                                                   weight: isActive ? .bold : .medium),
                .foregroundColor: isActive ? UIColor.white : UIColor(white: 0.82, alpha: 0.82)
            ]
            let textSize = icao.size(withAttributes: attributes)
            let textRect = CGRect(x: x - textSize.width * 0.5,
                                  y: y + dotRadius + 3,
                                  width: textSize.width,
                                  height: textSize.height)
            icao.draw(in: textRect, withAttributes: attributes)
        }
    }
}

struct RadarMapView: UIViewRepresentable {
    @EnvironmentObject var appState: AppState

    func makeCoordinator() -> Coordinator {
        Coordinator(appState: appState)
    }

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        container.backgroundColor = UIColor(red: 0.035, green: 0.047, blue: 0.074, alpha: 1.0)

        let mtkView = MTKView()
        mtkView.device = appState.device
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.isOpaque = true
        mtkView.backgroundColor = .clear
        mtkView.clearColor = MTLClearColor(red: 0.035, green: 0.047, blue: 0.074, alpha: 1.0)
        mtkView.framebufferOnly = false
        mtkView.preferredFramesPerSecond = 60
        mtkView.isPaused = true
        mtkView.enableSetNeedsDisplay = true
        mtkView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(mtkView)

        let overlay = StationOverlayView()
        overlay.translatesAutoresizingMaskIntoConstraints = false
        overlay.isUserInteractionEnabled = false
        container.addSubview(overlay)

        let renderCoordinator = MetalRenderCoordinator(
            engine: appState.engine,
            device: appState.device,
            appState: appState
        )
        mtkView.delegate = renderCoordinator
        renderCoordinator.attach(to: mtkView)

        context.coordinator.containerView = container
        context.coordinator.mtkView = mtkView
        context.coordinator.overlayView = overlay
        context.coordinator.renderCoordinator = renderCoordinator
        renderCoordinator.onRenderScaleChanged = { [weak coordinator = context.coordinator] in
            coordinator?.syncOverlayFromAppState()
        }
        context.coordinator.installGestures(on: container)

        NSLayoutConstraint.activate([
            mtkView.topAnchor.constraint(equalTo: container.topAnchor),
            mtkView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            mtkView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            mtkView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            overlay.topAnchor.constraint(equalTo: container.topAnchor),
            overlay.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            overlay.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])

        DispatchQueue.main.async {
            context.coordinator.syncOverlayFromAppState()
            context.coordinator.renderCoordinator?.requestDraw()
        }

        return container
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.renderCoordinator?.isRendering = appState.isRendering
        context.coordinator.renderCoordinator?.refreshInteractionPolicy()
        context.coordinator.syncOverlayFromAppState()
        context.coordinator.renderCoordinator?.requestDraw()
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let appState: AppState
        weak var containerView: UIView?
        weak var mtkView: MTKView?
        weak var overlayView: StationOverlayView?
        var renderCoordinator: MetalRenderCoordinator?

        init(appState: AppState) {
            self.appState = appState
            super.init()
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleStationChanged),
                name: .radarStationChanged,
                object: nil
            )
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        func installGestures(on view: UIView) {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.maximumNumberOfTouches = 2
            pan.delegate = self

            let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            pinch.delegate = self

            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            tap.delegate = self

            view.addGestureRecognizer(pan)
            view.addGestureRecognizer(pinch)
            view.addGestureRecognizer(tap)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            (gestureRecognizer is UIPinchGestureRecognizer && otherGestureRecognizer is UIPanGestureRecognizer) ||
            (gestureRecognizer is UIPanGestureRecognizer && otherGestureRecognizer is UIPinchGestureRecognizer)
        }

        private func pixelScale() -> CGFloat {
            mtkView?.contentScaleFactor ?? UIScreen.main.scale
        }

        private func engineInputScale() -> CGFloat {
            pixelScale() * (renderCoordinator?.inputScale ?? 1.0)
        }

        func syncOverlayFromAppState() {
            guard let overlayView else { return }
            overlayView.update(
                stations: appState.stations,
                activeStationIndex: appState.activeStationIndex,
                centerLat: appState.centerLat,
                centerLon: appState.centerLon,
                zoom: appState.zoom,
                renderScale: renderCoordinator?.inputScale ?? 1.0
            )
        }

        @objc func handleStationChanged() {
            appState.syncFromEngine()
            syncOverlayFromAppState()
            renderCoordinator?.requestDraw()
        }

        @objc private func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard let view = containerView else { return }
            updateInteractionState(for: recognizer)
            let translation = recognizer.translation(in: view)
            if translation != .zero {
                let scale = engineInputScale()
                appState.engine.pan(byDx: Double(translation.x * scale),
                                    dy: Double(translation.y * scale))
                recognizer.setTranslation(.zero, in: view)
                appState.syncFromEngine()
                syncOverlayFromAppState()
                renderCoordinator?.requestDraw()
            }
        }

        @objc private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            guard let view = containerView else { return }
            updateInteractionState(for: recognizer)
            let location = recognizer.location(in: view)
            let scale = engineInputScale()
            let delta = recognizer.scale - 1.0
            guard delta != 0 else { return }

            appState.engine.zoom(atScreenX: Double(location.x * scale),
                                 y: Double(location.y * scale),
                                 magnification: Double(delta))
            recognizer.scale = 1.0

            appState.syncFromEngine()
            syncOverlayFromAppState()
            renderCoordinator?.requestDraw()
        }

        @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard let view = containerView else { return }
            let location = recognizer.location(in: view)
            let scale = engineInputScale()

            appState.engine.tap(atScreenX: Double(location.x * scale), y: Double(location.y * scale))
            appState.syncFromEngine()
            syncOverlayFromAppState()
            renderCoordinator?.requestDraw()
        }

        private func updateInteractionState(for recognizer: UIGestureRecognizer) {
            switch recognizer.state {
            case .began, .changed:
                renderCoordinator?.setInteractionActive(true)
            case .ended, .cancelled, .failed:
                renderCoordinator?.setInteractionActive(false)
            default:
                break
            }
        }
    }
}
