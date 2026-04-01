import SwiftUI
import Metal
import Combine

private enum AppPreferenceKey {
    static let favoriteStations = "macdar.favoriteStations"
    static let recentStations = "macdar.recentStations"
    static let lastStationICAO = "macdar.lastStationICAO"
    static let lastProduct = "macdar.lastProduct"
    static let lastTilt = "macdar.lastTilt"
    static let mosaicMode = "macdar.mosaicMode"
    static let maxActiveStations = "macdar.maxActiveStations"
    static let liveLoopLength = "macdar.liveLoopLength"
    static let fullResolutionInteraction = "macdar.fullResolutionInteraction"
    static let dbzThreshold = "macdar.dbzThreshold"
    static let srvMode = "macdar.srvMode"
    static let stormSpeed = "macdar.stormSpeed"
    static let stormDir = "macdar.stormDir"
    static let warningsEnabled = "macdar.warningsEnabled"
    static let tornadoAlertsEnabled = "macdar.tornadoAlertsEnabled"
    static let severeAlertsEnabled = "macdar.severeAlertsEnabled"
    static let floodAlertsEnabled = "macdar.floodAlertsEnabled"
    static let watchAlertsEnabled = "macdar.watchAlertsEnabled"
    static let statementAlertsEnabled = "macdar.statementAlertsEnabled"
    static let advisoryAlertsEnabled = "macdar.advisoryAlertsEnabled"
    static let fireAlertsEnabled = "macdar.fireAlertsEnabled"
    static let marineAlertsEnabled = "macdar.marineAlertsEnabled"
    static let otherAlertsEnabled = "macdar.otherAlertsEnabled"
    static let tornadoAlertColor = "macdar.tornadoAlertColor"
    static let severeAlertColor = "macdar.severeAlertColor"
    static let floodAlertColor = "macdar.floodAlertColor"
    static let watchAlertColor = "macdar.watchAlertColor"
    static let statementAlertColor = "macdar.statementAlertColor"
    static let advisoryAlertColor = "macdar.advisoryAlertColor"
    static let fireAlertColor = "macdar.fireAlertColor"
    static let marineAlertColor = "macdar.marineAlertColor"
    static let otherAlertColor = "macdar.otherAlertColor"
}

private extension UserDefaults {
    func contains(key: String) -> Bool {
        object(forKey: key) != nil
    }
}

func radarTimestampLabel(_ rawValue: String) -> String {
    let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "" }
    return trimmed.uppercased().hasSuffix("UTC") ? trimmed : "\(trimmed) UTC"
}

@MainActor
class AppState: ObservableObject {
    let engine = RadarEngine()
    let device: MTLDevice
    let orchestrator = AppOrchestrator()
    private let defaults: UserDefaults
    private var cancellables: Set<AnyCancellable> = []
    private var pendingRestoredStationICAO: String?
    private var pendingRestoredTilt: Int?
    private var hasAppliedInitialSession = false
    private var lastObservedActiveStationICAO = ""

    @Published var activeProduct: Int = 0
    @Published var activeTilt: Int = 0
    @Published var maxTilts: Int = 1
    @Published var tiltAngle: Float = 0.5
    @Published var stationsLoaded: Int = 0
    @Published var stationsDownloading: Int = 0
    @Published var stations: [RadarStationInfo] = []
    @Published var activeStationName: String = "—"
    @Published var activeStationDetail: String = "Radar site"
    @Published var activeStationScanTime: String = "Waiting for data"
    @Published var activeStationIndex: Int = -1
    @Published var stationAutoTrackEnabled: Bool = true
    @Published var productName: String = "REF"
    @Published var mosaicMode: Bool = false
    @Published var isRendering: Bool = true
    @Published var maxActiveStations: Int = 1
    @Published var centerLat: Double = 39.0
    @Published var centerLon: Double = -98.0
    @Published var zoom: Double = 28.0
    @Published var cursorLat: Double = 39.0
    @Published var cursorLon: Double = -98.0
    @Published var archiveStatus: RadarArchiveStatus?
    @Published var liveLoopStatus: RadarLiveLoopStatus?
    @Published var liveLoopTargetFrames: Int = 8
    @Published var liveLoopMaxFrames: Int = 16
    @Published var historicEvents: [RadarHistoricEventInfo] = []
    @Published var warningCount: Int = 0
    @Published var favoriteStationICAOs: [String]
    @Published var recentStationICAOs: [String]
    @Published var prefersFullResolutionInteraction: Bool = false
    @Published var activeStationSweepCount: Int = 0
    @Published var activeStationLowestElevation: Float = 0.5
    @Published var activeStationTDSCount: Int = 0
    @Published var activeStationHailCount: Int = 0
    @Published var activeStationMesoCount: Int = 0
    @Published var activeStationErrorMessage: String = ""
    @Published var activeStationDecodeMs: Float = 0
    @Published var activeStationParseMs: Float = 0
    @Published var activeStationSweepBuildMs: Float = 0
    @Published var activeStationPreprocessMs: Float = 0
    @Published var activeStationDetectionMs: Float = 0
    @Published var activeStationUploadMs: Float = 0

    let productNames = ["REF", "VEL", "SW", "ZDR", "CC", "KDP", "PHI"]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        _favoriteStationICAOs = Published(initialValue: defaults.stringArray(forKey: AppPreferenceKey.favoriteStations) ?? [])
        _recentStationICAOs = Published(initialValue: defaults.stringArray(forKey: AppPreferenceKey.recentStations) ?? [])

        if defaults.contains(key: AppPreferenceKey.mosaicMode) {
            _mosaicMode = Published(initialValue: defaults.bool(forKey: AppPreferenceKey.mosaicMode))
        }

        if defaults.contains(key: AppPreferenceKey.maxActiveStations) {
            _maxActiveStations = Published(initialValue: max(1, defaults.integer(forKey: AppPreferenceKey.maxActiveStations)))
        }

        if defaults.contains(key: AppPreferenceKey.liveLoopLength) {
            _liveLoopTargetFrames = Published(initialValue: max(1, defaults.integer(forKey: AppPreferenceKey.liveLoopLength)))
        }

        if defaults.contains(key: AppPreferenceKey.fullResolutionInteraction) {
            _prefersFullResolutionInteraction = Published(initialValue: defaults.bool(forKey: AppPreferenceKey.fullResolutionInteraction))
        }

        device = MTLCreateSystemDefaultDevice()!
        pendingRestoredStationICAO = defaults.string(forKey: AppPreferenceKey.lastStationICAO)
        if defaults.contains(key: AppPreferenceKey.lastTilt) {
            pendingRestoredTilt = max(0, defaults.integer(forKey: AppPreferenceKey.lastTilt))
        }

        orchestrator.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var activeStationInfo: RadarStationInfo? {
        stations.first { Int($0.index) == activeStationIndex }
    }

    var recentStations: [RadarStationInfo] {
        recentStationICAOs.compactMap { icao in
            stations.first { $0.icao == icao }
        }
    }

    var favoriteStations: [RadarStationInfo] {
        favoriteStationICAOs.compactMap { icao in
            stations.first { $0.icao == icao }
        }
    }

    var supportsDesktopPerformanceControls: Bool {
#if targetEnvironment(macCatalyst)
        true
#else
        false
#endif
    }

    var stationTrackingLocked: Bool {
        !stationAutoTrackEnabled
    }

    func initialize(width: Int, height: Int) {
        engine.initialize(with: device, width: Int32(width), height: Int32(height))
        applyPersistedRuntimeSettings()
        syncFromEngine()
    }

    func syncFromEngine() {
        stations = engine.stationList()
        stationsDownloading = Int(engine.stationsDownloading)
        warningCount = Int(engine.warningCount)

        if historicEvents.isEmpty {
            historicEvents = engine.historicEvents()
        }

        restorePendingSessionStateIfPossible()

        activeProduct = Int(engine.activeProduct)
        activeTilt = Int(engine.activeTilt)
        maxTilts = Int(engine.maxTilts)
        tiltAngle = engine.activeTiltAngle
        stationsLoaded = Int(engine.stationsLoaded)
        activeStationIndex = Int(engine.activeStationIndex)
        stationAutoTrackEnabled = engine.stationAutoTrackEnabled
        productName = productNames[min(max(Int(engine.activeProduct), 0), productNames.count - 1)]
        mosaicMode = engine.mosaicMode
        centerLat = engine.centerLat
        centerLon = engine.centerLon
        zoom = engine.zoom
        cursorLat = Double(engine.cursorLat)
        cursorLon = Double(engine.cursorLon)

        let archive = engine.archiveStatus()
        archiveStatus = archive
        let liveLoop = engine.liveLoopStatus()
        liveLoopStatus = liveLoop
        liveLoopTargetFrames = max(1, Int(liveLoop.targetFrames))
        liveLoopMaxFrames = max(liveLoopTargetFrames, Int(liveLoop.maxFrames))

        if archive.active {
            clearActiveStationSignal()
            activeStationName = archive.station.isEmpty ? "ARCHIVE" : archive.station
            activeStationDetail = archive.label.isEmpty ? "Archive playback" : archive.label

            if archive.loading {
                activeStationScanTime = archive.totalFrames > 0
                    ? "Loading \(archive.downloadedFrames)/\(archive.totalFrames)"
                    : "Loading archive"
            } else if !archive.frameTimestamp.isEmpty {
                activeStationScanTime = "Frame \(radarTimestampLabel(archive.frameTimestamp))"
            } else {
                activeStationScanTime = "Archive playback"
            }
            return
        }

        guard let activeStation = activeStationInfo else {
            clearActiveStationSignal()
            activeStationName = engine.activeStationName
            activeStationDetail = "Radar site"
            activeStationScanTime = "Waiting for data"
            return
        }

        rememberActiveStation(activeStation)
        updateActiveStationSignal(using: activeStation)

        activeStationName = activeStation.icao
        let locationParts = [activeStation.siteName, activeStation.stateCode].filter { !$0.isEmpty }
        activeStationDetail = locationParts.isEmpty ? "Radar site" : locationParts.joined(separator: ", ")

        if !activeStation.scanTime.isEmpty {
            if liveLoop.viewingHistory && !liveLoop.label.isEmpty {
                activeStationScanTime = "Frame \(radarTimestampLabel(liveLoop.label))"
            } else {
                activeStationScanTime = "Scan \(radarTimestampLabel(activeStation.scanTime))"
            }
        } else if activeStation.downloading {
            activeStationScanTime = "Loading latest scan"
        } else if !activeStation.errorMessage.isEmpty {
            activeStationScanTime = activeStation.errorMessage
        } else {
            activeStationScanTime = "Awaiting scan"
        }
    }

    func setProduct(_ product: Int) {
        let clamped = min(max(product, 0), productNames.count - 1)
        defaults.set(clamped, forKey: AppPreferenceKey.lastProduct)
        engine.setProduct(Int32(clamped))
        syncFromEngine()
    }

    func setTilt(_ tilt: Int) {
        let clamped = max(tilt, 0)
        defaults.set(clamped, forKey: AppPreferenceKey.lastTilt)
        pendingRestoredTilt = nil
        engine.setTilt(Int32(clamped))
        syncFromEngine()
    }

    func setMosaicMode(_ enabled: Bool) {
        mosaicMode = enabled
        defaults.set(enabled, forKey: AppPreferenceKey.mosaicMode)
        engine.mosaicMode = enabled
        syncFromEngine()
    }

    func toggleMosaic() {
        setMosaicMode(!mosaicMode)
    }

    func setMaxActiveStations(_ count: Int) {
        let clamped = min(max(count, 1), 10)
        maxActiveStations = clamped
        defaults.set(clamped, forKey: AppPreferenceKey.maxActiveStations)
        engine.maxActiveStations = Int32(clamped)
        syncFromEngine()
    }

    func setLiveLoopLength(_ count: Int) {
        let minimum = supportsDesktopPerformanceControls ? 4 : 1
        let clamped = min(max(count, minimum), max(liveLoopMaxFrames, minimum))
        liveLoopTargetFrames = clamped
        defaults.set(clamped, forKey: AppPreferenceKey.liveLoopLength)
        engine.setLiveLoopLength(Int32(clamped))
        syncFromEngine()
    }

    func setLiveLoopFrame(_ frame: Int) {
        engine.setLiveLoopFrame(Int32(frame))
        syncFromEngine()
    }

    func goToLiveFrame() {
        engine.goToLiveLoopLatestFrame()
        syncFromEngine()
    }

    func setFullResolutionInteraction(_ enabled: Bool) {
        guard supportsDesktopPerformanceControls else { return }
        prefersFullResolutionInteraction = enabled
        defaults.set(enabled, forKey: AppPreferenceKey.fullResolutionInteraction)
    }

    func setDbzThreshold(_ value: Float) {
        defaults.set(value, forKey: AppPreferenceKey.dbzThreshold)
        engine.dbzThreshold = value
        syncFromEngine()
    }

    func setSRVMode(_ enabled: Bool) {
        defaults.set(enabled, forKey: AppPreferenceKey.srvMode)
        engine.srvMode = enabled
        syncFromEngine()
    }

    func setWarningsEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: AppPreferenceKey.warningsEnabled)
        engine.warningsEnabled = enabled
        syncFromEngine()
    }

    func setTornadoAlertsEnabled(_ enabled: Bool) {
        persistAlertFlag(enabled, key: AppPreferenceKey.tornadoAlertsEnabled) {
            engine.tornadoAlertsEnabled = $0
        }
    }

    func setSevereAlertsEnabled(_ enabled: Bool) {
        persistAlertFlag(enabled, key: AppPreferenceKey.severeAlertsEnabled) {
            engine.severeAlertsEnabled = $0
        }
    }

    func setFloodAlertsEnabled(_ enabled: Bool) {
        persistAlertFlag(enabled, key: AppPreferenceKey.floodAlertsEnabled) {
            engine.floodAlertsEnabled = $0
        }
    }

    func setWatchAlertsEnabled(_ enabled: Bool) {
        persistAlertFlag(enabled, key: AppPreferenceKey.watchAlertsEnabled) {
            engine.watchAlertsEnabled = $0
        }
    }

    func setStatementAlertsEnabled(_ enabled: Bool) {
        persistAlertFlag(enabled, key: AppPreferenceKey.statementAlertsEnabled) {
            engine.statementAlertsEnabled = $0
        }
    }

    func setAdvisoryAlertsEnabled(_ enabled: Bool) {
        persistAlertFlag(enabled, key: AppPreferenceKey.advisoryAlertsEnabled) {
            engine.advisoryAlertsEnabled = $0
        }
    }

    func setFireAlertsEnabled(_ enabled: Bool) {
        persistAlertFlag(enabled, key: AppPreferenceKey.fireAlertsEnabled) {
            engine.fireAlertsEnabled = $0
        }
    }

    func setMarineAlertsEnabled(_ enabled: Bool) {
        persistAlertFlag(enabled, key: AppPreferenceKey.marineAlertsEnabled) {
            engine.marineAlertsEnabled = $0
        }
    }

    func setOtherAlertsEnabled(_ enabled: Bool) {
        persistAlertFlag(enabled, key: AppPreferenceKey.otherAlertsEnabled) {
            engine.otherAlertsEnabled = $0
        }
    }

    func setTornadoAlertColor(_ color: UInt32) {
        persistAlertColor(color, key: AppPreferenceKey.tornadoAlertColor) {
            engine.tornadoAlertColor = $0
        }
    }

    func setSevereAlertColor(_ color: UInt32) {
        persistAlertColor(color, key: AppPreferenceKey.severeAlertColor) {
            engine.severeAlertColor = $0
        }
    }

    func setFloodAlertColor(_ color: UInt32) {
        persistAlertColor(color, key: AppPreferenceKey.floodAlertColor) {
            engine.floodAlertColor = $0
        }
    }

    func setWatchAlertColor(_ color: UInt32) {
        persistAlertColor(color, key: AppPreferenceKey.watchAlertColor) {
            engine.watchAlertColor = $0
        }
    }

    func setStatementAlertColor(_ color: UInt32) {
        persistAlertColor(color, key: AppPreferenceKey.statementAlertColor) {
            engine.statementAlertColor = $0
        }
    }

    func setAdvisoryAlertColor(_ color: UInt32) {
        persistAlertColor(color, key: AppPreferenceKey.advisoryAlertColor) {
            engine.advisoryAlertColor = $0
        }
    }

    func setFireAlertColor(_ color: UInt32) {
        persistAlertColor(color, key: AppPreferenceKey.fireAlertColor) {
            engine.fireAlertColor = $0
        }
    }

    func setMarineAlertColor(_ color: UInt32) {
        persistAlertColor(color, key: AppPreferenceKey.marineAlertColor) {
            engine.marineAlertColor = $0
        }
    }

    func setOtherAlertColor(_ color: UInt32) {
        persistAlertColor(color, key: AppPreferenceKey.otherAlertColor) {
            engine.otherAlertColor = $0
        }
    }

    func setStormSpeed(_ speed: Float) {
        defaults.set(speed, forKey: AppPreferenceKey.stormSpeed)
        engine.stormSpeed = speed
        syncFromEngine()
    }

    func setStormDir(_ direction: Float) {
        defaults.set(direction, forKey: AppPreferenceKey.stormDir)
        engine.stormDir = direction
        syncFromEngine()
    }

    func selectStation(_ station: RadarStationInfo, centerView: Bool = true) {
        pendingRestoredStationICAO = nil
        defaults.set(station.icao, forKey: AppPreferenceKey.lastStationICAO)
        pushRecentStation(station.icao)
        engine.selectStation(station.index, centerView: centerView)
        syncFromEngine()
        NotificationCenter.default.post(name: .radarStationChanged, object: nil)
    }

    @discardableResult
    func loadArchiveRange(stationICAO: String,
                          archiveDate: Date,
                          startTime: Date,
                          endTime: Date) -> Bool {
        let trimmedStation = stationICAO
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        guard !trimmedStation.isEmpty else { return false }

        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!

        let day = utcCalendar.dateComponents([.year, .month, .day], from: archiveDate)
        let start = utcCalendar.dateComponents([.hour, .minute], from: startTime)
        let end = utcCalendar.dateComponents([.hour, .minute], from: endTime)

        guard let year = day.year,
              let month = day.month,
              let dayOfMonth = day.day,
              let startHour = start.hour,
              let startMinute = start.minute,
              let endHour = end.hour,
              let endMinute = end.minute else {
            return false
        }

        let loaded = engine.loadArchiveRange(forStation: trimmedStation,
                                             year: Int32(year),
                                             month: Int32(month),
                                             day: Int32(dayOfMonth),
                                             startHour: Int32(startHour),
                                             startMinute: Int32(startMinute),
                                             endHour: Int32(endHour),
                                             endMinute: Int32(endMinute))
        if loaded {
            syncFromEngine()
        }
        return loaded
    }

    func lockCurrentTrackedStation() {
        engine.lockActiveStation()
        syncFromEngine()
        NotificationCenter.default.post(name: .radarStationChanged, object: nil)
    }

    func unlockStationTracking() {
        engine.unlockStationAutoTrack()
        syncFromEngine()
        NotificationCenter.default.post(name: .radarStationChanged, object: nil)
    }

    func isFavorite(_ station: RadarStationInfo) -> Bool {
        favoriteStationICAOs.contains(station.icao)
    }

    func toggleFavorite(_ station: RadarStationInfo) {
        if let existing = favoriteStationICAOs.firstIndex(of: station.icao) {
            favoriteStationICAOs.remove(at: existing)
        } else {
            favoriteStationICAOs.insert(station.icao, at: 0)
        }

        favoriteStationICAOs = Array(favoriteStationICAOs.prefix(12))
        defaults.set(favoriteStationICAOs, forKey: AppPreferenceKey.favoriteStations)
        objectWillChange.send()
    }

    func toggleFavoriteCurrentStation() {
        guard let activeStationInfo else { return }
        toggleFavorite(activeStationInfo)
    }

    private func applyPersistedRuntimeSettings() {
        guard !hasAppliedInitialSession else { return }
        hasAppliedInitialSession = true

        if defaults.contains(key: AppPreferenceKey.lastProduct) {
            let product = min(max(defaults.integer(forKey: AppPreferenceKey.lastProduct), 0), productNames.count - 1)
            engine.setProduct(Int32(product))
        }

        engine.mosaicMode = mosaicMode
        engine.maxActiveStations = Int32(maxActiveStations)
        engine.setLiveLoopLength(Int32(liveLoopTargetFrames))

        if defaults.contains(key: AppPreferenceKey.dbzThreshold) {
            engine.dbzThreshold = defaults.float(forKey: AppPreferenceKey.dbzThreshold)
        }

        if defaults.contains(key: AppPreferenceKey.srvMode) {
            engine.srvMode = defaults.bool(forKey: AppPreferenceKey.srvMode)
        }

        if defaults.contains(key: AppPreferenceKey.stormSpeed) {
            engine.stormSpeed = defaults.float(forKey: AppPreferenceKey.stormSpeed)
        }

        if defaults.contains(key: AppPreferenceKey.stormDir) {
            engine.stormDir = defaults.float(forKey: AppPreferenceKey.stormDir)
        }

        if defaults.contains(key: AppPreferenceKey.warningsEnabled) {
            engine.warningsEnabled = defaults.bool(forKey: AppPreferenceKey.warningsEnabled)
        }

        let alertFlagSettings: [(String, (Bool) -> Void)] = [
            (AppPreferenceKey.tornadoAlertsEnabled, { self.engine.tornadoAlertsEnabled = $0 }),
            (AppPreferenceKey.severeAlertsEnabled, { self.engine.severeAlertsEnabled = $0 }),
            (AppPreferenceKey.floodAlertsEnabled, { self.engine.floodAlertsEnabled = $0 }),
            (AppPreferenceKey.watchAlertsEnabled, { self.engine.watchAlertsEnabled = $0 }),
            (AppPreferenceKey.statementAlertsEnabled, { self.engine.statementAlertsEnabled = $0 }),
            (AppPreferenceKey.advisoryAlertsEnabled, { self.engine.advisoryAlertsEnabled = $0 }),
            (AppPreferenceKey.fireAlertsEnabled, { self.engine.fireAlertsEnabled = $0 }),
            (AppPreferenceKey.marineAlertsEnabled, { self.engine.marineAlertsEnabled = $0 }),
            (AppPreferenceKey.otherAlertsEnabled, { self.engine.otherAlertsEnabled = $0 })
        ]

        for (key, apply) in alertFlagSettings where defaults.contains(key: key) {
            apply(defaults.bool(forKey: key))
        }

        let alertColorSettings: [(String, (UInt32) -> Void)] = [
            (AppPreferenceKey.tornadoAlertColor, { self.engine.tornadoAlertColor = $0 }),
            (AppPreferenceKey.severeAlertColor, { self.engine.severeAlertColor = $0 }),
            (AppPreferenceKey.floodAlertColor, { self.engine.floodAlertColor = $0 }),
            (AppPreferenceKey.watchAlertColor, { self.engine.watchAlertColor = $0 }),
            (AppPreferenceKey.statementAlertColor, { self.engine.statementAlertColor = $0 }),
            (AppPreferenceKey.advisoryAlertColor, { self.engine.advisoryAlertColor = $0 }),
            (AppPreferenceKey.fireAlertColor, { self.engine.fireAlertColor = $0 }),
            (AppPreferenceKey.marineAlertColor, { self.engine.marineAlertColor = $0 }),
            (AppPreferenceKey.otherAlertColor, { self.engine.otherAlertColor = $0 })
        ]

        for (key, apply) in alertColorSettings where defaults.contains(key: key) {
            apply(UInt32(truncatingIfNeeded: defaults.integer(forKey: key)))
        }
    }

    private func persistAlertFlag(_ enabled: Bool, key: String, apply: (Bool) -> Void) {
        defaults.set(enabled, forKey: key)
        apply(enabled)
        syncFromEngine()
    }

    private func persistAlertColor(_ color: UInt32, key: String, apply: (UInt32) -> Void) {
        defaults.set(Int(color), forKey: key)
        apply(color)
        syncFromEngine()
    }

    private func restorePendingSessionStateIfPossible() {
        if let pendingRestoredStationICAO, !stations.isEmpty {
            if activeStationInfo?.icao == pendingRestoredStationICAO {
                self.pendingRestoredStationICAO = nil
            } else if let station = stations.first(where: { $0.icao == pendingRestoredStationICAO }) {
                engine.selectStation(station.index, centerView: true)
                self.pendingRestoredStationICAO = nil
            }
        }

        guard let pendingRestoredTilt else { return }

        if pendingRestoredTilt <= 0 {
            self.pendingRestoredTilt = nil
            return
        }

        let availableTilts = Int(engine.maxTilts)
        let activeIndex = Int(engine.activeStationIndex)
        let activeLoaded = stations.first(where: { Int($0.index) == activeIndex })?.loaded ?? false
        guard availableTilts > 1 || activeLoaded else { return }

        let clampedTilt = max(0, min(pendingRestoredTilt, max(availableTilts - 1, 0)))
        engine.setTilt(Int32(clampedTilt))
        self.pendingRestoredTilt = nil
    }

    private func rememberActiveStation(_ station: RadarStationInfo) {
        guard station.icao != lastObservedActiveStationICAO else { return }
        lastObservedActiveStationICAO = station.icao
        defaults.set(station.icao, forKey: AppPreferenceKey.lastStationICAO)
        pushRecentStation(station.icao)
    }

    private func pushRecentStation(_ icao: String) {
        recentStationICAOs.removeAll { $0 == icao }
        recentStationICAOs.insert(icao, at: 0)
        recentStationICAOs = Array(recentStationICAOs.prefix(8))
        defaults.set(recentStationICAOs, forKey: AppPreferenceKey.recentStations)
    }

    private func clearActiveStationSignal() {
        activeStationSweepCount = 0
        activeStationLowestElevation = 0.5
        activeStationTDSCount = 0
        activeStationHailCount = 0
        activeStationMesoCount = 0
        activeStationErrorMessage = ""
        activeStationDecodeMs = 0
        activeStationParseMs = 0
        activeStationSweepBuildMs = 0
        activeStationPreprocessMs = 0
        activeStationDetectionMs = 0
        activeStationUploadMs = 0
    }

    private func updateActiveStationSignal(using station: RadarStationInfo) {
        activeStationSweepCount = Int(station.sweepCount)
        activeStationLowestElevation = station.lowestElevationDeg
        activeStationTDSCount = Int(station.tdsCount)
        activeStationHailCount = Int(station.hailCount)
        activeStationMesoCount = Int(station.mesoCount)
        activeStationErrorMessage = station.errorMessage
        activeStationDecodeMs = station.decodeMs
        activeStationParseMs = station.parseMs
        activeStationSweepBuildMs = station.sweepBuildMs
        activeStationPreprocessMs = station.preprocessMs
        activeStationDetectionMs = station.detectionMs
        activeStationUploadMs = station.uploadMs
    }

    private var hasLaunched = false

    func suspendRendering() {
        isRendering = false
    }

    func resumeRendering() {
        isRendering = true
        if hasLaunched {
            syncFromEngine()
        }
        hasLaunched = true
    }
}
