use anyhow::Result;
use radar_domain::{ModelOverlaySnapshot, SoundingProfileLevel};

#[derive(Clone, Debug)]
pub struct ModelFieldRequest {
    pub station_id: String,
    pub field: String,
    pub run_id: String,
    pub forecast_hour: u16,
}

#[derive(Clone, Copy, Debug)]
pub struct ModelProfileRequest {
    pub lat_deg: f64,
    pub lon_deg: f64,
}

#[derive(Default)]
pub struct StubModelClient;

impl StubModelClient {
    pub fn fetch_overlay(&self, request: &ModelFieldRequest) -> Result<ModelOverlaySnapshot> {
        let width = 160u16;
        let height = 160u16;
        let mut values = Vec::with_capacity(width as usize * height as usize);
        for y in 0..height {
            for x in 0..width {
                let dx = x as f32 / width as f32 - 0.5;
                let dy = y as f32 / height as f32 - 0.5;
                let radial = (dx * dx + dy * dy).sqrt();
                let base = ((1.0 - radial).max(0.0) * 255.0) as u16;
                values.push(base);
            }
        }

        Ok(ModelOverlaySnapshot {
            field: request.field.clone(),
            width,
            height,
            scale: 1.0,
            offset: 0.0,
            values,
        })
    }

    pub fn fetch_profile(&self, request: ModelProfileRequest) -> Result<Vec<SoundingProfileLevel>> {
        let mut profile = Vec::with_capacity(36);
        for idx in 0..36 {
            let height_m = idx as f32 * 350.0;
            let pressure_hpa = 1000.0 - idx as f32 * 20.0;
            let temperature_c = 24.0 - idx as f32 * 6.3 / 3.0;
            let dewpoint_c = temperature_c - 4.0 - idx as f32 * 0.3;
            let u_wind_ms = 4.0 + idx as f32 * 0.8 + request.lon_deg as f32 * 0.0;
            let v_wind_ms = 2.0 + idx as f32 * 0.45 + request.lat_deg as f32 * 0.0;
            profile.push(SoundingProfileLevel {
                pressure_hpa,
                height_m,
                temperature_c,
                dewpoint_c,
                u_wind_ms,
                v_wind_ms,
            });
        }
        Ok(profile)
    }
}
