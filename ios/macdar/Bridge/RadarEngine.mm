#import "RadarEngine.h"

#include "app.h"
#include "nexrad/products.h"
#include "nexrad/stations.h"

#include <algorithm>
#include <memory>

// ── RadarStationInfo (ObjC wrapper) ────────────────────────────────

@implementation RadarStationInfo
@end

@implementation RadarHistoricEventInfo
@end

@implementation RadarArchiveStatus
@end

@implementation RadarLiveLoopStatus
@end

// ── RadarEngine ───────────────────────────────────────────────

@implementation RadarEngine {
    std::unique_ptr<App> _app;
    BOOL _initialized;
    BOOL _mosaicMode;
    int  _maxActiveStations;
}

#pragma mark - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        _initialized = NO;
        _mosaicMode = NO;
        _maxActiveStations = 1;
    }
    return self;
}

- (BOOL)initializeWithDevice:(id<MTLDevice>)device width:(int)w height:(int)h {
    @synchronized (self) {
        if (_initialized) {
            NSLog(@"RadarEngine: already initialized, shutting down first");
            [self shutdown];
        }

        NSLog(@"RadarEngine: creating App %dx%d", w, h);
        _app = std::make_unique<App>();
        NSLog(@"RadarEngine: calling init...");
        if (!_app->init(w, h, device)) {
            NSLog(@"RadarEngine: App::init failed");
            _app.reset();
            return NO;
        }

        _initialized = YES;
        NSLog(@"RadarEngine: initialized %dx%d", w, h);
        return YES;
    }
}

- (void)shutdown {
    @synchronized (self) {
        _app.reset();
        _initialized = NO;
    }
}

- (void)dealloc {
    [self shutdown];
}

#pragma mark - Per-frame

- (void)updateWithDeltaTime:(float)dt {
    @synchronized (self) {
        if (!_initialized) return;
        _app->update(dt);
    }
}

- (void)render {
    @synchronized (self) {
        if (!_initialized) return;
        _app->render();
    }
}

- (BOOL)needsRender {
    @synchronized (self) {
        if (!_initialized) return NO;
        return _app->needsRender() ? YES : NO;
    }
}

#pragma mark - Output

- (id<MTLBuffer>)outputBuffer {
    @synchronized (self) {
        if (!_initialized) return nil;
        return _app->getOutputBuffer();
    }
}

- (int)viewportWidth {
    @synchronized (self) {
        if (!_initialized) return 0;
        return _app->viewport().width;
    }
}

- (int)viewportHeight {
    @synchronized (self) {
        if (!_initialized) return 0;
        return _app->viewport().height;
    }
}

#pragma mark - Viewport Gestures

- (void)panByDx:(double)dx dy:(double)dy {
    @synchronized (self) {
        if (!_initialized) return;
        _app->onMouseDrag(dx, dy);
    }
}

- (void)zoomAtLat:(double)lat lon:(double)lon magnification:(double)mag {
    @synchronized (self) {
        if (!_initialized) return;
        // Move cursor to the lat/lon position, then magnify
        Viewport& vp = _app->viewport();
        int px, py;
        vp.latLonToPixel(lat, lon, px, py);
        _app->onMouseMove((double)px, (double)py);
        _app->onMagnify(mag);
    }
}

- (void)zoomAtScreenX:(double)x y:(double)y magnification:(double)mag {
    @synchronized (self) {
        if (!_initialized) return;
        _app->onMouseMove(x, y);
        _app->onMagnify(mag);
    }
}

- (void)zoomByMagnification:(double)mag {
    @synchronized (self) {
        if (!_initialized) return;
        _app->onMagnify(mag);
    }
}

- (void)hoverAtScreenX:(double)x y:(double)y {
    @synchronized (self) {
        if (!_initialized) return;
        _app->onMouseMove(x, y);
    }
}

- (void)tapAtScreenX:(double)x y:(double)y {
    @synchronized (self) {
        if (!_initialized) return;
        _app->onMouseMove(x, y);
        Viewport& vp = _app->viewport();

        // Find nearest NEXRAD station, but only if within tap radius
        int bestIdx = -1;
        float bestScreenDist2 = 1e9f;
        std::vector<StationUiState> stationList = _app->stations();
        for (const auto& st : stationList) {
            // Compute screen-space distance (in pixels)
            double sx = (st.display_lon - vp.center_lon) * vp.zoom + vp.width * 0.5;
            double sy = (vp.center_lat - st.display_lat) * vp.zoom + vp.height * 0.5;
            double dx = sx - x;
            double dy = sy - y;
            float dist2 = (float)(dx * dx + dy * dy);
            if (dist2 < bestScreenDist2) {
                bestScreenDist2 = dist2;
                bestIdx = st.index;
            }
        }

        // Only select if tap is within 44pt * scale = ~132px on 3x display
        float maxDist = 132.0f; // pixels
        if (bestIdx >= 0 && bestScreenDist2 < maxDist * maxDist &&
            bestIdx != _app->activeStation()) {
            _app->selectStation(bestIdx, true);
        }
    }
}

- (void)resizeWidth:(int)w height:(int)h {
    @synchronized (self) {
        if (!_initialized) return;
        _app->onResize(w, h);
    }
}

#pragma mark - Product & Tilt

- (int)activeProduct {
    @synchronized (self) {
        if (!_initialized) return 0;
        return _app->activeProduct();
    }
}

- (int)activeTilt {
    @synchronized (self) {
        if (!_initialized) return 0;
        return _app->activeTilt();
    }
}

- (int)maxTilts {
    @synchronized (self) {
        if (!_initialized) return 1;
        return _app->maxTilts();
    }
}

- (float)activeTiltAngle {
    @synchronized (self) {
        if (!_initialized) return 0.5f;
        return _app->activeTiltAngle();
    }
}

- (NSString *)activeProductName {
    @synchronized (self) {
        if (!_initialized) return @"";
        int p = _app->activeProduct();
        if (p >= 0 && p < (int)Product::COUNT) {
            return [NSString stringWithUTF8String:PRODUCT_INFO[p].name];
        }
        return @"Unknown";
    }
}

- (void)setProduct:(int)product {
    @synchronized (self) {
        if (!_initialized) return;
        _app->setProduct(product);
    }
}

- (void)setTilt:(int)tilt {
    @synchronized (self) {
        if (!_initialized) return;
        _app->setTilt(tilt);
    }
}

- (void)nextProduct {
    @synchronized (self) {
        if (!_initialized) return;
        _app->nextProduct();
    }
}

- (void)prevProduct {
    @synchronized (self) {
        if (!_initialized) return;
        _app->prevProduct();
    }
}

- (void)nextTilt {
    @synchronized (self) {
        if (!_initialized) return;
        _app->nextTilt();
    }
}

- (void)prevTilt {
    @synchronized (self) {
        if (!_initialized) return;
        _app->prevTilt();
    }
}

- (int)productCount {
    return (int)Product::COUNT;
}

- (NSString *)productNameForIndex:(int)idx {
    if (idx >= 0 && idx < (int)Product::COUNT) {
        return [NSString stringWithUTF8String:PRODUCT_INFO[idx].name];
    }
    return @"Unknown";
}

#pragma mark - Station

- (int)activeStationIndex {
    @synchronized (self) {
        if (!_initialized) return -1;
        return _app->activeStation();
    }
}

- (NSString *)activeStationName {
    @synchronized (self) {
        if (!_initialized) return @"";
        std::string name = _app->activeStationName();
        return [NSString stringWithUTF8String:name.c_str()];
    }
}

- (int)stationsLoaded {
    @synchronized (self) {
        if (!_initialized) return 0;
        return _app->stationsLoaded();
    }
}

- (int)stationsTotal {
    @synchronized (self) {
        if (!_initialized) return 0;
        return _app->stationsTotal();
    }
}

- (int)stationsDownloading {
    @synchronized (self) {
        if (!_initialized) return 0;
        return _app->stationsDownloading();
    }
}

- (int)warningCount {
    @synchronized (self) {
        if (!_initialized) return 0;
        return (int)_app->currentWarnings().size();
    }
}

- (BOOL)stationAutoTrackEnabled {
    @synchronized (self) {
        if (!_initialized) return YES;
        return _app->autoTrackStation() ? YES : NO;
    }
}

- (void)selectStation:(int)idx centerView:(BOOL)center {
    @synchronized (self) {
        if (!_initialized) return;
        _app->selectStation(idx, (bool)center);
    }
}

- (void)lockActiveStation {
    @synchronized (self) {
        if (!_initialized) return;
        const int idx = _app->activeStation();
        if (idx < 0) return;
        _app->selectStation(idx, false);
    }
}

- (void)unlockStationAutoTrack {
    @synchronized (self) {
        if (!_initialized) return;
        _app->setAutoTrackStation(true);
    }
}

- (NSArray<RadarStationInfo *> *)stationList {
    @synchronized (self) {
        if (!_initialized) return @[];

        std::vector<StationUiState> stations = _app->stations();
        NSMutableArray<RadarStationInfo *> *result = [NSMutableArray arrayWithCapacity:stations.size()];

        for (const auto& st : stations) {
            RadarStationInfo *info = [[RadarStationInfo alloc] init];
            info.icao = [NSString stringWithUTF8String:st.icao.c_str()];
            if (st.index >= 0 && st.index < NUM_NEXRAD_STATIONS) {
                info.siteName = [NSString stringWithUTF8String:NEXRAD_STATIONS[st.index].name];
                info.stateCode = [NSString stringWithUTF8String:NEXRAD_STATIONS[st.index].state];
            } else {
                info.siteName = @"";
                info.stateCode = @"";
            }
            info.lat = st.lat;
            info.lon = st.lon;
            info.displayLat = st.display_lat;
            info.displayLon = st.display_lon;
            info.loaded = st.parsed && st.uploaded;
            info.downloading = st.downloading;
            info.index = st.index;
            info.scanTime = [NSString stringWithUTF8String:st.latest_scan_utc.c_str()];
            info.errorMessage = [NSString stringWithUTF8String:st.error.c_str()];
            info.sweepCount = st.sweep_count;
            info.lowestElevationDeg = st.lowest_elev;
            info.tdsCount = (int)st.detection.tds.size();
            info.hailCount = (int)st.detection.hail.size();
            info.mesoCount = (int)st.detection.meso.size();
            info.decodeMs = st.timings.decode_ms;
            info.parseMs = st.timings.parse_ms;
            info.sweepBuildMs = st.timings.sweep_build_ms;
            info.preprocessMs = st.timings.preprocess_ms;
            info.detectionMs = st.timings.detection_ms;
            info.uploadMs = st.timings.upload_ms;
            [result addObject:info];
        }

        return [result copy];
    }
}

#pragma mark - Multi-radar mode

- (BOOL)mosaicMode {
    return _mosaicMode;
}

- (void)setMosaicMode:(BOOL)mosaicMode {
    @synchronized (self) {
        _mosaicMode = mosaicMode;
        if (_initialized) {
            if (mosaicMode && !_app->showAll()) {
                _app->toggleShowAll();
            } else if (!mosaicMode && _app->showAll()) {
                _app->toggleShowAll();
            }
        }
    }
}

- (int)maxActiveStations {
    return _maxActiveStations;
}

- (void)setMaxActiveStations:(int)maxActiveStations {
    _maxActiveStations = MIN(MAX(maxActiveStations, 1), 10);
}

#pragma mark - Boundary compositing

- (void)compositeBoundaries {
    @synchronized (self) {
        if (!_initialized) return;
        _app->compositeBoundaries();
    }
}

- (void)waitForGpu {
    @synchronized (self) {
        if (!_initialized) return;
        _app->waitForGpu();
    }
}

#pragma mark - Data

- (void)refreshData {
    @synchronized (self) {
        if (!_initialized) return;
        _app->refreshData();
    }
}

- (BOOL)warningsEnabled {
    @synchronized (self) {
        if (!_initialized) return YES;
        return _app->m_warningOptions.enabled ? YES : NO;
    }
}

- (void)setWarningsEnabled:(BOOL)warningsEnabled {
    @synchronized (self) {
        if (!_initialized) return;
        if ((bool)warningsEnabled != _app->m_warningOptions.enabled) {
            _app->m_warningOptions.enabled = warningsEnabled;
            _app->rerenderAll();
        }
    }
}

- (BOOL)tornadoAlertsEnabled {
    @synchronized (self) {
        if (!_initialized) return YES;
        return _app->m_warningOptions.showTornado ? YES : NO;
    }
}

- (void)setTornadoAlertsEnabled:(BOOL)tornadoAlertsEnabled {
    @synchronized (self) {
        if (!_initialized) return;
        if ((bool)tornadoAlertsEnabled != _app->m_warningOptions.showTornado) {
            _app->m_warningOptions.showTornado = tornadoAlertsEnabled;
            _app->rerenderAll();
        }
    }
}

- (BOOL)severeAlertsEnabled {
    @synchronized (self) {
        if (!_initialized) return YES;
        return _app->m_warningOptions.showSevere ? YES : NO;
    }
}

- (void)setSevereAlertsEnabled:(BOOL)severeAlertsEnabled {
    @synchronized (self) {
        if (!_initialized) return;
        if ((bool)severeAlertsEnabled != _app->m_warningOptions.showSevere) {
            _app->m_warningOptions.showSevere = severeAlertsEnabled;
            _app->rerenderAll();
        }
    }
}

- (BOOL)floodAlertsEnabled {
    @synchronized (self) {
        if (!_initialized) return YES;
        return _app->m_warningOptions.showFlood ? YES : NO;
    }
}

- (void)setFloodAlertsEnabled:(BOOL)floodAlertsEnabled {
    @synchronized (self) {
        if (!_initialized) return;
        if ((bool)floodAlertsEnabled != _app->m_warningOptions.showFlood) {
            _app->m_warningOptions.showFlood = floodAlertsEnabled;
            _app->rerenderAll();
        }
    }
}

- (BOOL)watchAlertsEnabled {
    @synchronized (self) {
        if (!_initialized) return NO;
        return _app->m_warningOptions.showWatches ? YES : NO;
    }
}

- (void)setWatchAlertsEnabled:(BOOL)watchAlertsEnabled {
    @synchronized (self) {
        if (!_initialized) return;
        if ((bool)watchAlertsEnabled != _app->m_warningOptions.showWatches) {
            _app->m_warningOptions.showWatches = watchAlertsEnabled;
            _app->rerenderAll();
        }
    }
}

- (BOOL)statementAlertsEnabled {
    @synchronized (self) {
        if (!_initialized) return NO;
        return _app->m_warningOptions.showStatements ? YES : NO;
    }
}

- (void)setStatementAlertsEnabled:(BOOL)statementAlertsEnabled {
    @synchronized (self) {
        if (!_initialized) return;
        if ((bool)statementAlertsEnabled != _app->m_warningOptions.showStatements) {
            _app->m_warningOptions.showStatements = statementAlertsEnabled;
            _app->m_warningOptions.showSpecialWeatherStatements = statementAlertsEnabled;
            _app->rerenderAll();
        }
    }
}

- (BOOL)advisoryAlertsEnabled {
    @synchronized (self) {
        if (!_initialized) return NO;
        return _app->m_warningOptions.showAdvisories ? YES : NO;
    }
}

- (void)setAdvisoryAlertsEnabled:(BOOL)advisoryAlertsEnabled {
    @synchronized (self) {
        if (!_initialized) return;
        if ((bool)advisoryAlertsEnabled != _app->m_warningOptions.showAdvisories) {
            _app->m_warningOptions.showAdvisories = advisoryAlertsEnabled;
            _app->rerenderAll();
        }
    }
}

- (BOOL)fireAlertsEnabled {
    @synchronized (self) {
        if (!_initialized) return NO;
        return _app->m_warningOptions.showFire ? YES : NO;
    }
}

- (void)setFireAlertsEnabled:(BOOL)fireAlertsEnabled {
    @synchronized (self) {
        if (!_initialized) return;
        if ((bool)fireAlertsEnabled != _app->m_warningOptions.showFire) {
            _app->m_warningOptions.showFire = fireAlertsEnabled;
            _app->rerenderAll();
        }
    }
}

- (BOOL)marineAlertsEnabled {
    @synchronized (self) {
        if (!_initialized) return NO;
        return _app->m_warningOptions.showMarine ? YES : NO;
    }
}

- (void)setMarineAlertsEnabled:(BOOL)marineAlertsEnabled {
    @synchronized (self) {
        if (!_initialized) return;
        if ((bool)marineAlertsEnabled != _app->m_warningOptions.showMarine) {
            _app->m_warningOptions.showMarine = marineAlertsEnabled;
            _app->rerenderAll();
        }
    }
}

- (BOOL)otherAlertsEnabled {
    @synchronized (self) {
        if (!_initialized) return NO;
        return _app->m_warningOptions.showOther ? YES : NO;
    }
}

- (void)setOtherAlertsEnabled:(BOOL)otherAlertsEnabled {
    @synchronized (self) {
        if (!_initialized) return;
        if ((bool)otherAlertsEnabled != _app->m_warningOptions.showOther) {
            _app->m_warningOptions.showOther = otherAlertsEnabled;
            _app->rerenderAll();
        }
    }
}

- (uint32_t)tornadoAlertColor {
    @synchronized (self) {
        if (!_initialized) return 0;
        return _app->m_warningOptions.tornadoColor;
    }
}

- (void)setTornadoAlertColor:(uint32_t)tornadoAlertColor {
    @synchronized (self) {
        if (!_initialized) return;
        if (tornadoAlertColor != _app->m_warningOptions.tornadoColor) {
            _app->m_warningOptions.tornadoColor = tornadoAlertColor;
            _app->rerenderAll();
        }
    }
}

- (uint32_t)severeAlertColor {
    @synchronized (self) {
        if (!_initialized) return 0;
        return _app->m_warningOptions.severeColor;
    }
}

- (void)setSevereAlertColor:(uint32_t)severeAlertColor {
    @synchronized (self) {
        if (!_initialized) return;
        if (severeAlertColor != _app->m_warningOptions.severeColor) {
            _app->m_warningOptions.severeColor = severeAlertColor;
            _app->rerenderAll();
        }
    }
}

- (uint32_t)floodAlertColor {
    @synchronized (self) {
        if (!_initialized) return 0;
        return _app->m_warningOptions.floodColor;
    }
}

- (void)setFloodAlertColor:(uint32_t)floodAlertColor {
    @synchronized (self) {
        if (!_initialized) return;
        if (floodAlertColor != _app->m_warningOptions.floodColor) {
            _app->m_warningOptions.floodColor = floodAlertColor;
            _app->rerenderAll();
        }
    }
}

- (uint32_t)watchAlertColor {
    @synchronized (self) {
        if (!_initialized) return 0;
        return _app->m_warningOptions.watchColor;
    }
}

- (void)setWatchAlertColor:(uint32_t)watchAlertColor {
    @synchronized (self) {
        if (!_initialized) return;
        if (watchAlertColor != _app->m_warningOptions.watchColor) {
            _app->m_warningOptions.watchColor = watchAlertColor;
            _app->rerenderAll();
        }
    }
}

- (uint32_t)statementAlertColor {
    @synchronized (self) {
        if (!_initialized) return 0;
        return _app->m_warningOptions.statementColor;
    }
}

- (void)setStatementAlertColor:(uint32_t)statementAlertColor {
    @synchronized (self) {
        if (!_initialized) return;
        if (statementAlertColor != _app->m_warningOptions.statementColor) {
            _app->m_warningOptions.statementColor = statementAlertColor;
            _app->rerenderAll();
        }
    }
}

- (uint32_t)advisoryAlertColor {
    @synchronized (self) {
        if (!_initialized) return 0;
        return _app->m_warningOptions.advisoryColor;
    }
}

- (void)setAdvisoryAlertColor:(uint32_t)advisoryAlertColor {
    @synchronized (self) {
        if (!_initialized) return;
        if (advisoryAlertColor != _app->m_warningOptions.advisoryColor) {
            _app->m_warningOptions.advisoryColor = advisoryAlertColor;
            _app->rerenderAll();
        }
    }
}

- (uint32_t)fireAlertColor {
    @synchronized (self) {
        if (!_initialized) return 0;
        return _app->m_warningOptions.fireColor;
    }
}

- (void)setFireAlertColor:(uint32_t)fireAlertColor {
    @synchronized (self) {
        if (!_initialized) return;
        if (fireAlertColor != _app->m_warningOptions.fireColor) {
            _app->m_warningOptions.fireColor = fireAlertColor;
            _app->rerenderAll();
        }
    }
}

- (uint32_t)marineAlertColor {
    @synchronized (self) {
        if (!_initialized) return 0;
        return _app->m_warningOptions.marineColor;
    }
}

- (void)setMarineAlertColor:(uint32_t)marineAlertColor {
    @synchronized (self) {
        if (!_initialized) return;
        if (marineAlertColor != _app->m_warningOptions.marineColor) {
            _app->m_warningOptions.marineColor = marineAlertColor;
            _app->rerenderAll();
        }
    }
}

- (uint32_t)otherAlertColor {
    @synchronized (self) {
        if (!_initialized) return 0;
        return _app->m_warningOptions.otherColor;
    }
}

- (void)setOtherAlertColor:(uint32_t)otherAlertColor {
    @synchronized (self) {
        if (!_initialized) return;
        if (otherAlertColor != _app->m_warningOptions.otherColor) {
            _app->m_warningOptions.otherColor = otherAlertColor;
            _app->rerenderAll();
        }
    }
}

#pragma mark - Archive playback

- (NSArray<RadarHistoricEventInfo *> *)historicEvents {
    NSMutableArray<RadarHistoricEventInfo *> *events = [NSMutableArray arrayWithCapacity:NUM_HISTORIC_EVENTS];
    for (int i = 0; i < NUM_HISTORIC_EVENTS; i++) {
        const auto& event = HISTORIC_EVENTS[i];
        RadarHistoricEventInfo *info = [[RadarHistoricEventInfo alloc] init];
        info.name = [NSString stringWithUTF8String:event.name];
        info.station = [NSString stringWithUTF8String:event.station];
        info.eventDescription = [NSString stringWithUTF8String:event.description];
        info.year = event.year;
        info.month = event.month;
        info.day = event.day;
        info.startHour = event.start_hour;
        info.startMinute = event.start_min;
        info.endHour = event.end_hour;
        info.endMinute = event.end_min;
        [events addObject:info];
    }
    return [events copy];
}

- (RadarArchiveStatus *)archiveStatus {
    RadarArchiveStatus *status = [[RadarArchiveStatus alloc] init];

    @synchronized (self) {
        if (!_initialized) {
            status.label = @"";
            status.station = @"";
            status.frameTimestamp = @"";
            status.errorMessage = @"";
            return status;
        }

        status.active = _app->m_historicMode ? YES : NO;
        status.loading = _app->m_historic.loading() ? YES : NO;
        status.loaded = _app->m_historic.loaded() ? YES : NO;
        status.playing = _app->m_historic.playing() ? YES : NO;
        status.currentFrame = _app->m_historic.currentFrame();
        status.totalFrames = _app->m_historic.numFrames();
        status.downloadedFrames = _app->m_historic.downloadedFrames();
        status.playbackFPS = _app->m_historic.speed();
        status.label = [NSString stringWithUTF8String:_app->m_historic.currentLabel().c_str()];
        status.station = [NSString stringWithUTF8String:_app->m_historic.currentStation().c_str()];
        status.errorMessage = [NSString stringWithUTF8String:_app->m_historic.lastError().c_str()];

        const RadarFrame* frame = _app->m_historic.frame(_app->m_historic.currentFrame());
        if (frame && !frame->timestamp.empty()) {
            status.frameTimestamp = [NSString stringWithUTF8String:frame->timestamp.c_str()];
        } else {
            status.frameTimestamp = @"";
        }
    }

    return status;
}

- (RadarLiveLoopStatus *)liveLoopStatus {
    RadarLiveLoopStatus *status = [[RadarLiveLoopStatus alloc] init];

    @synchronized (self) {
        if (!_initialized) {
            status.label = @"";
            return status;
        }

        status.enabled = _app->liveLoopEnabled() ? YES : NO;
        status.loading = _app->liveLoopBackfillLoading() ? YES : NO;
        status.playing = _app->liveLoopPlaying() ? YES : NO;
        status.viewingHistory = _app->liveLoopViewingHistory() ? YES : NO;
        status.currentFrame = _app->liveLoopPlaybackFrame();
        status.availableFrames = _app->liveLoopAvailableFrames();
        status.targetFrames = _app->liveLoopTargetFrames();
        status.maxFrames = _app->liveLoopMaxFrames();
        status.playbackFPS = _app->liveLoopSpeed();
        std::string label = _app->liveLoopCurrentLabel();
        status.label = label.empty() ? @"" : [NSString stringWithUTF8String:label.c_str()];
    }

    return status;
}

- (void)loadHistoricEvent:(int)idx {
    @synchronized (self) {
        if (!_initialized) return;
        _app->loadHistoricEvent(idx);
    }
}

- (BOOL)loadArchiveRangeForStation:(NSString *)station
                              year:(int)year
                             month:(int)month
                               day:(int)day
                         startHour:(int)startHour
                       startMinute:(int)startMinute
                           endHour:(int)endHour
                         endMinute:(int)endMinute {
    @synchronized (self) {
        if (!_initialized) return NO;
        std::string stationCode = station ? std::string(station.UTF8String) : std::string();
        const bool loaded = _app->loadArchiveRange(stationCode, year, month, day,
                                                   startHour, startMinute,
                                                   endHour, endMinute);
        if (loaded) {
            _app->rerenderAll();
        }
        return loaded ? YES : NO;
    }
}

- (void)toggleArchivePlayback {
    @synchronized (self) {
        if (!_initialized || !_app->m_historicMode) return;
        _app->m_historic.togglePlay();
        _app->rerenderAll();
    }
}

- (void)toggleLiveLoopPlayback {
    @synchronized (self) {
        if (!_initialized || _app->m_historicMode) return;
        _app->toggleLiveLoopPlayback();
        _app->rerenderAll();
    }
}

- (void)setLiveLoopFrame:(int)frame {
    @synchronized (self) {
        if (!_initialized || _app->m_historicMode) return;
        _app->setLiveLoopPlaybackFrame(frame);
        _app->rerenderAll();
    }
}

- (void)setLiveLoopLength:(int)frames {
    @synchronized (self) {
        if (!_initialized || _app->m_historicMode) return;
        _app->setLiveLoopLength(frames);
        _app->rerenderAll();
    }
}

- (void)goToLiveLoopLatestFrame {
    @synchronized (self) {
        if (!_initialized || _app->m_historicMode) return;
        _app->goToLiveLoopLatestFrame();
        _app->rerenderAll();
    }
}

- (void)setArchivePlaying:(BOOL)playing {
    @synchronized (self) {
        if (!_initialized || !_app->m_historicMode) return;
        if ((bool)playing != _app->m_historic.playing()) {
            _app->m_historic.togglePlay();
            _app->rerenderAll();
        }
    }
}

- (void)setArchiveFrame:(int)frame {
    @synchronized (self) {
        if (!_initialized || !_app->m_historicMode) return;
        _app->m_historic.setFrame(frame);
        _app->m_lastHistoricFrame = -1;
        _app->rerenderAll();
    }
}

- (void)setArchivePlaybackSpeed:(float)fps {
    @synchronized (self) {
        if (!_initialized) return;
        _app->m_historic.setSpeed(std::max(1.0f, std::min(fps, 15.0f)));
    }
}

- (void)returnToLiveRadar {
    [self refreshData];
}

#pragma mark - Viewport state

- (double)centerLat {
    @synchronized (self) {
        if (!_initialized) return 39.0;
        return _app->viewport().center_lat;
    }
}

- (double)centerLon {
    @synchronized (self) {
        if (!_initialized) return -98.0;
        return _app->viewport().center_lon;
    }
}

- (double)zoom {
    @synchronized (self) {
        if (!_initialized) return 28.0;
        return _app->viewport().zoom;
    }
}

- (void)setViewportCenter:(double)lat lon:(double)lon zoom:(double)zoom {
    @synchronized (self) {
        if (!_initialized) return;
        Viewport& vp = _app->viewport();
        vp.center_lat = lat;
        vp.center_lon = lon;
        vp.zoom = zoom;
        _app->rerenderAll();
    }
}

- (float)cursorLat {
    @synchronized (self) {
        if (!_initialized) return 0.0f;
        return _app->cursorLat();
    }
}

- (float)cursorLon {
    @synchronized (self) {
        if (!_initialized) return 0.0f;
        return _app->cursorLon();
    }
}

#pragma mark - SRV

- (BOOL)srvMode {
    @synchronized (self) {
        if (!_initialized) return NO;
        return _app->srvMode() ? YES : NO;
    }
}

- (void)setSrvMode:(BOOL)srvMode {
    @synchronized (self) {
        if (!_initialized) return;
        if ((bool)srvMode != _app->srvMode()) {
            _app->toggleSRV();
        }
    }
}

- (float)stormSpeed {
    @synchronized (self) {
        if (!_initialized) return 15.0f;
        return _app->stormSpeed();
    }
}

- (void)setStormSpeed:(float)stormSpeed {
    @synchronized (self) {
        if (!_initialized) return;
        _app->setStormMotion(stormSpeed, _app->stormDir());
    }
}

- (float)stormDir {
    @synchronized (self) {
        if (!_initialized) return 225.0f;
        return _app->stormDir();
    }
}

- (void)setStormDir:(float)stormDir {
    @synchronized (self) {
        if (!_initialized) return;
        _app->setStormMotion(_app->stormSpeed(), stormDir);
    }
}

#pragma mark - Threshold

- (float)dbzThreshold {
    @synchronized (self) {
        if (!_initialized) return 5.0f;
        return _app->dbzMinThreshold();
    }
}

- (void)setDbzThreshold:(float)dbzThreshold {
    @synchronized (self) {
        if (!_initialized) return;
        _app->setDbzMinThreshold(dbzThreshold);
    }
}

@end
