# Radar Gateway

The iPhone app should not crawl NOAA or AWS object listings directly in the hot path.

This service is expected to:

- normalize upstream Level II paths
- expose `latest` and chunk/volume lookup endpoints
- hide upstream naming changes from the app
- cache short-lived metadata close to the client

The app contract is intentionally small and station-centric.
