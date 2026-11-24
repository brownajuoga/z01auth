# Z01auth — Development Progress & Roadmap

**Current Status:** Frontend complete apart from items that need the backend team or Firebase. Lead-review fixes are in progress.
**Last updated:** November 11, 2026
**Target Platform:** Flutter (Android 6.0+ / API 23+, Chrome Web)
**Backend Architecture:** Go REST API + Firebase Auth & Firestore
**Tests:** `flutter analyze` clean, 31 tests passing

---

## 1. Executive Summary

Z01auth replaces the legacy physical door fingerprint scanner with zero-touch proximity-gated mobile attendance. Attendance accounting preserves the door scanner rule:
- **1st Valid Detection of the Day:** Locks `Time In` (`first_seen_at`) for the day.
- **Subsequent Valid Detections (Heartbeats):** Continuously rolls forward `Time Out` (`last_seen_at`).

The app is **fail-closed**: until a real reading says otherwise, the device is treated as not on campus, biometrics are locked, and nothing is recorded unless the server accepted it.

---

## 2. Completed Milestones

| Step | Date | Commit | Status | Summary of Deliverables |
| :--- | :--- | :--- | :--- | :--- |
| **Step 1** | Oct 17, 2026 | `ea2992d` | Completed | Monochrome theme engine, `ThemeController`, data models, and 4-frame navigation shell. |
| **Step 2** | Oct 17, 2026 | `42f13ff` | Completed | Frame 1 (`01_Auth`) with proximity-gating banner, biometric bottom sheet, and Google sign-in. |
| **Step 3** | Oct 18, 2026 | `af5323e` | Completed | Frame 2 (`02_Permissions`) checklist for fine location, background location, Wi-Fi and biometrics. Android 6.0+ (API 23+). |
| **Step 4** | Oct 19, 2026 | `fcdc008` | Completed | Frame 3 (`03_Dashboard`) with the animated radar ring, verification pills, Time In / Time Out cards, sync button and recent detections. |
| **Step 5** | Oct 20, 2026 | `2e58771` | Completed | Frame 4 (`04_History`) with monthly summary strip, daily log cards and `AttendanceDetailSheet`. |
| **Step 6** | Oct 21, 2026 | `9afe7a2` | Completed | Service layer (`ApiClient`, `AttendanceService`, `BiometricService`, `LocationService`, `WifiService`) matching the Go backend specification. |
| **Step 7** | Oct 27, 2026 | `4bd152d` | Completed | Analytics view (`AnalyticsScreen`), proximity shield hero, launcher icons and brand identity. |
| **Step 8** | Oct 30, 2026 | `677123e` | Completed | Synchronized Go backend API routes, resolved test suite lifecycle, 0 analyzer issues. |
| **Step 9** | Oct 31, 2026 | n/a | Completed | Real `local_auth` biometric sensing, `FlutterFragmentActivity` migration, `ProfileScreen`, header avatar navigation. |
| **Step 10** | Nov 2026 | on `ogero` | In progress | Fixes for the lead's review (section 3). Not yet merged to `main`. |

Design and build work (new theme, restyled screens, Insights tab covering 7 days, app icon and the "Z01 Authentication App" name) is merged to `main`.

---

## 3. Lead Review Findings (F1 to F17)

| # | Finding | Status |
| :--- | :--- | :--- |
| F1 | Dependencies fail on the wrong Flutter version | **Open.** `pubspec.yaml` now requires Flutter `>=3.47.7`. A single pinned version for the team still has to be agreed with the lead (FVM was suggested). |
| F2 | No real authentication | **Open.** Needs Firebase console access. |
| F3 | Made-up data and fake success | **Done.** `api_client.dart` throws typed `ApiException` errors; `attendance_service.dart` records only what the server accepted. Covered by tests. |
| F4 | Wi-Fi and location fail open | **Done.** Both services start "not on campus" and clear on any failure. Placeholder BSSIDs and mock locations are never treated as on campus. |
| F5 | Server trusts client claims | **Open.** Needs a design session with the backend team. |
| F6 | Hardcoded device ID and user | **Open.** Marked TODO; comes with Firebase. `UserService` still holds a placeholder profile. |
| F7 | Permissions screen is cosmetic | **Code complete.** Rows start off and reflect the real OS state; tapping an off row requests it or opens Settings; state is re-read on return from Settings. **Still to verify on a device** (background location "Allow all the time", Wi-Fi row on Android 11+). |
| F8 | Background heartbeat has no token | **Open.** Comes after F2. |
| F9 | Simulated proximity and demo controls | **Done.** The login screen reads real sensors; demo controls are debug-only; the login widget test injects fake services. |
| F10 | Insights shows generated data | **Open.** Needs the real history endpoint. |
| F11 | Heartbeat timing | **Partly done.** Sensors refresh before each heartbeat and overlapping pings are blocked. The 15-minute WorkManager side is untouched. |
| F12 | Times labelled EAT but in device time | **Done.** Server times are shown in Nairobi time. |
| F13 | Starts as "checked in" | **Done.** Starts off premises. |
| F14 | No service tests | **Done for now.** Tests cover Wi-Fi, location, attendance and the API client. |
| F15 | Release config | **Partly done.** Base URL can be set with `--dart-define`; the pubspec description and Flutter constraint are set. Still open: the `com.example.z01auth` app ID, signing with the debug key, and HTTPS. |
| F16 | Documentation drift | **Done** with this update: `progress.readme` duplicate removed, README source tree corrected. |
| F17 | Unused endpoints | **Open.** Ask the backend team which are in scope. |

Other fixes on `ogero`: the dashboard now shows a notice when today's attendance cannot be loaded (`todayLoadFailed`), and biometric availability starts false and stays false after an error or on web.

**Known gap:** `BiometricService.authenticate()` still returns success on web after a short delay. The attendance flow no longer reaches it, but the biometric modal calls it directly.

---

## 4. Feature Checklist

### Frontend UI
- [x] Theme switching via `ThemeController` (reactive `ValueNotifier`).
- [x] In-app `SettingsDrawer` with appearance toggles, background polling toggle, profile shortcut and sign-out.
- [x] `RadarRingPainter` with three states: solid (checked in), dashed (near premises), dotted (off premises).
- [x] Login screen reads real Wi-Fi and GPS state; the proximity toggle is a debug-only control.
- [x] Biometric bottom sheet wired to the physical sensor through `local_auth`.
- [x] `ProfileScreen` with identity, device binding details and biometric diagnostics (placeholder identity until Firebase).
- [x] Time In (locked) and Time Out (rolling) cards, with Nairobi-time display.
- [x] Dashboard notice when today's attendance cannot be loaded, and an empty state for no check-ins.
- [x] History list with API fetching and audit trail sheet.
- [x] Permissions checklist backed by real checks (`PermissionsService`).

### Platform and Android Configuration
- [x] `minSdk = 23` in `android/app/build.gradle.kts`.
- [x] `MainActivity.kt` uses `FlutterFragmentActivity` for `BiometricPrompt`.
- [x] Permissions declared in `AndroidManifest.xml`: `INTERNET`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `ACCESS_WIFI_STATE`, `CHANGE_WIFI_STATE`, `ACCESS_NETWORK_STATE`, `USE_FINGERPRINT`, `USE_BIOMETRIC`, `ACCESS_BACKGROUND_LOCATION`.
- [ ] Final application ID (currently `com.example.z01auth`), release signing, HTTPS.

### Backend Integration Layer (client side)
The client code for these endpoints exists and is tested against fakes. It has **not** been verified against a live server.
- [x] `POST /api/v1/auth/session`
- [x] `GET /api/v1/config/premises`
- [x] `POST /api/v1/attendance/ping`
- [x] `GET /api/v1/attendance/today`
- [x] `GET /api/v1/attendance/history`
- [x] Structured error parsing (`ERR_UNAUTHORIZED`, `ERR_DEVICE_MISMATCH`, `ERR_BIOMETRIC_REQUIRED`, `ERR_MOCK_LOCATION_DETECTED`, `ERR_OUTSIDE_PREMISES`).

---

## 5. Remaining Work

### Final stage
```
Remaining Tasks
├── 1. Hardware verification on a physical device
│   ├── Permissions flow (including "Allow all the time")
│   ├── Live GPS fix and mock-location rejection
│   └── Live BSSID reading on campus Wi-Fi
├── 2. Firebase and Google Auth setup
│   ├── Add google-services.json to android/app/
│   └── Attach the real Firebase ID token to ApiClient headers
├── 3. Background polling
│   └── WorkManager heartbeat (15-minute minimum interval) with token
├── 4. Live backend handshake
│   └── Point the base URL (--dart-define) at the staging server
└── 5. Campus deployment and router calibration
    └── Verify BSSIDs against the physical access points at Zone01 Kisumu
```