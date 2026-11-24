# Z01auth — Mobile Frontend

> **Zero-Touch Campus Attendance System**  
> Powered by Campus Wi-Fi, Geofencing, and On-Premises Biometrics.

[![Flutter](https://img.shields.io/badge/Flutter-3.47.5-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13.4-0175C2?logo=dart)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-6.0%2B%20(API%2023%2B)-3DDC84?logo=android)](https://developer.android.com)
[![Design](https://img.shields.io/badge/Theme-Light%20%26%20Dark-4A6FC4)](#3-design-system--aesthetics)
[![Backend](https://img.shields.io/badge/Backend-Go%20%2B%20Firebase-00ADD8?logo=go)](https://go.dev)

---

## 1. Project Overview

**Z01auth** replaces the legacy physical door fingerprint sensor at Zone01 Kisumu while preserving its exact attendance accounting rule:

$$\text{1st Valid Detection of the Day} = \textbf{Time In} \quad (\text{locked for the day})$$
$$\text{Last Valid Detection of the Day} = \textbf{Time Out} \quad (\text{continuously updated})$$

Instead of queueing at a wall-mounted sensor, the mobile app leverages three distinct verification signals:
1. **Google Auth (Firebase Auth):** Authenticates the student/staff member and binds their physical Android device. Not yet implemented; it needs Firebase access.
2. **Campus Proximity (Wi-Fi BSSID + GPS Geofence):** Verifies the phone is inside the $50\text{ m}$ campus perimeter or connected to a whitelisted campus Wi-Fi access point `00:1a:2b:3c:4d:5e` `00:1a:2b:3c:4d:5f`(the addresses in the code are placeholders until the real ones are confirmed)
3. **Proximity-Gated Biometrics (`local_auth`):** Unlocks on-device fingerprint/face authentication **only** when the phone detects campus Wi-Fi or GPS proximity.

---

## 2. Core Screens & User Workflow (4 Frames)

### Frame 1: Authentication (`01_Auth`)
- **Proximity Gate Banner:** Displays live proximity status (`NEAR PREMISES • 18m` vs `OFF PREMISES • >150m`). Reads the real Wi-Fi and GPS state and starts off premises (fail-closed). Debug builds also have a test toggle for simulating proximity.
- **Biometric Sign-In:** Gated by proximity. When near campus, clicking opens the native-style biometric bottom sheet. When off-premises, the button displays a locked state (`🔒 Biometrics Locked`).
- **Google Sign-In:** Initiates OAuth sign-in and device binding handshake (`POST /api/v1/auth/session`).  Real Firebase sign-in is still pending.
- **Biometric Scanner Modal:** Animated radar-pulse fingerprint target with haptic feedback simulation.

### Frame 2: Permission Onboarding (`02_Permissions`)
- Tailored for **Android 6.0+ (API 23+)** runtime permissions and Android 10+ background location.
- **Checklist cards (real permission state):** every row starts off and shows what the OS allows. Tapping an off row requests it or opens Settings, and the state refreshes when you come back.
  1. *Precise Location (GPS):* Detects entry into the 50m campus perimeter.
  2. *Background Location:* Enables hands-free check-ins without keeping the app open.
  3. *Wi-Fi State & BSSID:* Reads router MAC address to authenticate campus access points.
  4. *On-Premises Biometrics:* Unlocks hardware fingerprint/face sensors on campus.

### Frame 3: Live Radar Dashboard (`03_Dashboard`)
- **Central Presence Radar Ring:** 176x176 custom-painted indicator with animated radar glow and 3 geometry states:
  - **Checked In (Solid Ring + Pulse Glow):** Connected to campus Wi-Fi & GPS verified. Monospace timer displays active session duration (`07h 37m Active`).
  - **Near Premises / Approaching (Dashed Ring):** Inside geofence perimeter, connecting to Wi-Fi.
  - **Off Premises (Dotted Ring):** Outside perimeter; biometrics locked.
- **Verification Pills:** Instant status chips for Wi-Fi SSID, GPS perimeter, and Biometrics.
- **2-Column Summary Cards:**
  - *FIRST SEEN (IN):* `08:42:10 AM` with security lock icon 🔒 (immutable for today).
  - *LAST SEEN (OUT):* Dynamically rolls forward on every valid Wi-Fi heartbeat ping ↻.
- **Action CTA:** *Biometric Verify & Sync Attendance* (triggers on-demand ping to Go backend).
- **Recent Detections List:** Audit log showing exact timestamps and trigger types.
- **Load-failure notice:** if today's attendance can't be loaded, a notice appears and the last known values stay on screen.
- **In-App Settings Drawer:** Hamburger menu offering instant light/dark theme switching, background polling toggle, and sign-out.

### Frame 4: Monthly Attendance Log (`04_History`)
- **Monthly Summary Strip:** 3-column overview displaying `DAYS PRESENT` (e.g., 18d), `AVG HOURS` (e.g., 8.4h), and `VERIFIED` (100%).
- **Interactive Daily Cards:** Showing date, active badge, and monospaced `IN: 08:42 AM → OUT: 05:12 PM` timestamps.
- **Audit Detail Bottom Sheet:** Tap any daily card to inspect router BSSIDs, verification audit trail, and exact attendance duration.

---

## 3. Design System & Aesthetics

Z01auth uses a high-contrast black and white palette with neutral grays and a single blue brand accent, managed by a reactive `ThemeController` (light and dark modes). The token names below mirror the constants in `lib/core/theme/z01_theme.dart`.

| Token | Dark | Light | Usage |
| :--- | :--- | :--- | :--- |
| **`bg`** | `#000000` | `#FFFFFF` | Scaffold backgrounds |
| **`card`** | `#0E0E0E` | `#F5F5F5` | Standard cards & containers |
| **`cardElevated`** | `#1A1A1A` | `#EBEBEB` | Active states & pill containers |
| **`border`** | `#262626` | `#E0E0E0` | Hairline dividers & borders |
| **`borderStrong`** | `#FFFFFF` | `#000000` | High-contrast component borders |
| **`text`** | `#FFFFFF` | `#000000` | Primary headings & emphasis text |
| **`muted`** | `#9A9A9A` | `#5E5E5E` | Secondary labels & helper captions |
| **`accent`** | `#FFFFFF` | `#000000` | Primary action buttons (text on it: `accentFg`) |
| **`brand`** | `#4A6FC4` | `#4A6FC4` | Brand highlights, e.g. the Time In card (text on it: `onBrand`, `#FFFFFF`) |

### Typography
- **Primary UI:** `Inter` (clean, modern sans-serif).
- **Timestamps, Codes & BSSIDs:** `JetBrains Mono` (high-legibility monospace).

---

## 4. Codebase Architecture

```
lib/
├── core/
│   ├── constants/
│   │   └── api_endpoints.dart         # Go backend routes, campus coordinates & BSSID whitelists
│   └── theme/
│       ├── theme_controller.dart      # Reactive ValueNotifier for instant light/dark switching
│       └── z01_theme.dart             # Light and dark ThemeData, color tokens, and mono helpers
├── models/
│   └── presence_state.dart            # DTOs & models matching Go Backend JSON contracts
├── features/
│   ├── auth/                          # Frame 1: Auth screen & biometric scanner modal
│   │   ├── auth_screen.dart
│   │   └── widgets/
│   │       ├── biometric_auth_modal.dart
│   │       └── proximity_shield_hero.dart  # Shield graphic showing proximity state
│   ├── permissions/                   # Frame 2: Android 6.0+ permission onboarding checklist
│   │   └── permissions_screen.dart
│   ├── dashboard/                     # Frame 3: Live Radar, PresenceRing, and Settings Drawer
│   │   ├── dashboard_screen.dart
│   │   ├── dashboard_shell.dart
│   │   └── widgets/
│   │       ├── radar_ring.dart        # CustomPainter for solid, dashed, & dotted rings
│   │       └── settings_drawer.dart   # In-app settings and theme mode switcher
│   ├── history/                       # Frame 4: Monthly attendance log & summary
│   │   ├── history_screen.dart
│   │   └── widgets/
│   │       └── attendance_detail_sheet.dart
│   ├── analytics/                     # Insights tab (last 7 days)
│   │   └── analytics_screen.dart
│   └── profile/                       # Student profile
│       └── profile_screen.dart
├── services/                          # Integrated service layer for hardware & Go backend API
│   ├── api_client.dart                # REST client implementing Go backend contracts
│   ├── attendance_service.dart        # Central attendance & heartbeat orchestrator
│   ├── background_service.dart        # Background heartbeat (WorkManager)
│   ├── biometric_service.dart         # Local biometric authentication wrapper
│   ├── location_service.dart          # Haversine distance & geofence perimeter calculations
│   ├── permissions_service.dart       # Real permission state and requests; fails closed
│   ├── user_service.dart              # Current user profile (hardcoded placeholder until Firebase)
│   └── wifi_service.dart              # Wi-Fi SSID reading & BSSID whitelist matching
└── main.dart                          # App entry point & root route configuration
```

---

## 5. Go Backend API Integration

The app connects to the Go REST API (`/api/v1/*`) using Bearer tokens and device headers:

```http
Authorization: Bearer <FIREBASE_ID_TOKEN>
Content-Type: application/json
X-Device-ID: <ANDROID_HARDWARE_ID>
```

### Endpoints Implemented (client side)

The client code exists and is tested against fakes. It has not been verified against a live server, and the Firebase token and device ID are still placeholders.

| Endpoint | Method | Purpose |
| :--- | :--- | :--- |
| `/api/v1/auth/session` | `POST` | Binds Firebase user to device ID; prevents buddy-punching |
| `/api/v1/config/premises` | `GET` | Fetches campus geofence ($r = 50\text{ m}$) & router BSSIDs |
| `/api/v1/attendance/ping` | `POST` | Upserts attendance: 1st ping locks `Time In`, heartbeats roll `Time Out` |
| `/api/v1/attendance/today` | `GET` | Populates Live Radar status, locked Time In, and recent pings |
| `/api/v1/attendance/history` | `GET` | Populates monthly attendance stats and daily breakdown |

### Error Codes Handled
- `ERR_UNAUTHORIZED` (401): Missing or expired token.
- `ERR_DEVICE_MISMATCH` (403): User account bound to another phone.
- `ERR_BIOMETRIC_REQUIRED` (403): 1st check-in of the day sent without biometrics.
- `ERR_MOCK_LOCATION_DETECTED` (403): Fake GPS app detected.
- `ERR_OUTSIDE_PREMISES` (422): User is not on campus Wi-Fi or inside perimeter.

---

## 6. Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.47.5+)
- Android SDK 23+ (Android 6.0 Marshmallow minimum)

### Running Locally
```bash
# Clone the repository
git clone https://github.com/brownajuoga/z01auth.git
cd z01auth

# Install dependencies
flutter pub get

# Run static analysis
flutter analyze

# Run unit & widget tests
flutter test

# Run on Chrome
flutter run -d chrome

# Run on connected Android device / emulator
flutter run
```

---

## 7. Development Roadmap

For step-by-step progress tracking, commit history, and upcoming milestones, refer to [`PROGRESS.md`](./PROGRESS.md).
