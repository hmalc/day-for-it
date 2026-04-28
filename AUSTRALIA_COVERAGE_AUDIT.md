# dayforit Australia Coverage Audit

Last reviewed: 2026-04-28

## Decision

Do not present dayforit as a fully equivalent Australia-wide marine app yet.

The reliable national layer is Bureau of Meteorology coastal forecasts, coastal observations, and marine warning RSS. The richer local layer of tide samples, tide extrema, observed wave height, wave period, wave direction, and sea-surface temperature is currently implemented only for Queensland official open-data feeds.

The app now exposes selected interstate areas as "Official forecast only" so users can get the same scoring interface from official BOM sources without implying Queensland-grade local data density.

## Implemented Coverage Tiers

| Tier | Areas | Inputs | User-facing expectation |
| --- | --- | --- | --- |
| Full Queensland | Listed Queensland locations and manual/current Queensland coastal coordinates | BOM coastal forecast, BOM observations, BOM marine warnings, Queensland tide predictions, Queensland wave observations | Full day score with tide card and local wave observation context where available |
| Official forecast only | Byron Bay, Sydney Harbour, Melbourne Bay, Adelaide Gulf, Rottnest / Fremantle, Hobart Estuary, Darwin Harbour | BOM coastal forecast, BOM observations, BOM marine warning RSS | Score and forecast context only; tide and live wave detail unavailable |

## Official Source Findings

- BOM publishes coastal waters forecast products for each state and territory: NSW `IDN11001`, VIC `IDV10200`, QLD `IDQ11290`, WA `IDW11160`, SA `IDS11072`, TAS `IDT12329`, and NT `IDD11030`.
- BOM coastal forecast services cover local/coastal waters and are updated multiple times per day, but the Bureau notes coastal zones are broad and cannot describe all local inshore/offshore variation.
- BOM marine RSS feeds exist for NSW, VIC, QLD, WA, SA, TAS, and NT.
- BOM tide predictions cover many Australian locations, but the app does not yet have a validated national machine-readable tide provider with station binding, sampling, and attribution equivalent to the current Queensland implementation.
- Queensland has official open-data tide prediction CSV packages and near-real-time wave CSV data that fit the current app architecture.
- NSW and WA have promising official wave/tide data sources, but they are separate state implementations and need provider-specific validation before being treated as equivalent.

## Product Guardrails

- Non-Queensland locations must be labelled forecast-only in Settings.
- Non-Queensland locations must not receive Queensland tide stations by nearest-distance fallback.
- Manual and current-location support outside Queensland should remain near explicitly configured coastal presets until the app has verified national zone/station binding.
- App Store copy should avoid "Australia-wide tides", "Australia-wide waves", "live national marine conditions", or similar claims until those providers exist.

## Recommended Next Steps

1. Add NSW as the next full-quality state candidate because NSW has official Manly Hydraulics Laboratory wave data and BOM tide prediction coverage.
2. Validate whether BOM tide predictions can be consumed through a stable, attributed machine-readable endpoint across Australia.
3. Add provider health/status strings before ingesting any un-quality-controlled or intermittently available state wave/tide feeds.
4. Expand from curated presets to full coast-by-coast region support only after every region has explicit BOM coastal AAC, observation station, timezone, and source coverage metadata.
