import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:z01auth/core/constants/api_endpoints.dart';
import 'package:z01auth/models/presence_state.dart';
import 'package:z01auth/services/api_client.dart';
import 'package:z01auth/services/attendance_service.dart';
import 'package:z01auth/services/location_service.dart';
import 'package:z01auth/services/wifi_service.dart';

http.Response _pingOk({required String first, required String last}) {
  return http.Response(
    jsonEncode({
      'data': {
        'date': '2026-11-10',
        'presence_state': 'CHECKED_IN',
        'first_seen_at': first,
        'last_seen_at': last,
        'first_seen_locked': true,
        'active_duration_seconds': 27412,
        'active_duration_formatted': '07h 37m',
        'verification': {
          'wifi_verified': true,
          'gps_verified': true,
          'biometric_verified': false,
        },
      },
    }),
    200,
  );
}

AttendanceService _build(http.Client client, {bool onCampus = true}) {
  final wifi = WifiService();
  final location = LocationService();
  if (onCampus) {
    wifi.setWifiState(
      connected: true,
      ssid: 'campus',
      bssid: ApiEndpoints.defaultAllowedBssids.first,
    );
    location.setCoordinates(
      latitude: ApiEndpoints.defaultCampusLatitude,
      longitude: ApiEndpoints.defaultCampusLongitude,
    );
  }
  return AttendanceService(
    apiClient: ApiClient(httpClient: client),
    wifiService: wifi,
    locationService: location,
    clock: () => DateTime.utc(2026, 11, 10, 10),
  );
}

void main() {
  const trigger = AttendanceTriggerType.wifiHeartbeat;

  test('starts fail-closed with empty times', () {
    final service = _build(MockClient((_) async => http.Response('', 500)),
        onCampus: false);
    expect(service.presenceState, PresenceState.offPremises);
    expect(service.firstSeenEat, '--:--:--');
    expect(service.recentDetections, isEmpty);
  });

  test('a rejected ping records nothing', () async {
    final service = _build(MockClient((_) async => http.Response(
          jsonEncode({
            'error': {'code': 'ERR_OUTSIDE_PREMISES', 'message': 'Outside'},
          }),
          403,
        )));

    final ok = await service.sendHeartbeat(triggerType: trigger);

    expect(ok, isFalse);
    expect(service.firstSeenEat, '--:--:--');
    expect(service.lastSeenEat, '--:--:--');
    expect(service.isFirstSeenLocked, isFalse);
    expect(service.recentDetections, isEmpty);
    expect(service.lastErrorMessage, contains('outside'));
  });

  test('a network failure records nothing and says so', () async {
    final service = _build(
        MockClient((_) async => throw http.ClientException('offline')));

    final ok = await service.sendHeartbeat(triggerType: trigger);

    expect(ok, isFalse);
    expect(service.firstSeenEat, '--:--:--');
    expect(service.recentDetections, isEmpty);
    expect(service.lastErrorMessage, contains('reach'));
  });

  test('an accepted ping shows the SERVER times in Nairobi time', () async {
    final service = _build(MockClient((_) async => _pingOk(
          first: '2026-11-10T05:42:10Z',
          last: '2026-11-10T13:19:02Z',
        )));

    final ok = await service.sendHeartbeat(triggerType: trigger);

    expect(ok, isTrue);
    expect(service.firstSeenEat, '08:42:10 AM');
    expect(service.lastSeenEat, '04:19:02 PM');
    expect(service.activeDurationFormatted, '07h 37m');
    expect(service.isFirstSeenLocked, isTrue);
    expect(service.recentDetections.first.timeEat, '16:19');
  });

  test('a later ping moves Time Out but never Time In', () async {
    var call = 0;
    final service = _build(MockClient((_) async {
      call++;
      return _pingOk(
        first: '2026-11-10T05:42:10Z',
        last: call == 1 ? '2026-11-10T09:00:00Z' : '2026-11-10T13:19:02Z',
      );
    }));

    await service.sendHeartbeat(triggerType: trigger);
    expect(service.lastSeenEat, '12:00:00 PM');

    await service.sendHeartbeat(triggerType: trigger);
    expect(service.firstSeenEat, '08:42:10 AM');
    expect(service.lastSeenEat, '04:19:02 PM');
  });

  test('no request is sent when the device is not on campus', () async {
    var requests = 0;
    final service = _build(
      MockClient((_) async {
        requests++;
        return http.Response('', 500);
      }),
      onCampus: false,
    );

    final ok = await service.sendHeartbeat(triggerType: trigger);

    expect(ok, isFalse);
    expect(requests, 0);
    expect(service.lastErrorMessage, contains('outside'));
  });
}