# CIVICSETU

CIVICSETU is a Flutter-based Android app for civic issue reporting and multi-stakeholder resolution tracking.

The old React/Vite code has been removed. This repository now contains the Flutter app plus a secure AI backend proxy for image-to-report drafting.

## Repository Layout

- `civicsetu_flutter/` - main Flutter application
- `backend/auto-report-proxy/` - secure AI image analysis backend for auto-report drafts
- `README.md` - root project overview
- `.gitignore` - GitHub-safe ignore rules for Flutter, Android, and local machine files

## Key Features

- Citizen, authority, contractor, and NGO portals
- In-app complaint camera for direct issue capture
- Auto location fetch for complaint raising
- AI-assisted complaint draft generation with short review and auto-submit flow
- OpenStreetMap preview
- Speech-to-text support
- Duplicate issue detection
- Suspicious review spike freeze and manual review flow
- Authority proof upload and citizen verification before closure
- Comments, bids, donations, and NGO requests
- State quality rankings
- English, Hindi, Tamil, Marathi, and Kannada support

## Important Files

- `civicsetu_flutter/lib/main.dart`
- `civicsetu_flutter/lib/app_store.dart`
- `civicsetu_flutter/lib/models.dart`
- `civicsetu_flutter/lib/localization.dart`
- `civicsetu_flutter/lib/screens/landing_screen.dart`
- `civicsetu_flutter/lib/screens/citizen_portal.dart`
- `civicsetu_flutter/lib/screens/complaint_camera_screen.dart`
- `civicsetu_flutter/lib/screens/authority_portal.dart`
- `civicsetu_flutter/lib/screens/contractor_portal.dart`
- `civicsetu_flutter/lib/screens/ngo_portal.dart`
- `civicsetu_flutter/lib/utils/location_service.dart`
- `civicsetu_flutter/lib/widgets/common_widgets.dart`

## Run Locally

From `civicsetu_flutter/`:

```bash
flutter pub get
flutter run
```

Build an APK:

```bash
flutter build apk
```

Run the local AI proxy:

```bash
cd backend/auto-report-proxy
npm install
npm start
```

Then run Flutter with the backend endpoint:

```bash
flutter run --dart-define=CIVICSETU_AUTOREPORT_ENDPOINT=http://10.0.2.2:8787/v1/analyze-complaint-image
```

## GitHub Push Steps

From the repository root:

```bash
git init
git branch -M main
git add .
git commit -m "Initial Flutter app commit"
git remote add origin <your-github-repo-url>
git push -u origin main
```

## Notes

- The app currently uses seeded in-memory demo data.
- Login is role-based demo access and is not connected to a database.
- The camera flow uses the in-app Flutter camera screen and live device location.
- Complaint title, category, and description can now be AI-drafted from the captured image, then short-reviewed before optional auto-submit.
- The OpenAI key belongs only on the backend proxy, never inside the Android app.
- APKs, local SDK paths, Gradle caches, and other machine-specific files are intentionally ignored for GitHub.
