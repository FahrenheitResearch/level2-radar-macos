use anyhow::Result;
use radar_domain::RadarFrameSnapshot;

#[derive(Default)]
pub struct Level2Assembler {
    buffered_bytes: usize,
}

impl Level2Assembler {
    pub fn ingest_chunk(&mut self, bytes: &[u8]) {
        self.buffered_bytes += bytes.len();
    }

    pub fn buffered_bytes(&self) -> usize {
        self.buffered_bytes
    }

    pub fn try_finalize_volume(&mut self) -> Result<Option<RadarFrameSnapshot>> {
        Ok(None)
    }
}
