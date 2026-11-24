import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/api_endpoints.dart';
import '../models/presence_state.dart';

/// A failed request: an error from the Go backend (4xx/5xx with a code), or
/// a local failure (no network, timeout, unreadable response).
class ApiException implements Exception {
  final String code;
  final String message;
  final int statusCode; // 0 when the request never reached the server

  const ApiException({
    required this.code,
    required this.message,
    required this.statusCode,
  });

  /// True when the server could not be reached at all.
  bool get isNetworkError => statusCode == 0;

  @override
  String toString() => 'ApiException [$code] ($statusCode): $message';
}

/// Go backend API client.
/// Never invents data: every failure is thrown as an [ApiException] so the
/// UI can show a real offline or error state.
class ApiClient {
  final http.Client _httpClient;
  String? _idToken;
  String _deviceId = 'android_9f8a7b6c5d4e3f2a'; // TODO(F6): per-install ID

  static const Duration _timeout = Duration(seconds: 15);

  ApiClient({http.Client? httpClient}) : _httpClient = httpClient ?? http.Client();

  static final ApiClient instance = ApiClient();

  /// True when the campus config in use is the built-in default because the
  /// server could not be reached. The UI can use this to tell the user.
  bool usingDefaultPremises = false;

  void setAuthToken(String token) => _idToken = token;
  void setDeviceId(String deviceId) => _deviceId = deviceId;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-Device-ID': _deviceId,
        if (_idToken != null) 'Authorization': 'Bearer $_idToken',
      };

  /// POST /api/v1/auth/session - binds the device and validates the user.
  Future<UserProfile> createSession({
    required String deviceModel,
    required String osVersion,
    required String appVersion,
  }) async {
    final response = await _send(
      () => _httpClient.post(
        Uri.parse(ApiEndpoints.authSession),
        headers: _headers,
        body: jsonEncode({
          'device_id': _deviceId,
          'device_model': deviceModel,
          'os_version': osVersion,
          'app_version': appVersion,
        }),
      ),
    );
    return _parse(
      response,
      (data) => UserProfile.fromJson(data['user'] as Map<String, dynamic>),
    );
  }

  /// GET /api/v1/config/premises - campus Wi-Fi and geofence.
  /// Falls back to the built-in defaults when the server is unreachable
  /// (sets [usingDefaultPremises]). Auth errors are still thrown.
  Future<PremisesConfig> getPremisesConfig() async {
    try {
      final response = await _send(
        () => _httpClient.get(
          Uri.parse(ApiEndpoints.configPremises),
          headers: _headers,
        ),
      );
      final config = _parse(response, PremisesConfig.fromJson);
      usingDefaultPremises = false;
      return config;
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) rethrow;
      usingDefaultPremises = true;
      return const PremisesConfig(
        campusName: ApiEndpoints.defaultCampusName,
        timezone: ApiEndpoints.defaultTimezone,
        latitude: ApiEndpoints.defaultCampusLatitude,
        longitude: ApiEndpoints.defaultCampusLongitude,
        radiusMeters: ApiEndpoints.defaultGeofenceRadiusMeters,
        allowedBssids: ApiEndpoints.defaultAllowedBssids,
        heartbeatIntervalSeconds: ApiEndpoints.defaultHeartbeatIntervalSeconds,
      );
    }
  }

  /// POST /api/v1/attendance/ping - biometric check-in or heartbeat.
  Future<AttendancePingResponse> sendAttendancePing(
    AttendancePingRequest request,
  ) async {
    final response = await _send(
      () => _httpClient.post(
        Uri.parse(ApiEndpoints.attendancePing),
        headers: _headers,
        body: jsonEncode(request.toJson()),
      ),
    );
    return _parse(response, AttendancePingResponse.fromJson);
  }

  /// GET /api/v1/attendance/today
  Future<Map<String, dynamic>> getTodayAttendance() async {
    final response = await _send(
      () => _httpClient.get(
        Uri.parse(ApiEndpoints.attendanceToday),
        headers: _headers,
      ),
    );
    return _parse(response, (data) => data);
  }

  /// GET /api/v1/attendance/history?month=YYYY-MM
  Future<Map<String, dynamic>> getAttendanceHistory(String month) async {
    final response = await _send(
      () => _httpClient.get(
        Uri.parse('${ApiEndpoints.attendanceHistory}?month=$month'),
        headers: _headers,
      ),
    );
    return _parse(response, (data) => data);
  }

  // ---------- helpers ----------

  /// Runs a request and turns every failure into an [ApiException].
  Future<http.Response> _send(Future<http.Response> Function() call) async {
    final http.Response response;
    try {
      response = await call().timeout(_timeout);
    } on TimeoutException {
      throw const ApiException(
        code: 'ERR_TIMEOUT',
        message: 'The server took too long to respond.',
        statusCode: 0,
      );
    } catch (_) {
      throw const ApiException(
        code: 'ERR_NETWORK',
        message: 'Could not reach the server.',
        statusCode: 0,
      );
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }
    _throwFromResponse(response);
  }

  /// Reads { "data": {...} } and builds a result. Any shape problem becomes
  /// ERR_BAD_RESPONSE instead of an unhandled cast error.
  T _parse<T>(
    http.Response response,
    T Function(Map<String, dynamic> data) build,
  ) {
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return build(decoded['data'] as Map<String, dynamic>);
    } catch (_) {
      throw ApiException(
        code: 'ERR_BAD_RESPONSE',
        message: 'Unexpected response from the server.',
        statusCode: response.statusCode,
      );
    }
  }

  /// Always throws. Uses the backend's `{ "error": { code, message } }`
  /// when present, otherwise a generic code like `ERR_HTTP_500`.
  Never _throwFromResponse(http.Response response) {
    var code = 'ERR_HTTP_${response.statusCode}';
    var message = 'The server returned an error (${response.statusCode}).';
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> &&
          decoded['error'] is Map<String, dynamic>) {
        final error = decoded['error'] as Map<String, dynamic>;
        code = error['code'] as String? ?? 'ERR_UNKNOWN';
        message = error['message'] as String? ?? message;
      }
    } catch (_) {
      // Body was not JSON: keep the generic code and message.
    }
    throw ApiException(
      code: code,
      message: message,
      statusCode: response.statusCode,
    );
  }
}