import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/constants/api_endpoints.dart';
import '../models/presence_state.dart';
import 'api_client.dart';
import 'biometric_service.dart';
import 'location_service.dart';
import 'wifi_service.dart';

/// Central Attendance & Heartbeat Orchestrator
/// Enforces business logic:
/// 1st Scan = Time In (first_seen_at)
/// Last Seen = Time Out (last_seen_at)
class AttendanceService extends ChangeNotifier {
  AttendanceService._();
  static final AttendanceService instance = AttendanceService._();

  final ApiClient _apiClient = ApiClient.instance;
  final BiometricService _biometricService = BiometricService.instance;
  final LocationService _locationService = LocationService.instance;
  final WifiService _wifiService = WifiService.instance;

  PresenceState _presenceState = PresenceState.checkedIn;
  bool _isFirstSeenLocked = false;
  String _firstSeenEat = '--:--:--';
  String _lastSeenEat = '--:--:--';
  String _activeDurationFormatted = '00h 00m';
  DateTime? _firstSeenTime;
  bool _isSyncing = false;
  Timer? _heartbeatTimer;

  final List<DetectionLog> _recentDetections = [];

  PresenceState get presenceState => _presenceState;
  bool get isFirstSeenLocked => _isFirstSeenLocked;
  String get firstSeenEat => _firstSeenEat;
  String get lastSeenEat => _lastSeenEat;
  String get activeDurationFormatted => _activeDurationFormatted;
  bool get isSyncing => _isSyncing;
  List<DetectionLog> get recentDetections => List.unmodifiable(_recentDetections);

  bool get isWifiVerified => _wifiService.isCampusWifiMatched();
  bool get isGpsVerified => _locationService.isWithinGeofence();
  bool get isNearCampus => isWifiVerified || isGpsVerified;

  void initialize() {
    _evaluatePresence();
    _loadTodayAttendance();

    // Schedule 5-minute background Wi-Fi heartbeat
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (isWifiVerified) {
        sendHeartbeat(triggerType: AttendanceTriggerType.wifiHeartbeat);
      }
    });
  }

  Future<void> _loadTodayAttendance() async {
    try {
      final data = await _apiClient.getTodayAttendance();
      if (data['checked_in_today'] == true) {
        _isFirstSeenLocked = true;
        _firstSeenEat = data['first_seen_at'] ?? '--:--:--';
        _lastSeenEat = data['last_seen_at'] ?? '--:--:--';
        _activeDurationFormatted = data['active_duration_formatted'] ?? '00h 00m';

        final rawDetections = data['recent_detections'] as List<dynamic>? ?? [];
        _recentDetections.clear();
        for (final item in rawDetections) {
          _recentDetections.add(DetectionLog.fromJson(item as Map<String, dynamic>));
        }
        notifyListeners();
      }
    } catch (_) {
      // Offline or network error
    }
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

  void cycleStateForDemo() {
    if (_presenceState == PresenceState.checkedIn) {
      _presenceState = PresenceState.approaching;
    } else if (_presenceState == PresenceState.approaching) {
      _presenceState = PresenceState.offPremises;
    } else {
      _presenceState = PresenceState.checkedIn;
    }
    notifyListeners();
  }

  /// Format DateTime into readable EAT time string
  String _formatEatTime(DateTime dt) {
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final minStr = dt.minute.toString().padLeft(2, '0');
    final secStr = dt.second.toString().padLeft(2, '0');
    return '${hour.toString().padLeft(2, '0')}:$minStr:$secStr $period';
  }

  /// Sends attendance ping to Go Backend and updates UI state with real-time calculations
  Future<bool> sendHeartbeat({
    required String triggerType,
    bool biometricVerified = false,
  }) async {
    _isSyncing = true;
    notifyListeners();

    final now = DateTime.now();

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
      await _apiClient.sendAttendancePing(request);

      final formattedEat = _formatEatTime(now);
      final shortEat = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

      if (!_isFirstSeenLocked) {
        _firstSeenTime = now;
        _firstSeenEat = formattedEat;
        _isFirstSeenLocked = true;
      }

      _lastSeenEat = formattedEat;
      _firstSeenTime ??= now;

      final diff = now.difference(_firstSeenTime!);
      final hrs = diff.inHours;
      final mins = diff.inMinutes % 60;
      _activeDurationFormatted = '${hrs.toString().padLeft(2, '0')}h ${mins.toString().padLeft(2, '0')}m';

      _recentDetections.insert(
        0,
        DetectionLog(
          id: 'ping_${now.millisecondsSinceEpoch}',
          timeEat: shortEat,
          title: triggerType == AttendanceTriggerType.biometricCheckin
              ? 'First Check-In (Time In)'
              : triggerType == AttendanceTriggerType.manualBiometricSync
                  ? 'Biometric Attendance Sync'
                  : 'Wi-Fi Heartbeat (Auto)',
          subtitle: 'SSID: ${_wifiService.currentSsid} • BSSID: ${_wifiService.currentBssid}',
          triggerType: triggerType,
        ),
      );

      _presenceState = PresenceState.checkedIn;
      _isSyncing = false;
      notifyListeners();
      return true;
    } catch (_) {
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  /// Perform Biometric Check-in or Manual Sync with physical hardware authentication
  Future<bool> authenticateAndSync({required String triggerType}) async {
    final canAuth = await _biometricService.checkBiometricAvailability();
    if (!canAuth) return false;

    final authenticated = await _biometricService.authenticate(
      reason: 'Verify identity to mark presence at Zone01 Campus',
      proximityVerified: isNearCampus,
    );

    if (authenticated) {
      return await sendHeartbeat(
        triggerType: triggerType,
        biometricVerified: true,
      );
    }
    return false;
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
