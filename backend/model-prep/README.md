# Model Prep

The iPhone app should consume app-ready model fields and profiles, not raw GRIB2/Zarr.

This service is expected to:

- ingest HRRR/RAP or equivalent source data
- subset only required fields
- emit quantized 2D tiles or station-local grids
- emit profile payloads for sounding requests
- cache by model, run, forecast hour, and field

This repo currently ships only the contract boundary, not the service implementation.
