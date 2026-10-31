import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import '../core/constants/api_endpoints.dart';
import '../models/presence_state.dart';
import 'api_client.dart';
import 'location_service.dart';
import 'wifi_service.dart';

const String kZ01BackgroundHeartbeatTask = 'z01auth_wifi_heartbeat';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == kZ01BackgroundHeartbeatTask) {
      try {
        final wifiService = WifiService.instance;
        final locationService = LocationService.instance;

        await wifiService.refreshWifiInfo();
        await locationService.refreshLocation();

        if (wifiService.isCampusWifiMatched() || locationService.isWithinGeofence()) {
          final now = DateTime.now();
          final request = AttendancePingRequest(
            triggerType: AttendanceTriggerType.wifiHeartbeat,
            clientTimestamp: now,
            biometricVerified: false,
            wifiConnected: wifiService.isConnected,
            wifiSsid: wifiService.currentSsid,
            wifiBssid: wifiService.currentBssid,
            latitude: locationService.currentLatitude,
            longitude: locationService.currentLongitude,
            accuracyMeters: locationService.accuracyMeters,
            isMockLocation: locationService.isMockLocation,
          );
          await ApiClient.instance.sendAttendancePing(request);
        }
      } catch (_) {
        return Future.value(false);
      }
    }
    return Future.value(true);
  });
}

/// Central Android WorkManager background service orchestrator
class BackgroundService {
  BackgroundService._();
  static final BackgroundService instance = BackgroundService._();

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (kIsWeb || _isInitialized) return;

    try {
      await Workmanager().initialize(
        callbackDispatcher,
      );

      // Register periodic background heartbeat (runs while screen is off / student in pocket)
      await Workmanager().registerPeriodicTask(
        'z01auth_heartbeat_periodic',
        kZ01BackgroundHeartbeatTask,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
      );
      _isInitialized = true;
    } catch (_) {
      // Graceful fallback on unsupported environments
    }
  }
}
