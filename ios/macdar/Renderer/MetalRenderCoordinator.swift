import Metal
import MetalKit
import UIKit

@MainActor
class MetalRenderCoordinator: NSObject, MTKViewDelegate {
    private struct BufferBlitParams {
        var width: UInt32
        var height: UInt32
        var hasOverlay: UInt32
    }

    let engine: RadarEngine
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    weak var appState: AppState?
    var onRenderScaleChanged: (() -> Void)?

    private weak var view: MTKView?

    // Full-screen blit into the MTKView drawable from the engine's output buffer.
    private var pipelineState: MTLRenderPipelineState?
    private var engineInitialized = false
    private var fullDrawableSize: CGSize = .zero
    private var currentRenderScale: CGFloat = 1.0
    private var interactionActive = false
    private let restoreDelaySeconds: TimeInterval = 0.22
    private var restoreWorkItem: DispatchWorkItem?

    private var updateTimer: DispatchSourceTimer?
    private let idleTickSeconds: CFTimeInterval = 0.25
    private var lastUpdateTime: CFTimeInterval = 0

    var inputScale: CGFloat {
        currentRenderScale
    }

    var isRendering = true {
        didSet {
            updateTimerState()
            if isRendering {
                requestDraw()
            }
        }
    }

    init(engine: RadarEngine, device: MTLDevice, appState: AppState) {
        self.engine = engine
        self.device = device
        self.appState = appState
        self.commandQueue = device.makeCommandQueue()!
        super.init()
        buildPipeline()
    }

    deinit {
        updateTimer?.cancel()
    }

    func attach(to view: MTKView) {
        self.view = view
        view.isPaused = true
        view.enableSetNeedsDisplay = true
        view.preferredFramesPerSecond = 60
        updateTimerState()
    }

    func requestDraw() {
        guard isRendering, let view else { return }
        if Thread.isMainThread {
            view.draw()
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.view?.draw()
            }
        }
    }

    private func buildPipeline() {
        guard let library = device.makeDefaultLibrary(),
              let vertex = library.makeFunction(name: "blit_buffer_vertex"),
              let fragment = library.makeFunction(name: "blit_buffer_fragment")
        else {
            print("MetalRenderCoordinator: Failed to load blit shaders from default library")
            return
        }

        do {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = vertex
            descriptor.fragmentFunction = fragment
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            print("MetalRenderCoordinator: Failed to build blit pipeline: \(error)")
        }
    }

    private func initEngineIfNeeded(width: Int, height: Int) {
        guard !engineInitialized && width > 0 && height > 0 else { return }
        let initialSize = scaledRenderSize(for: CGSize(width: width, height: height), scale: currentRenderScale)
        print("MetalRenderCoordinator: Initializing engine \(initialSize.width)x\(initialSize.height)")
        appState?.initialize(width: initialSize.width, height: initialSize.height)
        engineInitialized = true
        lastUpdateTime = CACurrentMediaTime()
        appState?.orchestrator.setInteractionRendering(active: false, scale: currentRenderScale)
    }

    private func updateTimerState() {
        if isRendering {
            startUpdateTimer()
        } else {
            stopUpdateTimer()
        }
    }

    private func startUpdateTimer() {
        guard updateTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        timer.schedule(deadline: .now(), repeating: idleTickSeconds, leeway: .milliseconds(50))
        timer.setEventHandler { [weak self] in
            self?.tick()
        }
        updateTimer = timer
        timer.resume()
    }

    private func stopUpdateTimer() {
        updateTimer?.cancel()
        updateTimer = nil
    }

    private func tick() {
        guard isRendering else { return }
        guard let view else { return }

        if !engineInitialized {
            let size = view.drawableSize
            if size.width > 0 && size.height > 0 {
                initEngineIfNeeded(width: Int(size.width), height: Int(size.height))
                if engineInitialized {
                    requestDraw()
                }
            }
            return
        }

        let now = CACurrentMediaTime()
        let dt = Float(lastUpdateTime > 0 ? now - lastUpdateTime : idleTickSeconds)
        lastUpdateTime = now
        engine.update(withDeltaTime: dt)
        appState?.syncFromEngine()

        if engine.needsRender() {
            requestDraw()
        }
    }

    func setInteractionActive(_ active: Bool) {
        interactionActive = active
        restoreWorkItem?.cancel()

        if active {
            applyRenderScale(preferredInteractionRenderScale())
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            self?.applyRenderScale(1.0)
        }
        restoreWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + restoreDelaySeconds, execute: workItem)
    }

    func refreshInteractionPolicy() {
        guard interactionActive else { return }
        applyRenderScale(preferredInteractionRenderScale())
    }

    private func preferredInteractionRenderScale() -> CGFloat {
        if appState?.prefersFullResolutionInteraction == true {
            return 1.0
        }
#if targetEnvironment(macCatalyst)
        return 0.82
#else
        return 0.65
#endif
    }

    private func applyRenderScale(_ scale: CGFloat) {
        let clampedScale = min(max(scale, 0.5), 1.0)
        guard abs(clampedScale - currentRenderScale) > 0.001 else { return }

        let previousScale = currentRenderScale
        currentRenderScale = clampedScale
        appState?.orchestrator.setInteractionRendering(active: clampedScale < 0.999, scale: clampedScale)
        onRenderScaleChanged?()

        guard engineInitialized else {
            requestDraw()
            return
        }

        let zoomScale = Double(clampedScale / previousScale)
        let adjustedZoom = max(1.0, engine.zoom * zoomScale)
        engine.setViewportCenter(engine.centerLat, lon: engine.centerLon, zoom: adjustedZoom)

        let renderSize = scaledRenderSize(for: fullDrawableSize, scale: clampedScale)
        engine.resizeWidth(Int32(renderSize.width), height: Int32(renderSize.height))
        requestDraw()
    }

    private func scaledRenderSize(for size: CGSize, scale: CGFloat) -> (width: Int, height: Int) {
        let width = max(1, Int((size.width * scale).rounded(.toNearestOrEven)))
        let height = max(1, Int((size.height * scale).rounded(.toNearestOrEven)))
        return (
            width: max(64, (width + 7) & ~7),
            height: max(64, (height + 7) & ~7)
        )
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        fullDrawableSize = size
        let w = Int(size.width)
        let h = Int(size.height)
        if w <= 0 || h <= 0 { return }

        if !engineInitialized {
            initEngineIfNeeded(width: w, height: h)
        } else {
            let renderSize = scaledRenderSize(for: size, scale: currentRenderScale)
            engine.resizeWidth(Int32(renderSize.width), height: Int32(renderSize.height))
        }

        requestDraw()
    }

    func draw(in view: MTKView) {
        guard isRendering else { return }

        if !engineInitialized {
            let size = view.drawableSize
            if size.width > 0 && size.height > 0 {
                fullDrawableSize = size
                initEngineIfNeeded(width: Int(size.width), height: Int(size.height))
            }
        }

        guard engineInitialized, engine.needsRender() else { return }

        let w = Int(engine.viewportWidth())
        let h = Int(engine.viewportHeight())
        if w <= 0 || h <= 0 { return }

        engine.render()

        guard let outputBuf = engine.outputBuffer(),
              let drawable = view.currentDrawable,
              let renderPassDesc = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let pipeline = pipelineState
        else {
            return
        }
        let overlayBuffer = engine.overlayBuffer()

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDesc) else {
            return
        }

        var params = BufferBlitParams(width: UInt32(w), height: UInt32(h), hasOverlay: overlayBuffer == nil ? 0 : 1)
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBuffer(outputBuf, offset: 0, index: 0)
        encoder.setFragmentBytes(&params, length: MemoryLayout<BufferBlitParams>.stride, index: 1)
        if let overlayBuffer {
            encoder.setFragmentBuffer(overlayBuffer, offset: 0, index: 2)
        }
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
