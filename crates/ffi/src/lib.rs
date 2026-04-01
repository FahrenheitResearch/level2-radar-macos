use met_engine::{
    MetConfig as CoreMetConfig, MetEngine as CoreMetEngine, MetPoint as CoreMetPoint,
    SoundingRequestId as CoreSoundingRequestId,
};
use radar_domain::{RadarFrameSnapshot, SoundingProfileLevel, SweepMomentDescriptor};
use std::ffi::{c_char, c_void, CStr};
use std::ptr;
use std::slice;
use std::sync::Mutex;

pub struct MetEngine {
    inner: Mutex<CoreMetEngine>,
}

#[repr(C)]
pub struct MetConfig {
    pub cache_capacity_frames: u32,
    pub scene_radius_m: f32,
    pub enable_debug_gradient: bool,
}

#[repr(C)]
pub struct MetPoint {
    pub lat_deg: f64,
    pub lon_deg: f64,
}

#[repr(C)]
pub struct MetPlotRequest {
    pub palette_name: [c_char; 32],
    pub width: u32,
    pub height: u32,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct MetU16Slice {
    pub data: *const u16,
    pub len: usize,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct MetU8Slice {
    pub data: *const u8,
    pub len: usize,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct MetSweepMomentDescriptor {
    pub moment: u8,
    pub elevation_deg: f32,
    pub radial_count: u16,
    pub gate_count: u16,
    pub first_gate_m: f32,
    pub gate_spacing_m: f32,
    pub scale: f32,
    pub offset: f32,
    pub missing_code: u16,
    pub azimuth_lut_len: u16,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct MetSweepMomentSnapshot {
    pub descriptor: MetSweepMomentDescriptor,
    pub bin_codes: MetU16Slice,
    pub azimuths_deg_x100: MetU16Slice,
    pub azimuth_to_radial_lut: MetU16Slice,
    pub valid_mask: MetU8Slice,
}

#[repr(C)]
pub struct MetFrameSnapshot {
    pub station_id: [c_char; 8],
    pub volume_id: u64,
    pub generated_at_unix_ms: i64,
    pub origin_lat_deg: f64,
    pub origin_lon_deg: f64,
    pub meters_per_unit: f32,
    pub scene_radius_m: f32,
    pub render_scale_hint: f32,
    pub sweeps: *const MetSweepMomentSnapshot,
    pub sweep_count: usize,
    pub model_overlay_values: *const u16,
    pub model_overlay_len: usize,
    pub model_overlay_width: u16,
    pub model_overlay_height: u16,
    pub model_overlay_scale: f32,
    pub model_overlay_offset: f32,
    pub retained_handle: *mut c_void,
}

#[repr(C)]
#[derive(Clone, Copy)]
pub struct MetSoundingLevel {
    pub pressure_hpa: f32,
    pub height_m: f32,
    pub temperature_c: f32,
    pub dewpoint_c: f32,
    pub u_wind_ms: f32,
    pub v_wind_ms: f32,
}

#[repr(C)]
pub struct MetSoundingResult {
    pub cape_jkg: f32,
    pub cin_jkg: f32,
    pub lcl_m: f32,
    pub lfc_m: f32,
    pub srh_0_1km_m2s2: f32,
    pub levels: *const MetSoundingLevel,
    pub level_count: usize,
    pub retained_handle: *mut c_void,
}

#[repr(C)]
pub struct MetImage {
    pub width: u32,
    pub height: u32,
    pub rgba_bytes: *const u8,
    pub rgba_len: usize,
    pub retained_handle: *mut c_void,
}

struct RetainedSweep {
    bin_codes: Vec<u16>,
    azimuths_deg_x100: Vec<u16>,
    azimuth_to_radial_lut: Vec<u16>,
    valid_mask: Vec<u8>,
}

struct RetainedFrame {
    sweeps_storage: Vec<RetainedSweep>,
    sweeps: Vec<MetSweepMomentSnapshot>,
    model_overlay_values: Vec<u16>,
}

struct RetainedSoundingResult {
    levels: Vec<MetSoundingLevel>,
}

struct RetainedImage {
    rgba: Vec<u8>,
}

fn copy_station_id(text: &str) -> [c_char; 8] {
    let mut out = [0 as c_char; 8];
    for (idx, byte) in text.as_bytes().iter().take(7).enumerate() {
        out[idx] = *byte as c_char;
    }
    out
}

fn descriptor_to_ffi(descriptor: SweepMomentDescriptor) -> MetSweepMomentDescriptor {
    MetSweepMomentDescriptor {
        moment: descriptor.moment,
        elevation_deg: descriptor.elevation_deg,
        radial_count: descriptor.radial_count,
        gate_count: descriptor.gate_count,
        first_gate_m: descriptor.first_gate_m,
        gate_spacing_m: descriptor.gate_spacing_m,
        scale: descriptor.scale,
        offset: descriptor.offset,
        missing_code: descriptor.missing_code,
        azimuth_lut_len: descriptor.azimuth_lut_len,
    }
}

fn build_retained_frame(frame: RadarFrameSnapshot) -> (MetFrameSnapshot, Box<RetainedFrame>) {
    let RadarFrameSnapshot {
        station_id,
        volume_id,
        generated_at_unix_ms,
        scene,
        sweeps,
        model_overlay,
        render_scale_hint,
    } = frame;

    let mut descriptors = Vec::with_capacity(sweeps.len());
    let mut sweeps_storage = Vec::with_capacity(sweeps.len());
    for sweep in sweeps {
        descriptors.push(descriptor_to_ffi(sweep.descriptor));
        sweeps_storage.push(RetainedSweep {
            bin_codes: sweep.bin_codes,
            azimuths_deg_x100: sweep.azimuths_deg_x100,
            azimuth_to_radial_lut: sweep.azimuth_to_radial_lut,
            valid_mask: sweep.valid_mask.unwrap_or_default(),
        });
    }

    let mut sweeps = Vec::with_capacity(sweeps_storage.len());
    for (storage, descriptor) in sweeps_storage.iter().zip(descriptors.into_iter()) {
        sweeps.push(MetSweepMomentSnapshot {
            descriptor,
            bin_codes: MetU16Slice {
                data: storage.bin_codes.as_ptr(),
                len: storage.bin_codes.len(),
            },
            azimuths_deg_x100: MetU16Slice {
                data: storage.azimuths_deg_x100.as_ptr(),
                len: storage.azimuths_deg_x100.len(),
            },
            azimuth_to_radial_lut: MetU16Slice {
                data: storage.azimuth_to_radial_lut.as_ptr(),
                len: storage.azimuth_to_radial_lut.len(),
            },
            valid_mask: MetU8Slice {
                data: storage.valid_mask.as_ptr(),
                len: storage.valid_mask.len(),
            },
        });
    }

    let (model_overlay_values, model_overlay_width, model_overlay_height, model_overlay_scale, model_overlay_offset) =
        if let Some(overlay) = model_overlay {
            (
                overlay.values,
                overlay.width,
                overlay.height,
                overlay.scale,
                overlay.offset,
            )
        } else {
            (Vec::new(), 0, 0, 0.0, 0.0)
        };

    let retained = Box::new(RetainedFrame {
        sweeps_storage,
        sweeps,
        model_overlay_values,
    });

    let snapshot = MetFrameSnapshot {
        station_id: copy_station_id(&station_id),
        volume_id,
        generated_at_unix_ms,
        origin_lat_deg: scene.origin_lat_deg,
        origin_lon_deg: scene.origin_lon_deg,
        meters_per_unit: scene.meters_per_unit,
        scene_radius_m: scene.scene_radius_m,
        render_scale_hint,
        sweeps: retained.sweeps.as_ptr(),
        sweep_count: retained.sweeps.len(),
        model_overlay_values: retained.model_overlay_values.as_ptr(),
        model_overlay_len: retained.model_overlay_values.len(),
        model_overlay_width,
        model_overlay_height,
        model_overlay_scale,
        model_overlay_offset,
        retained_handle: ptr::null_mut(),
    };

    (snapshot, retained)
}

fn build_retained_sounding_result(
    result: met_engine::SoundingResult,
) -> (MetSoundingResult, Box<RetainedSoundingResult>) {
    let levels = result
        .profile
        .into_iter()
        .map(level_to_ffi)
        .collect::<Vec<_>>();

    let retained = Box::new(RetainedSoundingResult { levels });
    let public = MetSoundingResult {
        cape_jkg: result.analysis.cape_jkg,
        cin_jkg: result.analysis.cin_jkg,
        lcl_m: result.analysis.lcl_m,
        lfc_m: result.analysis.lfc_m,
        srh_0_1km_m2s2: result.analysis.srh_0_1km_m2s2,
        levels: retained.levels.as_ptr(),
        level_count: retained.levels.len(),
        retained_handle: ptr::null_mut(),
    };
    (public, retained)
}

fn build_retained_image(image: met_engine::RgbaImage) -> (MetImage, Box<RetainedImage>) {
    let retained = Box::new(RetainedImage { rgba: image.rgba });
    let public = MetImage {
        width: image.width,
        height: image.height,
        rgba_bytes: retained.rgba.as_ptr(),
        rgba_len: retained.rgba.len(),
        retained_handle: ptr::null_mut(),
    };
    (public, retained)
}

fn level_to_ffi(level: SoundingProfileLevel) -> MetSoundingLevel {
    MetSoundingLevel {
        pressure_hpa: level.pressure_hpa,
        height_m: level.height_m,
        temperature_c: level.temperature_c,
        dewpoint_c: level.dewpoint_c,
        u_wind_ms: level.u_wind_ms,
        v_wind_ms: level.v_wind_ms,
    }
}

fn c_string_or_default(ptr_value: *const c_char, default: &str) -> String {
    if ptr_value.is_null() {
        return default.to_string();
    }
    unsafe { CStr::from_ptr(ptr_value) }
        .to_str()
        .unwrap_or(default)
        .to_string()
}

fn fixed_char_buffer_to_string(buffer: &[c_char]) -> String {
    let len = buffer.iter().position(|ch| *ch == 0).unwrap_or(buffer.len());
    let bytes = buffer[..len].iter().map(|ch| *ch as u8).collect::<Vec<_>>();
    String::from_utf8_lossy(&bytes).to_string()
}

#[no_mangle]
pub extern "C" fn met_engine_create(config: *const MetConfig) -> *mut MetEngine {
    let config = if config.is_null() {
        CoreMetConfig::default()
    } else {
        let config = unsafe { &*config };
        CoreMetConfig {
            cache_capacity_frames: config.cache_capacity_frames as usize,
            scene_radius_m: config.scene_radius_m,
            enable_debug_gradient: config.enable_debug_gradient,
        }
    };

    Box::into_raw(Box::new(MetEngine {
        inner: Mutex::new(CoreMetEngine::new(config)),
    }))
}

#[no_mangle]
pub extern "C" fn met_engine_destroy(engine: *mut MetEngine) {
    if engine.is_null() {
        return;
    }
    unsafe { drop(Box::from_raw(engine)) };
}

#[no_mangle]
pub extern "C" fn met_engine_ingest_l2_chunk(engine: *mut MetEngine, data: *const u8, len: usize) {
    if engine.is_null() || data.is_null() || len == 0 {
        return;
    }

    let bytes = unsafe { slice::from_raw_parts(data, len) };
    let _ = unsafe { &*engine }
        .inner
        .lock()
        .ok()
        .and_then(|mut engine| engine.ingest_l2_chunk(bytes).ok());
}

#[no_mangle]
pub extern "C" fn met_engine_set_station(engine: *mut MetEngine, station_id: *const c_char) {
    if engine.is_null() {
        return;
    }
    let station_id = c_string_or_default(station_id, "KTLX");
    if let Ok(mut engine) = unsafe { &*engine }.inner.lock() {
        engine.set_station(&station_id);
    }
}

#[no_mangle]
pub extern "C" fn met_engine_set_time(engine: *mut MetEngine, unix_ms: i64) {
    if engine.is_null() {
        return;
    }
    if let Ok(mut engine) = unsafe { &*engine }.inner.lock() {
        engine.set_time(unix_ms);
    }
}

#[no_mangle]
pub extern "C" fn met_engine_get_latest_frame(
    engine: *mut MetEngine,
    out_snapshot: *mut MetFrameSnapshot,
) -> bool {
    if engine.is_null() || out_snapshot.is_null() {
        return false;
    }

    let Some(frame) = unsafe { &*engine }
        .inner
        .lock()
        .ok()
        .and_then(|engine| engine.latest_frame())
    else {
        return false;
    };

    let (mut public, retained) = build_retained_frame(frame);
    public.retained_handle = Box::into_raw(retained) as *mut c_void;
    unsafe {
        ptr::write(out_snapshot, public);
    }
    true
}

#[no_mangle]
pub extern "C" fn met_engine_release_frame(snapshot: *mut MetFrameSnapshot) {
    if snapshot.is_null() {
        return;
    }

    let retained_handle = unsafe { (*snapshot).retained_handle };
    if !retained_handle.is_null() {
        unsafe { drop(Box::from_raw(retained_handle as *mut RetainedFrame)) };
    }

    unsafe {
        (*snapshot).retained_handle = ptr::null_mut();
        (*snapshot).sweeps = ptr::null();
        (*snapshot).sweep_count = 0;
        (*snapshot).model_overlay_values = ptr::null();
        (*snapshot).model_overlay_len = 0;
    }
}

#[no_mangle]
pub extern "C" fn met_engine_request_sounding(
    engine: *mut MetEngine,
    point: MetPoint,
    out_request_id: *mut u64,
) -> bool {
    if engine.is_null() || out_request_id.is_null() {
        return false;
    }

    let request_id = unsafe { &*engine }
        .inner
        .lock()
        .ok()
        .and_then(|mut engine| {
            engine
                .request_sounding(CoreMetPoint {
                    lat_deg: point.lat_deg,
                    lon_deg: point.lon_deg,
                })
                .ok()
        });

    let Some(request_id) = request_id else {
        return false;
    };

    unsafe {
        *out_request_id = request_id.0;
    }
    true
}

#[no_mangle]
pub extern "C" fn met_engine_poll_sounding(
    engine: *mut MetEngine,
    request_id: u64,
    out_result: *mut MetSoundingResult,
) -> bool {
    if engine.is_null() || out_result.is_null() {
        return false;
    }

    let result = unsafe { &*engine }
        .inner
        .lock()
        .ok()
        .and_then(|mut engine| engine.poll_sounding(CoreSoundingRequestId(request_id)));

    let Some(result) = result else {
        return false;
    };

    let (mut public, retained) = build_retained_sounding_result(result);
    public.retained_handle = Box::into_raw(retained) as *mut c_void;
    unsafe {
        ptr::write(out_result, public);
    }
    true
}

#[no_mangle]
pub extern "C" fn met_sounding_result_free(result: *mut MetSoundingResult) {
    if result.is_null() {
        return;
    }

    let retained_handle = unsafe { (*result).retained_handle };
    if !retained_handle.is_null() {
        unsafe { drop(Box::from_raw(retained_handle as *mut RetainedSoundingResult)) };
    }

    unsafe {
        (*result).retained_handle = ptr::null_mut();
        (*result).levels = ptr::null();
        (*result).level_count = 0;
    }
}

#[no_mangle]
pub extern "C" fn met_engine_render_plot(
    engine: *mut MetEngine,
    request: *const MetPlotRequest,
    out_image: *mut MetImage,
) -> bool {
    if engine.is_null() || request.is_null() || out_image.is_null() {
        return false;
    }

    let request = unsafe { &*request };
    let palette_name = fixed_char_buffer_to_string(&request.palette_name);
    let image = unsafe { &*engine }
        .inner
        .lock()
        .ok()
        .map(|engine| engine.render_palette_preview(&palette_name, request.width, request.height));

    let Some(image) = image else {
        return false;
    };

    let (mut public, retained) = build_retained_image(image);
    public.retained_handle = Box::into_raw(retained) as *mut c_void;
    unsafe {
        ptr::write(out_image, public);
    }
    true
}

#[no_mangle]
pub extern "C" fn met_image_free(image: *mut MetImage) {
    if image.is_null() {
        return;
    }

    let retained_handle = unsafe { (*image).retained_handle };
    if !retained_handle.is_null() {
        unsafe { drop(Box::from_raw(retained_handle as *mut RetainedImage)) };
    }

    unsafe {
        (*image).retained_handle = ptr::null_mut();
        (*image).rgba_bytes = ptr::null();
        (*image).rgba_len = 0;
    }
}
