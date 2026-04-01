import Metal
import MetalKit
import UIKit

@MainActor
class MetalRenderCoordinator: NSObject, MTKViewDelegate {
    let engine: RadarEngine
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    weak var appState: AppState?
    var onRenderScaleChanged: (() -> Void)?

    private weak var view: MTKView?

    // GPU copy + full-screen blit into the MTKView drawable.
    private var pipelineState: MTLRenderPipelineState?
    private var outputTexture: MTLTexture?
    private var outputTextureSize: (Int, Int) = (0, 0)
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
        let shaderSrc = """
        #include <metal_stdlib>
        using namespace metal;

        struct VertexOut {
            float4 position [[position]];
            float2 texCoord;
        };

        vertex VertexOut blit_vertex(uint vid [[vertex_id]]) {
            float2 positions[3] = {float2(-1, -1), float2(3, -1), float2(-1, 3)};
            float2 texCoords[3] = {float2(0, 1), float2(2, 1), float2(0, -1)};
            VertexOut out;
            out.position = float4(positions[vid], 0, 1);
            out.texCoord = texCoords[vid];
            return out;
        }

        fragment float4 blit_fragment(VertexOut in [[stage_in]],
                                       texture2d<float> tex [[texture(0)]]) {
            constexpr sampler s(filter::linear, address::clamp_to_edge);
            return tex.sample(s, in.texCoord);
        }
        """

        do {
            let library = try device.makeLibrary(source: shaderSrc, options: nil)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "blit_vertex")
            descriptor.fragmentFunction = library.makeFunction(name: "blit_fragment")
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            descriptor.colorAttachments[0].isBlendingEnabled = true
            descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
            descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            pipelineState = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            print("MetalRenderCoordinator: Failed to build blit pipeline: \(error)")
        }
    }

    private func ensureOutputTexture(width: Int, height: Int) {
        if outputTextureSize == (width, height) && outputTexture != nil { return }
        let desc = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        desc.usage = .shaderRead
        desc.storageMode = .private
        outputTexture = device.makeTexture(descriptor: desc)
        outputTextureSize = (width, height)
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

        guard let outputBuf = engine.outputBuffer() else { return }
        ensureOutputTexture(width: w, height: h)

        guard let tex = outputTexture,
              let drawable = view.currentDrawable,
              let renderPassDesc = view.currentRenderPassDescriptor,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let pipeline = pipelineState,
              let blitEncoder = commandBuffer.makeBlitCommandEncoder()
        else {
            return
        }

        let bytesPerRow = w * MemoryLayout<UInt32>.stride
        blitEncoder.copy(
            from: outputBuf,
            sourceOffset: 0,
            sourceBytesPerRow: bytesPerRow,
            sourceBytesPerImage: bytesPerRow * h,
            sourceSize: MTLSize(width: w, height: h, depth: 1),
            to: tex,
            destinationSlice: 0,
            destinationLevel: 0,
            destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
        )
        blitEncoder.endEncoding()

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDesc) else {
            return
        }

        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentTexture(tex, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()

        commandBuffer.present(drawable)
        commandBuffer.commit()

        appState?.syncFromEngine()
    }
}
