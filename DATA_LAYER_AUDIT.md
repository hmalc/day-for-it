# dayforit Data Layer Audit

Last reviewed: 2026-04-28

## Current Live Inputs

- Bureau of Meteorology coastal waters forecast XML, keyed by state product and coastal AAC. Used for forecast wind, seas/swell, rainfall heuristics, warnings context, and daily scoring in configured Australian coastal areas.
- Bureau of Meteorology coastal observation JSON, keyed by FWO product and WMO station. Used for recent observed wind and gusts when fresh enough for the current day.
- Bureau of Meteorology marine warning RSS. Used as a warning cap and surfaced in the UI.
- Maritime Safety Queensland / Queensland Government tide prediction CSV resources. Used for tide samples, tide extrema, daily tide suitability, and tide charts in Queensland coverage areas.
- Queensland Government Coastal Data System near-real-time wave CSV. Used for latest nearby observed significant wave height, maximum wave height, peak/zero-crossing periods, wave direction, and sea-surface temperature in Queensland coverage areas.

## Improvements Made

- Preserved normalized tide high/low events instead of dropping them after tide ingestion.
- Added richer tide summaries that include high/low event counts.
- Split BOM sea/swell parsing so forecast swell is now retained separately from combined sea-state height.
- Stopped mapping BOM `air_temp` into `seaTempC`; that field now stays unavailable unless a true marine surface source provides it.
- Parsed BOM observation timestamps in the selected location timezone instead of assuming Sydney time.
- Added Queensland near-real-time wave observations as an official open-data input.
- Let current-day scoring include fresh observed wind and wave values while using the more conservative of forecast and observed conditions.
- Added nearest-station selection for Queensland BOM observations instead of reusing Brisbane observations for every Queensland location.
- Added quantified driver strings such as observed wind, observed waves, forecast seas, swell, peak period, and sea-surface temperature.
- Updated Settings attribution for Queensland wave data.
- Added conservative forecast-only presets for selected non-Queensland Australian boating areas using official BOM coastal forecast, observation, and marine warning products.
- Added a Queensland tide-provider boundary guard so non-Queensland locations cannot silently inherit the nearest Queensland tide station.

## Integrity Notes

- BOM coastal forecasts describe broad average coastal-zone conditions, not exact local point conditions. The app should keep presenting scores as planning guidance.
- BOM coastal observation stations can be inland or land-exposed enough to differ from offshore conditions. Observed wind is useful, but still not definitive.
- Queensland wave observations are buoy observations, so they are strong current-condition signals near the buoy but should not be stretched too far along the coast.
- Tide samples and events remain tied to the nearest available official tide station. The selected station and distance should remain visible when the nearest station is far away.
- The score now mixes forecast and observation signals for today, but rougher/stronger forecast values still dominate the score. Future-day scores remain forecast-led.
- Non-Queensland presets are intentionally forecast-only. They should not show tide charts, live wave observations, sea-surface temperature, or claims of full local equivalence until state-specific official data providers are implemented.
- Current-location and manual-location support outside Queensland stays near the explicitly configured forecast-only coastal areas. This avoids accidentally applying a state capital feed to distant coastline.

## Candidate Sources For Future Density

- Queensland historical wave datasets: useful for location-specific climatology, seasonal baselines, and "typical for this coast" context.
- NSW Manly Hydraulics Laboratory / NSW Government wave data: promising for adding NSW observed wave density after API stability and terms are validated.
- WA Department of Transport tide and wave services: promising but the real-time pages note intermittent issues and un-quality-controlled data, so this should be added only with clear status messaging.
- BOM ocean forecasts / BLUElink products: promising for sea-surface temperature, currents, salinity, and sea-level anomaly context if a stable machine-readable endpoint is acceptable.
- BOM warning details beyond RSS titles: useful for valid windows, issue time, warning area matching, and stronger auditability.
- More observation fields from BOM FWO JSON: visibility, humidity, rain trace, and air temperature can enrich comfort/context strings, as long as labels remain precise.
- Tide station metadata: maintaining explicit station IDs in presets would improve reproducibility versus nearest-station lookup alone.

## Next Priority

Implement warning valid-window parsing and source-object area matching. That would reduce over-broad warning caps and make warning-limited scores more explainable.
