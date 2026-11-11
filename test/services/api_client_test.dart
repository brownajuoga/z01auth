import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:z01auth/services/api_client.dart';

ApiClient _client(MockClientHandler handler) =>
    ApiClient(httpClient: MockClient(handler));

http.Response _json(Object body, int status) =>
    http.Response(jsonEncode(body), status);

void main() {
  test('a 403 device mismatch is thrown, not turned into a login', () async {
    final api = _client((_) async => _json({
          'error': {'code': 'ERR_DEVICE_MISMATCH', 'message': 'Other device'},
        }, 403));

    expect(
      () => api.createSession(deviceModel: 'x', osVersion: 'y', appVersion: 'z'),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'ERR_DEVICE_MISMATCH')
          .having((e) => e.statusCode, 'status', 403)),
    );
  });

  test('a good session response returns the real profile', () async {
    final api = _client((_) async => _json({
          'data': {
            'user': {
              'uid': 'u1',
              'email': 'a@b.c',
              'display_name': 'Ada Lovelace',
              'initials': 'AL',
              'cohort': 'C1',
            },
          },
        }, 200));

    final user = await api.createSession(
        deviceModel: 'x', osVersion: 'y', appVersion: 'z');
    expect(user.displayName, 'Ada Lovelace');
  });

  test('no network is reported as a network error', () async {
    final api = _client((_) async => throw http.ClientException('offline'));

    expect(
      () => api.getTodayAttendance(),
      throwsA(isA<ApiException>()
          .having((e) => e.isNetworkError, 'isNetworkError', true)),
    );
  });

  test("today's attendance throws on a server error instead of faking data",
      () async {
    final api = _client((_) async => http.Response('boom', 500));

    expect(
      () => api.getTodayAttendance(),
      throwsA(isA<ApiException>().having((e) => e.code, 'code', 'ERR_HTTP_500')),
    );
  });

  test('history throws on failure and never invents days', () async {
    final api = _client((_) async => http.Response('boom', 503));

    expect(
      () => api.getAttendanceHistory('2026-11'),
      throwsA(isA<ApiException>()),
    );
  });

  test('a 200 with the wrong shape becomes ERR_BAD_RESPONSE', () async {
    final api = _client((_) async => _json({'unexpected': true}, 200));

    expect(
      () => api.getTodayAttendance(),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'ERR_BAD_RESPONSE')),
    );
  });

  test('requests carry the device id and the bearer token', () async {
    late http.Request seen;
    final api = _client((request) async {
      seen = request;
      return _json({'data': <String, dynamic>{}}, 200);
    });
    api.setAuthToken('abc123');

    await api.getTodayAttendance();

    expect(seen.headers['Authorization'], 'Bearer abc123');
    expect(seen.headers['X-Device-ID'], isNotEmpty);
  });

  test('premises config falls back to defaults and says so', () async {
    final api = _client((_) async => throw http.ClientException('offline'));

    final config = await api.getPremisesConfig();

    expect(api.usingDefaultPremises, isTrue);
    expect(config.allowedBssids, isNotEmpty);
  });

  test('premises config does not hide an auth error', () async {
    final api = _client((_) async => _json({
          'error': {'code': 'ERR_UNAUTHORIZED', 'message': 'No token'},
        }, 401));

    expect(() => api.getPremisesConfig(), throwsA(isA<ApiException>()));
  });
}