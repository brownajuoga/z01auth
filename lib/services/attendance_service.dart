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
  bool _isFirstSeenLocked = true;
  final String _firstSeenEat = '08:42:10 AM';
  String _lastSeenEat = '04:19:02 PM';
  String _activeDurationFormatted = '07h 37m';
  bool _isSyncing = false;
  Timer? _heartbeatTimer;

  final List<DetectionLog> _recentDetections = [
    const DetectionLog(
      id: 'ping_992',
      timeEat: '16:19',
      title: 'Wi-Fi Heartbeat (Auto)',
      subtitle: 'BSSID: 00:1A:2B:3C:4D:5E',
      triggerType: AttendanceTriggerType.wifiHeartbeat,
    ),
    const DetectionLog(
      id: 'ping_901',
      timeEat: '08:42',
      title: 'First Check-In (Time In)',
      subtitle: 'Door Wi-Fi + GPS + Biometrics',
      triggerType: AttendanceTriggerType.biometricCheckin,
    ),
  ];

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
    // Schedule 5-minute background Wi-Fi heartbeat
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (isWifiVerified) {
        sendHeartbeat(triggerType: AttendanceTriggerType.wifiHeartbeat);
      }
    });
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

  /// Sends attendance ping to Go Backend and updates UI state
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
      final response = await _apiClient.sendAttendancePing(request);

      final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
      final period = now.hour >= 12 ? 'PM' : 'AM';
      final minStr = now.minute.toString().padLeft(2, '0');
      final secStr = now.second.toString().padLeft(2, '0');
      final shortEat = '${now.hour.toString().padLeft(2, '0')}:$minStr';
      final formattedEat = '${hour.toString().padLeft(2, '0')}:$minStr:$secStr $period';

      _lastSeenEat = formattedEat;
      _activeDurationFormatted = response.activeDurationFormatted;
      _isFirstSeenLocked = response.firstSeenLocked;

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
          subtitle: 'Go Backend Heartbeat Synced',
          triggerType: triggerType,
        ),
      );

      _isSyncing = false;
      notifyListeners();
      return true;
    } catch (_) {
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  /// Perform Biometric Check-in or Manual Sync
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
