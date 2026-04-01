use anyhow::Result;
use model_client::{ModelFieldRequest, ModelProfileRequest, StubModelClient};
use nexrad_l2::Level2Assembler;
use plot_bridge::PlotBridge;
use radar_domain::{
    LocalXySceneDescriptor, RadarFrameSnapshot, RadarMomentKind, SoundingAnalysis, SoundingProfileLevel,
};
use radar_pack::pack_debug_sweep;
use sounding_engine::SoundingEngine;
use std::collections::HashMap;

#[derive(Clone, Debug)]
pub struct MetConfig {
    pub cache_capacity_frames: usize,
    pub scene_radius_m: f32,
    pub enable_debug_gradient: bool,
}

impl Default for MetConfig {
    fn default() -> Self {
        Self {
            cache_capacity_frames: 12,
            scene_radius_m: 230_000.0,
            enable_debug_gradient: true,
        }
    }
}

#[derive(Clone, Copy, Debug, Default)]
pub struct MetPoint {
    pub lat_deg: f64,
    pub lon_deg: f64,
}

#[derive(Clone, Debug)]
pub struct RgbaImage {
    pub width: u32,
    pub height: u32,
    pub rgba: Vec<u8>,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq, Hash)]
pub struct SoundingRequestId(pub u64);

#[derive(Clone, Debug)]
pub struct SoundingResult {
    pub point: MetPoint,
    pub profile: Vec<SoundingProfileLevel>,
    pub analysis: SoundingAnalysis,
}

pub struct MetEngine {
    config: MetConfig,
    station_id: String,
    current_time_unix_ms: i64,
    next_volume_id: u64,
    next_sounding_id: u64,
    latest_frame: Option<RadarFrameSnapshot>,
    assembler: Level2Assembler,
    model_client: StubModelClient,
    sounding_engine: SoundingEngine,
    plot_bridge: PlotBridge,
    sounding_results: HashMap<SoundingRequestId, SoundingResult>,
}

impl MetEngine {
    pub fn new(config: MetConfig) -> Self {
        let mut engine = Self {
            config,
            station_id: "KTLX".to_string(),
            current_time_unix_ms: 0,
            next_volume_id: 1,
            next_sounding_id: 1,
            latest_frame: None,
            assembler: Level2Assembler::default(),
            model_client: StubModelClient,
            sounding_engine: SoundingEngine,
            plot_bridge: PlotBridge,
            sounding_results: HashMap::new(),
        };
        engine.refresh_debug_frame();
        engine
    }

    pub fn set_station(&mut self, station_id: &str) {
        self.station_id = station_id.to_string();
        self.refresh_debug_frame();
    }

    pub fn set_time(&mut self, unix_ms: i64) {
        self.current_time_unix_ms = unix_ms;
        self.refresh_debug_frame();
    }

    pub fn ingest_l2_chunk(&mut self, bytes: &[u8]) -> Result<()> {
        self.assembler.ingest_chunk(bytes);
        let _ = self.assembler.try_finalize_volume()?;
        self.refresh_debug_frame();
        Ok(())
    }

    pub fn latest_frame(&self) -> Option<RadarFrameSnapshot> {
        self.latest_frame.clone()
    }

    pub fn request_sounding(&mut self, point: MetPoint) -> Result<SoundingRequestId> {
        let profile = self.model_client.fetch_profile(ModelProfileRequest {
            lat_deg: point.lat_deg,
            lon_deg: point.lon_deg,
        })?;
        let analysis = self.sounding_engine.analyze(&profile);
        let request_id = SoundingRequestId(self.next_sounding_id);
        self.next_sounding_id += 1;

        self.sounding_results.insert(
            request_id,
            SoundingResult {
                point,
                profile,
                analysis,
            },
        );

        Ok(request_id)
    }

    pub fn poll_sounding(&mut self, id: SoundingRequestId) -> Option<SoundingResult> {
        self.sounding_results.remove(&id)
    }

    pub fn render_palette_preview(&self, name: &str, width: u32, height: u32) -> RgbaImage {
        let lut = self.plot_bridge.palette_lut(name);
        let mut rgba = Vec::with_capacity(width as usize * height as usize * 4);
        for _y in 0..height {
            for x in 0..width {
                let idx = ((x as f32 / width.max(1) as f32) * 255.0).round() as usize;
                let offset = idx.min(255) * 4;
                rgba.extend_from_slice(&lut.rgba[offset..offset + 4]);
            }
        }
        RgbaImage { width, height, rgba }
    }

    fn refresh_debug_frame(&mut self) {
        let sweep = pack_debug_sweep(RadarMomentKind::Reflectivity, 720, 920);
        let model_overlay = self
            .model_client
            .fetch_overlay(&ModelFieldRequest {
                station_id: self.station_id.clone(),
                field: "mlcape".to_string(),
                run_id: "debug".to_string(),
                forecast_hour: 0,
            })
            .ok();

        self.latest_frame = Some(RadarFrameSnapshot {
            station_id: self.station_id.clone(),
            volume_id: self.next_volume_id,
            generated_at_unix_ms: self.current_time_unix_ms,
            scene: LocalXySceneDescriptor {
                origin_lat_deg: 35.333,
                origin_lon_deg: -97.278,
                meters_per_unit: 1.0,
                scene_radius_m: self.config.scene_radius_m,
            },
            sweeps: vec![sweep],
            model_overlay,
            render_scale_hint: if self.config.enable_debug_gradient { 1.0 } else { 0.75 },
        });
        self.next_volume_id += 1;
    }
}
