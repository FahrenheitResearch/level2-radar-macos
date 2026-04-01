#import <Foundation/Foundation.h>
#import <Metal/Metal.h>

NS_ASSUME_NONNULL_BEGIN

@interface RadarStationInfo : NSObject
@property (nonatomic, copy) NSString *icao;
@property (nonatomic, copy) NSString *siteName;
@property (nonatomic, copy) NSString *stateCode;
@property (nonatomic) float lat, lon;
@property (nonatomic) float displayLat, displayLon;
@property (nonatomic) BOOL loaded;
@property (nonatomic) BOOL downloading;
@property (nonatomic) int index;
@property (nonatomic, copy) NSString *scanTime;
@property (nonatomic, copy) NSString *errorMessage;
@property (nonatomic) int sweepCount;
@property (nonatomic) float lowestElevationDeg;
@property (nonatomic) int tdsCount;
@property (nonatomic) int hailCount;
@property (nonatomic) int mesoCount;
@property (nonatomic) float decodeMs;
@property (nonatomic) float parseMs;
@property (nonatomic) float sweepBuildMs;
@property (nonatomic) float preprocessMs;
@property (nonatomic) float detectionMs;
@property (nonatomic) float uploadMs;
@end

@interface RadarHistoricEventInfo : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *station;
@property (nonatomic, copy) NSString *eventDescription;
@property (nonatomic) int year;
@property (nonatomic) int month;
@property (nonatomic) int day;
@property (nonatomic) int startHour;
@property (nonatomic) int startMinute;
@property (nonatomic) int endHour;
@property (nonatomic) int endMinute;
@end

@interface RadarArchiveStatus : NSObject
@property (nonatomic) BOOL active;
@property (nonatomic) BOOL loading;
@property (nonatomic) BOOL loaded;
@property (nonatomic) BOOL playing;
@property (nonatomic) int currentFrame;
@property (nonatomic) int totalFrames;
@property (nonatomic) int downloadedFrames;
@property (nonatomic) float playbackFPS;
@property (nonatomic, copy) NSString *label;
@property (nonatomic, copy) NSString *station;
@property (nonatomic, copy) NSString *frameTimestamp;
@property (nonatomic, copy) NSString *errorMessage;
@end

@interface RadarLiveLoopStatus : NSObject
@property (nonatomic) BOOL enabled;
@property (nonatomic) BOOL loading;
@property (nonatomic) BOOL playing;
@property (nonatomic) BOOL viewingHistory;
@property (nonatomic) int currentFrame;
@property (nonatomic) int availableFrames;
@property (nonatomic) int targetFrames;
@property (nonatomic) int maxFrames;
@property (nonatomic) float playbackFPS;
@property (nonatomic, copy) NSString *label;
@end

@interface RadarEngine : NSObject

// Lifecycle
- (BOOL)initializeWithDevice:(id<MTLDevice>)device width:(int)w height:(int)h;
- (void)shutdown;

// Per-frame
- (void)updateWithDeltaTime:(float)dt;
- (void)render;
- (BOOL)needsRender;

// Output
- (id<MTLBuffer> _Nullable)outputBuffer;
- (int)viewportWidth;
- (int)viewportHeight;

// Viewport gestures
- (void)panByDx:(double)dx dy:(double)dy;
- (void)zoomAtLat:(double)lat lon:(double)lon magnification:(double)mag;
- (void)zoomAtScreenX:(double)x y:(double)y magnification:(double)mag;
- (void)zoomByMagnification:(double)mag;
- (void)tapAtScreenX:(double)x y:(double)y;
- (void)resizeWidth:(int)w height:(int)h;

// Product & tilt
@property (nonatomic, readonly) int activeProduct;
@property (nonatomic, readonly) int activeTilt;
@property (nonatomic, readonly) int maxTilts;
@property (nonatomic, readonly) float activeTiltAngle;
@property (nonatomic, readonly) NSString *activeProductName;
- (void)setProduct:(int)product;
- (void)setTilt:(int)tilt;
- (void)nextProduct;
- (void)prevProduct;
- (void)nextTilt;
- (void)prevTilt;
- (int)productCount;
- (NSString *)productNameForIndex:(int)idx;

// Station
@property (nonatomic, readonly) int activeStationIndex;
@property (nonatomic, readonly) NSString *activeStationName;
@property (nonatomic, readonly) int stationsLoaded;
@property (nonatomic, readonly) int stationsTotal;
@property (nonatomic, readonly) int stationsDownloading;
@property (nonatomic, readonly) int warningCount;
- (void)selectStation:(int)idx centerView:(BOOL)center;
- (NSArray<RadarStationInfo *> *)stationList;

// Multi-radar mode
@property (nonatomic) BOOL mosaicMode;
@property (nonatomic) int maxActiveStations;

// Boundary compositing (call after GPU work from previous frame is done)
- (void)compositeBoundaries;
- (void)waitForGpu;

// Data
- (void)refreshData;
@property (nonatomic) BOOL warningsEnabled;
@property (nonatomic) BOOL tornadoAlertsEnabled;
@property (nonatomic) BOOL severeAlertsEnabled;
@property (nonatomic) BOOL floodAlertsEnabled;
@property (nonatomic) BOOL watchAlertsEnabled;
@property (nonatomic) BOOL statementAlertsEnabled;
@property (nonatomic) BOOL advisoryAlertsEnabled;
@property (nonatomic) BOOL fireAlertsEnabled;
@property (nonatomic) BOOL marineAlertsEnabled;
@property (nonatomic) BOOL otherAlertsEnabled;
@property (nonatomic) uint32_t tornadoAlertColor;
@property (nonatomic) uint32_t severeAlertColor;
@property (nonatomic) uint32_t floodAlertColor;
@property (nonatomic) uint32_t watchAlertColor;
@property (nonatomic) uint32_t statementAlertColor;
@property (nonatomic) uint32_t advisoryAlertColor;
@property (nonatomic) uint32_t fireAlertColor;
@property (nonatomic) uint32_t marineAlertColor;
@property (nonatomic) uint32_t otherAlertColor;

// Archive playback
- (NSArray<RadarHistoricEventInfo *> *)historicEvents;
- (RadarArchiveStatus *)archiveStatus;
- (RadarLiveLoopStatus *)liveLoopStatus;
- (void)loadHistoricEvent:(int)idx;
- (void)toggleArchivePlayback;
- (void)toggleLiveLoopPlayback;
- (void)setLiveLoopFrame:(int)frame;
- (void)setLiveLoopLength:(int)frames;
- (void)goToLiveLoopLatestFrame;
- (void)setArchivePlaying:(BOOL)playing;
- (void)setArchiveFrame:(int)frame;
- (void)setArchivePlaybackSpeed:(float)fps;
- (void)returnToLiveRadar;

// Viewport state
@property (nonatomic, readonly) double centerLat;
@property (nonatomic, readonly) double centerLon;
@property (nonatomic, readonly) double zoom;
- (void)setViewportCenter:(double)lat lon:(double)lon zoom:(double)zoom;
@property (nonatomic, readonly) float cursorLat;
@property (nonatomic, readonly) float cursorLon;

// SRV
@property (nonatomic) BOOL srvMode;
@property (nonatomic) float stormSpeed;
@property (nonatomic) float stormDir;

// Threshold
@property (nonatomic) float dbzThreshold;

@end

NS_ASSUME_NONNULL_END
