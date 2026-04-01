use radar_domain::{PackedSweepMoment, RadarMomentKind, SweepMomentDescriptor};

pub fn build_azimuth_lut(azimuths_deg_x100: &[u16], lut_len: usize) -> Vec<u16> {
    if azimuths_deg_x100.is_empty() || lut_len == 0 {
        return Vec::new();
    }

    let mut lut = vec![0u16; lut_len];
    let lut_span = 36000usize;

    for slot in 0..lut_len {
        let target = (slot * lut_span) / lut_len;
        let mut best_idx = 0usize;
        let mut best_dist = u16::MAX;

        for (idx, azimuth) in azimuths_deg_x100.iter().enumerate() {
            let az = *azimuth as i32;
            let target = target as i32;
            let direct = (az - target).unsigned_abs() as u16;
            let wrapped = (36000i32 - (az - target).abs()) as u16;
            let dist = direct.min(wrapped);
            if dist < best_dist {
                best_dist = dist;
                best_idx = idx;
            }
        }

        lut[slot] = best_idx as u16;
    }

    lut
}

pub fn pack_debug_sweep(moment: RadarMomentKind, radial_count: u16, gate_count: u16) -> PackedSweepMoment {
    let mut bin_codes = Vec::with_capacity(radial_count as usize * gate_count as usize);
    let azimuths_deg_x100 = (0..radial_count)
        .map(|idx| ((idx as f32 / radial_count.max(1) as f32) * 36000.0) as u16)
        .collect::<Vec<_>>();

    for gate in 0..gate_count {
        for radial in 0..radial_count {
            let radial_wave = (radial as f32 / radial_count.max(1) as f32) * 255.0;
            let gate_wave = (gate as f32 / gate_count.max(1) as f32) * 255.0;
            let value = (0.6 * radial_wave + 0.4 * gate_wave).round() as u16;
            bin_codes.push(value);
        }
    }

    let azimuth_to_radial_lut = build_azimuth_lut(&azimuths_deg_x100, 720);

    PackedSweepMoment {
        descriptor: SweepMomentDescriptor {
            moment: moment as u8,
            elevation_deg: 0.5,
            radial_count,
            gate_count,
            first_gate_m: 250.0,
            gate_spacing_m: 250.0,
            scale: 2.0,
            offset: 64.0,
            missing_code: 0,
            azimuth_lut_len: azimuth_to_radial_lut.len() as u16,
        },
        bin_codes,
        azimuths_deg_x100,
        azimuth_to_radial_lut,
        valid_mask: None,
    }
}
