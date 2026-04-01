use radar_domain::{SoundingAnalysis, SoundingProfileLevel};

#[derive(Default)]
pub struct SoundingEngine;

impl SoundingEngine {
    pub fn analyze(&self, profile: &[SoundingProfileLevel]) -> SoundingAnalysis {
        if profile.is_empty() {
            return SoundingAnalysis::default();
        }

        let surface = profile[0];
        let mid_level = profile.get(profile.len() / 2).copied().unwrap_or(surface);
        let dewpoint_depression = (surface.temperature_c - surface.dewpoint_c).max(0.0);
        let bulk_shear = ((mid_level.u_wind_ms - surface.u_wind_ms).powi(2)
            + (mid_level.v_wind_ms - surface.v_wind_ms).powi(2))
        .sqrt();

        SoundingAnalysis {
            cape_jkg: (surface.temperature_c.max(0.0) * 55.0 + bulk_shear * 35.0).max(0.0),
            cin_jkg: -(dewpoint_depression * 18.0),
            lcl_m: 125.0 * dewpoint_depression,
            lfc_m: 125.0 * dewpoint_depression + 650.0,
            srh_0_1km_m2s2: bulk_shear * 22.0,
        }
    }
}
