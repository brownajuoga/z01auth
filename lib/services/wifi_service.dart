import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../core/constants/api_endpoints.dart';

/// Campus Wi-Fi state and BSSID verification (network_info_plus).
/// FAIL CLOSED: until a real, valid reading says otherwise, the device is
/// treated as NOT on campus Wi-Fi.
class WifiService {
  /// Pass a fake [NetworkInfo] in unit tests; the app uses [instance].
  WifiService({NetworkInfo? networkInfo})
      : _networkInfo = networkInfo ?? NetworkInfo();

  static final WifiService instance = WifiService();

  final NetworkInfo _networkInfo;

  bool _isConnected = false;
  String _currentSsid = '';
  String _currentBssid = '';
  String _currentIp = '';

  /// Android returns these when location permission is missing or Wi-Fi is
  /// off. They are not real routers.
  static const Set<String> _placeholderBssids = {
    '02:00:00:00:00:00',
    '00:00:00:00:00:00',
  };

  bool get isConnected => _isConnected;
  String get currentSsid => _currentSsid;
  String get currentBssid => _currentBssid.toLowerCase();
  String get currentIp => _currentIp;

  /// Reads the connected Wi-Fi from the device. Any problem (web, no
  /// permission, no Wi-Fi, placeholder address, plugin error) resets to
  /// "not connected" instead of keeping an old or default value.
  Future<void> refreshWifiInfo() async {
    if (kIsWeb) {
      _clear();
      return;
    }
    try {
      final rawBssid = await _networkInfo.getWifiBSSID();
      final bssid = (rawBssid ?? '').toLowerCase().trim();
      if (bssid.isEmpty || _placeholderBssids.contains(bssid)) {
        _clear();
        return;
      }

      final rawSsid = await _networkInfo.getWifiName();
      final ip = await _networkInfo.getWifiIP();

      _currentBssid = bssid;
      // Android wraps the SSID in quotation marks.
      _currentSsid = (rawSsid ?? '').replaceAll('"', '').trim();
      _currentIp = ip ?? '';
      _isConnected = true;
    } catch (_) {
      _clear();
    }
  }

  /// True only when connected AND the BSSID is on the campus whitelist.
  bool isCampusWifiMatched({List<String>? whitelist}) {
    if (!_isConnected || _currentBssid.isEmpty) return false;
    final list = whitelist ?? ApiEndpoints.defaultAllowedBssids;
    final current = _currentBssid.toLowerCase().trim();
    return list.any((b) => b.toLowerCase().trim() == current);
  }

  /// Overrides the Wi-Fi state. For tests only.
  @visibleForTesting
  void setWifiState({
    required bool connected,
    String? ssid,
    String? bssid,
  }) {
    _isConnected = connected;
    if (ssid != null) _currentSsid = ssid;
    if (bssid != null) _currentBssid = bssid.toLowerCase();
  }

  void _clear() {
    _isConnected = false;
    _currentSsid = '';
    _currentBssid = '';
    _currentIp = '';
  }
}