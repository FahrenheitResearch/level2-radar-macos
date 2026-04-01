use serde::{Deserialize, Serialize};

#[repr(u8)]
#[derive(Clone, Copy, Debug, Default, Eq, PartialEq, Serialize, Deserialize)]
pub enum RadarMomentKind {
    #[default]
    Reflectivity = 0,
    Velocity = 1,
    SpectrumWidth = 2,
    DifferentialReflectivity = 3,
    CorrelationCoefficient = 4,
    SpecificDifferentialPhase = 5,
    DifferentialPhase = 6,
}

#[repr(C)]
#[derive(Clone, Copy, Debug, Default, Serialize, Deserialize)]
pub struct SweepMomentDescriptor {
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
#[derive(Clone, Copy, Debug, Default, Serialize, Deserialize)]
pub struct LocalXySceneDescriptor {
    pub origin_lat_deg: f64,
    pub origin_lon_deg: f64,
    pub meters_per_unit: f32,
    pub scene_radius_m: f32,
}

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct PackedSweepMoment {
    pub descriptor: SweepMomentDescriptor,
    pub bin_codes: Vec<u16>,
    pub azimuths_deg_x100: Vec<u16>,
    pub azimuth_to_radial_lut: Vec<u16>,
    pub valid_mask: Option<Vec<u8>>,
}

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct ModelOverlaySnapshot {
    pub field: String,
    pub width: u16,
    pub height: u16,
    pub scale: f32,
    pub offset: f32,
    pub values: Vec<u16>,
}

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct RadarFrameSnapshot {
    pub station_id: String,
    pub volume_id: u64,
    pub generated_at_unix_ms: i64,
    pub scene: LocalXySceneDescriptor,
    pub sweeps: Vec<PackedSweepMoment>,
    pub model_overlay: Option<ModelOverlaySnapshot>,
    pub render_scale_hint: f32,
}

#[derive(Clone, Copy, Debug, Default, Serialize, Deserialize)]
pub struct SoundingProfileLevel {
    pub pressure_hpa: f32,
    pub height_m: f32,
    pub temperature_c: f32,
    pub dewpoint_c: f32,
    pub u_wind_ms: f32,
    pub v_wind_ms: f32,
}

#[derive(Clone, Debug, Default, Serialize, Deserialize)]
pub struct SoundingAnalysis {
    pub cape_jkg: f32,
    pub cin_jkg: f32,
    pub lcl_m: f32,
    pub lfc_m: f32,
    pub srh_0_1km_m2s2: f32,
}
