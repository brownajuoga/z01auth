import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/constants/api_endpoints.dart';
import '../models/presence_state.dart';
import 'api_client.dart';
import 'biometric_service.dart';
import 'location_service.dart';
import 'wifi_service.dart';

/// Central attendance and heartbeat orchestrator.
/// Business rule: the first accepted ping of the day is Time In, and the
/// latest accepted ping is Time Out. Both times come from the SERVER's
/// response, so a failed request never changes them.
class AttendanceService extends ChangeNotifier {
  /// Dependencies can be passed in (unit tests); the app uses [instance].
  AttendanceService({
    ApiClient? apiClient,
    BiometricService? biometricService,
    LocationService? locationService,
    WifiService? wifiService,
    DateTime Function()? clock,
  })  : _apiClient = apiClient ?? ApiClient.instance,
        _biometricService = biometricService ?? BiometricService.instance,
        _locationService = locationService ?? LocationService.instance,
        _wifiService = wifiService ?? WifiService.instance,
        _now = clock ?? DateTime.now;

  static final AttendanceService instance = AttendanceService();

  final ApiClient _apiClient;
  final BiometricService _biometricService;
  final LocationService _locationService;
  final WifiService _wifiService;
  final DateTime Function() _now;

  // Fail closed: not on campus until the sensors say so.
  PresenceState _presenceState = PresenceState.offPremises;
  bool _isFirstSeenLocked = false;
  String _firstSeenEat = '--:--:--';
  String _lastSeenEat = '--:--:--';
  String _activeDurationFormatted = '00h 00m';
  bool _isSyncing = false;
  bool _todayLoadFailed = false;
  String? _lastErrorMessage;
  Timer? _heartbeatTimer;

  final List<DetectionLog> _recentDetections = [];

  PresenceState get presenceState => _presenceState;
  bool get isFirstSeenLocked => _isFirstSeenLocked;
  String get firstSeenEat => _firstSeenEat;
  String get lastSeenEat => _lastSeenEat;
  String get activeDurationFormatted => _activeDurationFormatted;
  bool get isSyncing => _isSyncing;

  /// True when today's attendance could not be loaded from the server, so
  /// the screen can say so instead of looking like "not checked in".
  bool get todayLoadFailed => _todayLoadFailed;

  /// Plain-language reason the last check-in or sync failed, or null.
  String? get lastErrorMessage => _lastErrorMessage;

  List<DetectionLog> get recentDetections =>
      List.unmodifiable(_recentDetections);

  bool get isWifiVerified => _wifiService.isCampusWifiMatched();
  bool get isGpsVerified => _locationService.isWithinGeofence();
  bool get isNearCampus => isWifiVerified || isGpsVerified;

  void initialize() {
    _evaluatePresence();
    unawaited(_start());

    // Foreground heartbeat. Android background work is WorkManager's job
    // (minimum interval 15 minutes).
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      await _refreshSensors(); // never trust a stale reading
      if (isWifiVerified) {
        await sendHeartbeat(triggerType: AttendanceTriggerType.wifiHeartbeat);
      }
    });
  }

  Future<void> _start() async {
    await _refreshSensors();
    await loadTodayAttendance();
  }

  Future<void> _refreshSensors() async {
    await Future.wait([
      _wifiService.refreshWifiInfo(),
      _locationService.refreshLocation(),
    ]);
    _evaluatePresence();
  }

  /// Loads today's attendance from the server. A failure sets
  /// [todayLoadFailed] and leaves the previous values alone.
  Future<void> loadTodayAttendance() async {
    try {
      final data = await _apiClient.getTodayAttendance();
      _todayLoadFailed = false;

      if (data['checked_in_today'] == true) {
        _isFirstSeenLocked = true;
        final first = DateTime.tryParse('${data['first_seen_at'] ?? ''}');
        final last = DateTime.tryParse('${data['last_seen_at'] ?? ''}');
        if (first != null) _firstSeenEat = _clock12(first);
        if (last != null) _lastSeenEat = _clock12(last);
        _activeDurationFormatted =
            data['active_duration_formatted'] as String? ?? '00h 00m';

        final raw = data['recent_detections'] as List<dynamic>? ?? [];
        _recentDetections
          ..clear()
          ..addAll(
            raw
                .whereType<Map<String, dynamic>>()
                .map(DetectionLog.fromJson),
          );
      }
    } catch (_) {
      _todayLoadFailed = true;
    }
    notifyListeners();
  }

  void _evaluatePresence() {
    if (isWifiVerified && isGpsVerified) {
      _presenceState = PresenceState.checkedIn;
    } else if (isGpsVerified || isWifiVerified) {
      _presenceState = PresenceState.approaching;
    } else {
      _presenceState = PresenceState.offPremises;
    }
    notifyListeners();
  }

  /// Debug builds only: cycles the radar through its three states.
  void cycleStateForDemo() {
    if (!kDebugMode) return;
    if (_presenceState == PresenceState.checkedIn) {
      _presenceState = PresenceState.approaching;
    } else if (_presenceState == PresenceState.approaching) {
      _presenceState = PresenceState.offPremises;
    } else {
      _presenceState = PresenceState.checkedIn;
    }
    notifyListeners();
  }

  /// Sends an attendance ping. Returns true ONLY when the server accepted it.
  /// On any failure nothing is recorded and [lastErrorMessage] is set.
  Future<bool> sendHeartbeat({
    required String triggerType,
    bool biometricVerified = false,
  }) async {
    if (_isSyncing) return false; // never send two pings at once
    _lastErrorMessage = null;

    // The server is the real authority. This only avoids pointless requests.
    if (!isNearCampus) {
      _lastErrorMessage = 'You are outside the campus area.';
      notifyListeners();
      return false;
    }

    _isSyncing = true;
    notifyListeners();

    final now = _now();
    final request = AttendancePingRequest(
      triggerType: triggerType,
      clientTimestamp: now,
      biometricVerified: biometricVerified,
      wifiConnected: _wifiService.isConnected,
      wifiSsid: _wifiService.currentSsid,
      wifiBssid: _wifiService.currentBssid,
      latitude: _locationService.currentLatitude,
      longitude: _locationService.currentLongitude,
      accuracyMeters: _locationService.accuracyMeters,
      isMockLocation: _locationService.isMockLocation,
    );

    try {
      final response = await _apiClient.sendAttendancePing(request);

      // Times shown are the server's, converted to Nairobi time.
      final first = DateTime.tryParse(response.firstSeenAt);
      final last = DateTime.tryParse(response.lastSeenAt) ?? now;
      if (first != null) _firstSeenEat = _clock12(first);
      _lastSeenEat = _clock12(last);
      _activeDurationFormatted = response.activeDurationFormatted;
      _isFirstSeenLocked = response.firstSeenLocked;
      _presenceState = response.presenceState;

      final bssid = _wifiService.currentBssid;
      _recentDetections.insert(
        0,
        DetectionLog(
          id: 'ping_${now.millisecondsSinceEpoch}',
          timeEat: _clock24(last),
          title: triggerType == AttendanceTriggerType.biometricCheckin
              ? 'First Check-In (Time In)'
              : triggerType == AttendanceTriggerType.manualBiometricSync
                  ? 'Biometric Attendance Sync'
                  : 'Wi-Fi Heartbeat (Auto)',
          subtitle: bssid.isNotEmpty ? 'BSSID: $bssid' : 'GPS location',
          triggerType: triggerType,
        ),
      );

      _isSyncing = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _lastErrorMessage = _friendlyMessage(e);
    } catch (_) {
      _lastErrorMessage = 'Something went wrong. Please try again.';
    }

    _isSyncing = false;
    notifyListeners();
    return false;
  }

  /// Biometric check-in or manual sync.
  Future<bool> authenticateAndSync({required String triggerType}) async {
    _lastErrorMessage = null;
    await _refreshSensors();

    final canAuth = await _biometricService.checkBiometricAvailability();
    if (!canAuth) {
      _lastErrorMessage = 'Biometrics are not available on this device.';
      notifyListeners();
      return false;
    }

    final authenticated = await _biometricService.authenticate(
      reason: 'Verify identity to mark presence at Zone01 Campus',
      proximityVerified: isNearCampus,
    );
    if (!authenticated) {
      _lastErrorMessage = 'Fingerprint was not verified.';
      notifyListeners();
      return false;
    }

    return sendHeartbeat(triggerType: triggerType, biometricVerified: true);
  }

  // ---------- helpers ----------

  String _friendlyMessage(ApiException e) {
    if (e.isNetworkError) {
      return "Can't reach the server. Check your connection and try again.";
    }
    switch (e.code) {
      case 'ERR_OUTSIDE_PREMISES':
        return 'You are outside the campus area.';
      case 'ERR_DEVICE_MISMATCH':
        return 'This account is linked to a different device.';
      case 'ERR_BIOMETRIC_REQUIRED':
        return 'A fingerprint check is required first.';
      case 'ERR_MOCK_LOCATION_DETECTED':
        return 'Mock location is on. Turn it off and try again.';
      default:
        return e.message;
    }
  }

  // Nairobi (EAT) is UTC+3 all year, with no daylight saving.
  DateTime _toEat(DateTime t) => t.toUtc().add(const Duration(hours: 3));

  String _two(int n) => n.toString().padLeft(2, '0');

  /// 08:42:10 AM
  String _clock12(DateTime t) {
    final e = _toEat(t);
    final h = e.hour % 12 == 0 ? 12 : e.hour % 12;
    final period = e.hour >= 12 ? 'PM' : 'AM';
    return '${_two(h)}:${_two(e.minute)}:${_two(e.second)} $period';
  }

  /// 16:19
  String _clock24(DateTime t) {
    final e = _toEat(t);
    return '${_two(e.hour)}:${_two(e.minute)}';
  }

  void stop() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}