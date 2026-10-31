# Z01auth — Development Progress & Roadmap

**Current Status:** Step 1–6 Core Frontend & Integration Architecture Complete  
**Date:** October 21, 2026  
**Target Platform:** Flutter (Android 6.0+ / API 23+, Chrome Web)  
**Backend Architecture:** Go REST API + Firebase Auth & Firestore  

---

## 1. Executive Summary

Z01auth replaces the legacy physical door fingerprint scanner with zero-touch proximity-gated mobile attendance. Attendance accounting strictly preserves the door scanner rule:
- **1st Valid Detection of the Day:** Locks `Time In` (`first_seen_at`) for the day.
- **Subsequent Valid Detections (Heartbeats):** Continuously rolls forward `Time Out` (`last_seen_at`).

---

## 2. Completed Milestones (Steps 1 – 6)

| Step | Date | Commit | Status | Summary of Deliverables |
| :--- | :--- | :--- | :--- | :--- |
| **Step 1** | Oct 17, 2026 | `ea2992d` | Completed | Initialized monochrome B&W theme engine, `ThemeController`, data models, and 4-frame navigation shell. |
| **Step 2** | Oct 17, 2026 | `42f13ff` | Completed | Built Frame 1 (`01_Auth`) with proximity-gating banner, interactive biometric bottom sheet modal, and Google sign-in. |
| **Step 3** | Oct 18, 2026 | `af5323e` | Completed | Built Frame 2 (`02_Permissions`) with interactive checklist cards for fine location, background location, Wi-Fi BSSID, and biometrics. Configured for Android 6.0+ (API 23+). |
| **Step 4** | Oct 19, 2026 | `fcdc008` | Completed | Built Frame 3 (`03_Dashboard`) featuring the custom animated `PresenceRadarRing`, verification pills, 2-column Time In / Time Out cards, sync button, and recent detections list. |
| **Step 5** | Oct 20, 2026 | `2e58771` | Completed | Built Frame 4 (`04_History`) with 3-column monthly summary strip (`DAYS PRESENT`, `AVG HOURS`, `VERIFIED`), daily attendance log cards, and `AttendanceDetailSheet`. |
| **Step 6** | Oct 21, 2026 | `9afe7a2` | Completed | Built full service layer (`ApiClient`, `AttendanceService`, `BiometricService`, `LocationService`, `WifiService`) matching the Go Backend API specification. |
| **Step 7** | Oct 27, 2026 | `4bd152d` | Completed | Implemented Analytics View (`AnalyticsScreen`), refined proximity shield hero, updated launcher icons, and finalized brand identity. |
| **Step 8** | Oct 30, 2026 | `HEAD` | Completed | Finalized frontend integration: synchronized Go backend API routes, resolved test suite lifecycle, and validated 0 analyzer issues. |

---

## 3. Detailed Feature Progress Checklist

### Frontend UI & Aesthetics
- [x] Strict high-contrast Monochrome theme: Pure Black (`#000000`) and Pure White (`#FFFFFF`).
- [x] Dynamic runtime theme switching via `ThemeController` (reactive `ValueNotifier`).
- [x] In-app `SettingsDrawer` with Black/White appearance toggles, background polling toggle, and Google sign-out.
- [x] Custom `RadarRingPainter` supporting 3 visual geometry states:
  - Solid outer ring with animated pulse glow (**Checked In**)
  - Dashed arc ring (**Near Premises / Approaching**)
  - Dotted circle ring (**Off Premises / Locked**)
- [x] Proximity gate banner with interactive test toggle (simulates Near Premises `<50m` vs Off Premises `>150m`).
- [x] Biometric authentication bottom-sheet scanner with pulsing ripple animation.
- [x] 2-Column summary cards with immutable Time In (lock icon) and rolling Time Out (sync icon).
- [x] Frame 4 History scrollable list with interactive audit trail modal sheet.

### Platform & Android Configuration
- [x] Target platform configured for **Android 6.0+ (API 23+)** via `minSdk = 23` in `android/app/build.gradle.kts`.
- [x] Declared runtime & hardware permissions in `AndroidManifest.xml`:
  - `android.permission.INTERNET`
  - `android.permission.ACCESS_FINE_LOCATION`
  - `android.permission.ACCESS_COARSE_LOCATION`
  - `android.permission.ACCESS_WIFI_STATE`
  - `android.permission.CHANGE_WIFI_STATE`
  - `android.permission.ACCESS_NETWORK_STATE`
  - `android.permission.USE_FINGERPRINT` (Android 6.0 – 8.1 / API 23+)
  - `android.permission.USE_BIOMETRIC` (Android 9.0+ / API 28+)
  - `android.permission.ACCESS_BACKGROUND_LOCATION`

### Backend API Integration Layer (Go + Firebase)
- [x] `POST /api/v1/auth/session`: User validation & hardware device ID binding.
- [x] `GET /api/v1/config/premises`: Fetches campus geofence ($r = 50\text{ m}$) and allowed BSSID whitelist (`00:1a:2b:3c:4d:5e`, `00:1a:2b:3c:4d:5f`).
- [x] `POST /api/v1/attendance/ping`: Dispatches biometric check-in, Wi-Fi heartbeats, manual sync, and geofence exit events.
- [x] `GET /api/v1/attendance/today`: Real-time dashboard sync.
- [x] `GET /api/v1/attendance/history`: Monthly attendance statistics and daily records.
- [x] Structured error code parsing (`ERR_UNAUTHORIZED`, `ERR_DEVICE_MISMATCH`, `ERR_BIOMETRIC_REQUIRED`, `ERR_MOCK_LOCATION_DETECTED`, `ERR_OUTSIDE_PREMISES`).

---

## 4. Remaining Tasks & Roadmap

```
Remaining Tasks
├── 1. Physical Device Hardware Wiring
│   ├── local_auth plugin integration (real biometric hardware prompt)
│   ├── geolocator plugin integration (live GPS fix + isMockLocation check)
│   └── network_info_plus plugin integration (live BSSID/SSID reading)
├── 2. Firebase & Google Auth Production Setup
│   ├── Add google-services.json to android/app/
│   └── Attach real Firebase ID Token to ApiClient headers
├── 3. Background Polling Service
│   └── Configure workmanager for 5-minute background Wi-Fi heartbeats
├── 4. Live Go Backend Server Handshake
│   └── Update ApiEndpoints.baseUrl to live backend IP / staging server
└── 5. Campus Deployment & Router Calibration
    └── Verify BSSIDs against physical access points at Zone01 Kisumu
```
