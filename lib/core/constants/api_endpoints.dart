/// Go Backend API Contracts and Campus Network Constants
/// Matches Z01auth — Backend API & Integration Specification (Go + Firebase)
class ApiEndpoints {
  // Go Backend Base URL format: https://<api-domain>/api/v1 (or local Android emulator 10.0.2.2:8080/api/v1)
  static const String baseUrl = 'http://10.0.2.2:8080/api/v1';

  // 1. Auth & Session Binding
  static const String authSession = '$baseUrl/auth/session';
  static const String authGoogle = '$baseUrl/auth/google';
  static const String authBiometricChallenge = '$baseUrl/auth/biometric/challenge';
  static const String authBiometricLogin = '$baseUrl/auth/biometric/login';
  static const String authRefresh = '$baseUrl/auth/refresh';
  static const String authLogout = '$baseUrl/auth/logout';

  // 2. Premises & Network Configuration
  static const String config = '$baseUrl/config';
  static const String configPremises = '$baseUrl/config/premises';
  static const String proximityCheck = '$baseUrl/proximity/check';

  // 3. User & Settings
  static const String me = '$baseUrl/me';
  static const String meSettings = '$baseUrl/me/settings';
  static const String meBiometricKey = '$baseUrl/me/device/biometric-key';
  static const String meDevices = '$baseUrl/me/devices';

  // 4. Attendance Heartbeats & Pings
  static const String attendancePing = '$baseUrl/attendance/ping';
  static const String attendanceHeartbeat = '$baseUrl/attendance/heartbeat';
  static const String attendanceBiometricChallenge = '$baseUrl/attendance/biometric/challenge';
  static const String attendanceToday = '$baseUrl/attendance/today';
  static const String attendanceHistory = '$baseUrl/attendance/history';
  static const String attendanceMonths = '$baseUrl/attendance/months';

  // Fallback defaults matching Backend Spec
  static const String defaultCampusName = 'Zone01 Campus';
  static const String defaultTimezone = 'Africa/Nairobi';
  static const double defaultCampusLatitude = -0.091702;
  static const double defaultCampusLongitude = 34.767956;
  static const double defaultGeofenceRadiusMeters = 50.0;
  static const int defaultHeartbeatIntervalSeconds = 300;

  static const List<String> defaultAllowedSsids = ['Z01_Campus_5G'];
  static const List<String> defaultAllowedBssids = [
    '00:1a:2b:3c:4d:5e',
    '00:1a:2b:3c:4d:5f',
  ];
}

/// Standardized Trigger Types for POST /api/v1/attendance/ping
class AttendanceTriggerType {
  static const String biometricCheckin = 'BIOMETRIC_CHECKIN';
  static const String wifiHeartbeat = 'WIFI_HEARTBEAT';
  static const String manualBiometricSync = 'MANUAL_BIOMETRIC_SYNC';
  static const String geofenceExit = 'GEOFENCE_EXIT';
}

/// Standardized Backend Error Codes
class ApiErrorCodes {
  static const String errUnauthorized = 'ERR_UNAUTHORIZED';
  static const String errUnauthorizedDomain = 'ERR_UNAUTHORIZED_DOMAIN';
  static const String errDeviceMismatch = 'ERR_DEVICE_MISMATCH';
  static const String errBiometricRequired = 'ERR_BIOMETRIC_REQUIRED';
  static const String errMockLocationDetected = 'ERR_MOCK_LOCATION_DETECTED';
  static const String errOutsidePremises = 'ERR_OUTSIDE_PREMISES';
}
