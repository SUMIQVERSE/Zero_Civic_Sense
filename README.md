# CIVICSETU

CIVICSETU is a Flutter-based Android app for civic issue reporting and multi-stakeholder resolution tracking.

This repository is now mobile-only. The old React/Vite code has been removed so the project is ready to publish as a clean Flutter GitHub repo.

## Repository Layout

- `civicsetu_flutter/` - main Flutter application
- `README.md` - root project overview
- `.gitignore` - GitHub-safe ignore rules for Flutter, Android, and local machine files

## Key Features

- Citizen, authority, contractor, and NGO portals
- In-app complaint camera for direct issue capture
- Auto location fetch for complaint raising
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
- Complaint title, category, and description are filled manually by the user.
- APKs, local SDK paths, Gradle caches, and other machine-specific files are intentionally ignored for GitHub.
