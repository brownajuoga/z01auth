import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../core/constants/api_endpoints.dart';

/// Campus Wi-Fi State & BSSID Verification Service utilizing network_info_plus
class WifiService {
  WifiService._();
  static final WifiService instance = WifiService._();

  final NetworkInfo _networkInfo = NetworkInfo();

  bool _isConnected = true;
  String _currentSsid = ApiEndpoints.defaultAllowedSsids.first;
  String _currentBssid = ApiEndpoints.defaultAllowedBssids.first;
  String _currentIp = '';

  bool get isConnected => _isConnected;
  String get currentSsid => _currentSsid;
  String get currentBssid => _currentBssid.toLowerCase();
  String get currentIp => _currentIp;

  /// Refreshes live connected Wi-Fi SSID and BSSID from device hardware
  Future<void> refreshWifiInfo() async {
    if (kIsWeb) return;
    try {
      final rawSsid = await _networkInfo.getWifiName();
      final rawBssid = await _networkInfo.getWifiBSSID();
      final ip = await _networkInfo.getWifiIP();

      if (rawBssid != null && rawBssid.isNotEmpty) {
        _currentBssid = rawBssid.toLowerCase().trim();
        _isConnected = true;
      }
      if (rawSsid != null && rawSsid.isNotEmpty) {
        // Strip surrounding quotation marks if provided by platform OS
        _currentSsid = rawSsid.replaceAll('"', '').trim();
      }
      if (ip != null) {
        _currentIp = ip;
      }
    } catch (_) {
      // Keep existing configuration if sensor query fails
    }
  }

  /// Check if the connected Wi-Fi BSSID matches the campus whitelist
  bool isCampusWifiMatched({List<String>? whitelist}) {
    if (!_isConnected) return false;
    final list = whitelist ?? ApiEndpoints.defaultAllowedBssids;
    final normalizedCurrent = _currentBssid.toLowerCase().trim();
    return list.any((bssid) => bssid.toLowerCase().trim() == normalizedCurrent);
  }

  /// Update simulated Wi-Fi connection for testing
  void setWifiState({
    required bool connected,
    String? ssid,
    String? bssid,
  }) {
    _isConnected = connected;
    if (ssid != null) _currentSsid = ssid;
    if (bssid != null) _currentBssid = bssid.toLowerCase();
  }
}
