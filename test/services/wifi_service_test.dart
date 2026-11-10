import 'package:flutter_test/flutter_test.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:z01auth/services/wifi_service.dart';

/// Minimal stand-in for the plugin so tests run without a phone.
class _FakeNetworkInfo implements NetworkInfo {
  String? bssid;
  String? ssid;
  String? ip;
  bool throws = false;

  @override
  Future<String?> getWifiBSSID() async {
    if (throws) throw Exception('no permission');
    return bssid;
  }

  @override
  Future<String?> getWifiName() async => ssid;

  @override
  Future<String?> getWifiIP() async => ip;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const whitelist = ['aa:bb:cc:dd:ee:ff'];
  late _FakeNetworkInfo fake;
  late WifiService wifi;

  setUp(() {
    fake = _FakeNetworkInfo();
    wifi = WifiService(networkInfo: fake);
  });

  test('starts fail-closed: not connected, no match', () {
    expect(wifi.isConnected, isFalse);
    expect(wifi.isCampusWifiMatched(whitelist: whitelist), isFalse);
  });

  test('matches a campus BSSID, ignoring case and SSID quotes', () async {
    fake.bssid = 'AA:BB:CC:DD:EE:FF';
    fake.ssid = '"Campus"';
    await wifi.refreshWifiInfo();

    expect(wifi.isConnected, isTrue);
    expect(wifi.currentSsid, 'Campus');
    expect(wifi.isCampusWifiMatched(whitelist: whitelist), isTrue);
  });

  test('a different network is connected but not a match', () async {
    fake.bssid = '11:22:33:44:55:66';
    await wifi.refreshWifiInfo();

    expect(wifi.isConnected, isTrue);
    expect(wifi.isCampusWifiMatched(whitelist: whitelist), isFalse);
  });

  test("Android's placeholder BSSID counts as not connected", () async {
    fake.bssid = '02:00:00:00:00:00';
    await wifi.refreshWifiInfo();

    expect(wifi.isConnected, isFalse);
    expect(wifi.isCampusWifiMatched(whitelist: whitelist), isFalse);
  });

  test('losing the reading clears an earlier match', () async {
    fake.bssid = 'aa:bb:cc:dd:ee:ff';
    await wifi.refreshWifiInfo();
    expect(wifi.isCampusWifiMatched(whitelist: whitelist), isTrue);

    fake.bssid = null; // e.g. Wi-Fi switched off
    await wifi.refreshWifiInfo();
    expect(wifi.isConnected, isFalse);
    expect(wifi.isCampusWifiMatched(whitelist: whitelist), isFalse);
  });

  test('a sensor error clears the state instead of keeping old values',
      () async {
    fake.bssid = 'aa:bb:cc:dd:ee:ff';
    await wifi.refreshWifiInfo();

    fake.throws = true;
    await wifi.refreshWifiInfo();
    expect(wifi.isConnected, isFalse);
    expect(wifi.currentBssid, isEmpty);
  });
}