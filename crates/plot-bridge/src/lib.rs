#[derive(Clone, Copy, Debug)]
pub struct PaletteStop {
    pub value: f32,
    pub rgba: [u8; 4],
}

#[derive(Clone, Debug)]
pub struct PaletteLut {
    pub name: String,
    pub rgba: Vec<u8>,
}

#[derive(Default)]
pub struct PlotBridge;

impl PlotBridge {
    pub fn palette_lut(&self, name: &str) -> PaletteLut {
        let mut rgba = Vec::with_capacity(256 * 4);
        for idx in 0..=255u8 {
            let color = match name {
                "reflectivity" => [idx, idx.saturating_add(24), 255u8.saturating_sub(idx / 2), 255],
                "mlcape" => [255, idx, 32, 210],
                _ => [idx, idx, idx, 255],
            };
            rgba.extend_from_slice(&color);
        }

        PaletteLut {
            name: name.to_string(),
            rgba,
        }
    }
}
