#ifndef MET_ENGINE_FFI_H
#define MET_ENGINE_FFI_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct MetEngine MetEngine;
typedef uint64_t MetSoundingRequestId;

typedef struct MetConfig {
    uint32_t cache_capacity_frames;
    float scene_radius_m;
    bool enable_debug_gradient;
} MetConfig;

typedef struct MetPoint {
    double lat_deg;
    double lon_deg;
} MetPoint;

typedef struct MetPlotRequest {
    char palette_name[32];
    uint32_t width;
    uint32_t height;
} MetPlotRequest;

typedef struct MetU16Slice {
    const uint16_t* data;
    size_t len;
} MetU16Slice;

typedef struct MetU8Slice {
    const uint8_t* data;
    size_t len;
} MetU8Slice;

typedef struct MetSweepMomentDescriptor {
    uint8_t moment;
    float elevation_deg;
    uint16_t radial_count;
    uint16_t gate_count;
    float first_gate_m;
    float gate_spacing_m;
    float scale;
    float offset;
    uint16_t missing_code;
    uint16_t azimuth_lut_len;
} MetSweepMomentDescriptor;

typedef struct MetSweepMomentSnapshot {
    MetSweepMomentDescriptor descriptor;
    MetU16Slice bin_codes;
    MetU16Slice azimuths_deg_x100;
    MetU16Slice azimuth_to_radial_lut;
    MetU8Slice valid_mask;
} MetSweepMomentSnapshot;

typedef struct MetFrameSnapshot {
    char station_id[8];
    uint64_t volume_id;
    int64_t generated_at_unix_ms;
    double origin_lat_deg;
    double origin_lon_deg;
    float meters_per_unit;
    float scene_radius_m;
    float render_scale_hint;
    const MetSweepMomentSnapshot* sweeps;
    size_t sweep_count;
    const uint16_t* model_overlay_values;
    size_t model_overlay_len;
    uint16_t model_overlay_width;
    uint16_t model_overlay_height;
    float model_overlay_scale;
    float model_overlay_offset;
    void* retained_handle;
} MetFrameSnapshot;

typedef struct MetSoundingLevel {
    float pressure_hpa;
    float height_m;
    float temperature_c;
    float dewpoint_c;
    float u_wind_ms;
    float v_wind_ms;
} MetSoundingLevel;

typedef struct MetSoundingResult {
    float cape_jkg;
    float cin_jkg;
    float lcl_m;
    float lfc_m;
    float srh_0_1km_m2s2;
    const MetSoundingLevel* levels;
    size_t level_count;
    void* retained_handle;
} MetSoundingResult;

typedef struct MetImage {
    uint32_t width;
    uint32_t height;
    const uint8_t* rgba_bytes;
    size_t rgba_len;
    void* retained_handle;
} MetImage;

MetEngine* met_engine_create(const MetConfig* config);
void met_engine_destroy(MetEngine* engine);

void met_engine_ingest_l2_chunk(MetEngine* engine, const uint8_t* data, size_t len);
void met_engine_set_station(MetEngine* engine, const char* station_id);
void met_engine_set_time(MetEngine* engine, int64_t unix_ms);

bool met_engine_get_latest_frame(MetEngine* engine, MetFrameSnapshot* out_snapshot);
void met_engine_release_frame(MetFrameSnapshot* snapshot);

bool met_engine_request_sounding(MetEngine* engine, MetPoint point, MetSoundingRequestId* out_request_id);
bool met_engine_poll_sounding(MetEngine* engine, MetSoundingRequestId request_id, MetSoundingResult* out_result);
void met_sounding_result_free(MetSoundingResult* result);

bool met_engine_render_plot(MetEngine* engine, const MetPlotRequest* request, MetImage* out_image);
void met_image_free(MetImage* image);

#ifdef __cplusplus
}
#endif

#endif
