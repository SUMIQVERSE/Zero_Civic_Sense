# CIVICSETU Flutter

This folder contains the Flutter Android app for CIVICSETU.

## What is included

- Android-ready Flutter project structure
- Multi-role mobile app flow for:
  - Citizen
  - Authority
  - Contractor
  - NGO
- In-memory seed data and business logic for:
  - duplicate issue detection
  - suspicious rating spike freeze
  - contractor bidding
  - NGO requests
  - resolution proof upload
  - citizen verification before closure
  - comments and donations
  - state quality rankings
- Multi-language UI foundation:
  - English
  - Hindi
  - Tamil
  - Marathi
  - Kannada
- Citizen mobile features:
  - image picking
  - speech-to-text integration hook
  - geolocation
  - OpenStreetMap preview via `flutter_map`
  - AI-assisted image-to-complaint draft flow via secure backend endpoint

## Important files

- `lib/main.dart`
- `lib/app_store.dart`
- `lib/models.dart`
- `lib/localization.dart`
- `lib/screens/citizen_portal.dart`
- `lib/screens/authority_portal.dart`
- `lib/screens/contractor_portal.dart`
- `lib/screens/ngo_portal.dart`
- `lib/screens/landing_screen.dart`
- `lib/widgets/common_widgets.dart`

## Run locally

From this folder:

```bash
flutter pub get
flutter run
```

For an APK build:

```bash
flutter build apk
```

To enable AI drafting, first start the root-level backend proxy and then run with:

```bash
flutter run --dart-define=CIVICSETU_AUTOREPORT_ENDPOINT=http://10.0.2.2:8787/v1/analyze-complaint-image
```

## Notes

- This Flutter app currently uses seeded in-memory demo data.
- The repository root is GitHub-ready and intentionally ignores local Flutter/Android generated files.
- The AI image analysis flow expects a backend proxy to hold the OpenAI key securely.
- If `flutter pub get` fails on another machine, confirm that Flutter, Android SDK, and Java 17 are installed correctly.
