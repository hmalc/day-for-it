# App Store Prep Audit

Last updated: April 27, 2026

## Addressed In App

- Safety disclaimer is visible in Settings and on the source/update card.
- Settings includes privacy, support, and source/attribution links.
- Location permission copy explains the user-triggered supported coastal-area purpose.
- Privacy manifest declares no tracking, no collected data types, and the UserDefaults required-reason API for app-only preference storage.
- The app does not request background location, accounts, tracking, advertising, analytics, HealthKit, payments, notifications, or user-generated content permissions.
- Pull-to-refresh remains available on Summary and Tides.
- Dynamic Type fallback remains in place for dense forecast layouts.
- Reduce Motion is respected in loading and hero animation paths already present in the app.
- Forecast cards and tide curves now expose clearer VoiceOver labels, hints, and values for the densest custom UI.

## App Store Connect Checklist

- Add Privacy Policy URL: `https://github.com/hmalc/day-for-it/blob/main/PRIVACY.md` after the repository is public and pushed.
- Add Support URL: `https://github.com/hmalc/day-for-it/issues` after the repository is public and pushed, or replace with a public support page.
- Privacy nutrition label should disclose no tracking and no analytics. If answering conservatively, note that current location is optional and used for app functionality; review Apple's definition of "collection" before submission because Day For It processes location on device and does not operate its own server.
- Review notes should state that the app is a marine planning aid with richer local tide/wave detail currently limited to Queensland, uses optional When In Use location only after user action, and is not an emergency alert or navigation product.
- Confirm data-source license and attribution obligations before release, especially Bureau of Meteorology brand-display requirements.
- Test on a physical device with VoiceOver, Larger Text, Reduce Motion, Dark Mode, and poor network conditions.

## Known Pre-Submission Risks

- The app's safety category is weather/marine planning. Keep all marketing copy away from guarantees such as "safe to boat" or "official warning app."
- If the GitHub repository remains private, the privacy/support links will not satisfy App Store Connect.
- The Bureau of Meteorology has specific brand and attribution rules. If formal logo attribution is required for your use case, add the official attribution asset before submission.
