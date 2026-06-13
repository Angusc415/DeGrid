# Google Play release (Android)

## Checklist

1. **Application ID** — `dev.degrid.app` in `android/app/build.gradle.kts`. Do not change after the first production upload (Play treats a new ID as a new app).

2. **Signing**
   - Create an upload keystore (see `android/key.properties.template`).
   - Put `upload-keystore.jks` under `android/` (or another path; update `storeFile` accordingly).
   - Copy `android/key.properties.template` → `android/key.properties` and set passwords and alias.
   - Enable **Play App Signing** in Play Console (Google re-signs with the app signing key).

3. **Version**
   - Bump `version` in `pubspec.yaml`: `major.minor.patch+versionCode` (`versionCode` must increase for every Play upload).

4. **Build**
   ```bash
   flutter build appbundle --release
   ```
   Output: `build/app/outputs/bundle/release/app-release.aab`

5. **Play Console**
   - Store listing: screenshots, feature graphic, descriptions aligned with shipped features.
   - Privacy policy URL (even for local-only data—state that data stays on device).
   - Data safety questionnaire (accurate answers; no analytics/backend ⇒ simpler).
   - Target API / policy requirements: confirm against current [Play requirements](https://developer.android.com/google/play/requirements).

6. **QA**
   - Install release build on a physical device (internal testing track): create project, draw, save, reopen, export PDF if enabled.

## Notes

- Release builds now fail fast when `android/key.properties` or the upload keystore is missing. That is intentional to prevent accidental signing with the wrong key.

- Carpet-related UI is gated by `lib/core/config/feature_flags.dart` (`kEnableCarpetFeatures`).
