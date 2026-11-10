import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../core/constants/api_endpoints.dart';

/// Campus location and geofencing (Geolocator).
/// FAIL CLOSED: with no valid GPS fix, or a mock location, the device is
/// treated as NOT inside the campus geofence.
class LocationService {
  LocationService();

  static final LocationService instance = LocationService();

  double _currentLatitude = 0;
  double _currentLongitude = 0;
  double _accuracyMeters = 0;
  bool _isMockLocation = false;
  bool _hasPermission = false;
  bool _hasFix = false;
  String _lastError = '';

  /// Coordinates are 0 until a real fix exists. Check [hasFix] before use.
  double get currentLatitude => _currentLatitude;
  double get currentLongitude => _currentLongitude;
  double get accuracyMeters => _accuracyMeters;
  bool get isMockLocation => _isMockLocation;
  bool get hasPermission => _hasPermission;

  /// True only after a successful GPS read, and until the next failed one.
  bool get hasFix => _hasFix;
  String get lastError => _lastError;

  /// Requests the runtime location permission.
  Future<bool> requestPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      _hasPermission = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (!_hasPermission) _lastError = 'Location permission denied.';
      return _hasPermission;
    } catch (e) {
      _hasPermission = false;
      _lastError = e.toString();
      return false;
    }
  }

  /// Reads the current GPS position. Any failure clears the previous fix,
  /// so old coordinates can never keep the device "on campus".
  Future<Position?> refreshLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _clearFix('Location services are disabled.');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _hasPermission = false;
        _clearFix('Location permission denied.');
        return null;
      }

      _hasPermission = true;
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 5),
        ),
      );

      _currentLatitude = position.latitude;
      _currentLongitude = position.longitude;
      _accuracyMeters = position.accuracy;
      _isMockLocation = position.isMocked;
      _hasFix = true;
      _lastError = '';
      return position;
    } catch (e) {
      _clearFix(e.toString());
      return null;
    }
  }

  /// Distance in metres from a point (default: the current fix) to campus.
  double calculateDistanceToCampus({
    double? latitude,
    double? longitude,
    double campusLat = ApiEndpoints.defaultCampusLatitude,
    double campusLng = ApiEndpoints.defaultCampusLongitude,
  }) {
    final lat = latitude ?? _currentLatitude;
    final lng = longitude ?? _currentLongitude;

    try {
      return Geolocator.distanceBetween(lat, lng, campusLat, campusLng);
    } catch (_) {
      // Haversine fallback
      final lat1 = lat * pi / 180.0;
      final lon1 = lng * pi / 180.0;
      final lat2 = campusLat * pi / 180.0;
      final lon2 = campusLng * pi / 180.0;
      final dlat = lat2 - lat1;
      final dlon = lon2 - lon1;
      final a = sin(dlat / 2) * sin(dlat / 2) +
          cos(lat1) * cos(lat2) * sin(dlon / 2) * sin(dlon / 2);
      final c = 2 * atan2(sqrt(a), sqrt(1 - a));
      return 6371000.0 * c;
    }
  }

  /// True only with a real, non-mock fix inside the campus radius.
  bool isWithinGeofence({
    double radiusMeters = ApiEndpoints.defaultGeofenceRadiusMeters,
  }) {
    if (!_hasFix || _isMockLocation) return false;
    return calculateDistanceToCampus() <= radiusMeters;
  }

  /// Sets a fake GPS fix. For tests only.
  @visibleForTesting
  void setCoordinates({
    required double latitude,
    required double longitude,
    double accuracy = 8.5,
    bool isMock = false,
  }) {
    _currentLatitude = latitude;
    _currentLongitude = longitude;
    _accuracyMeters = accuracy;
    _isMockLocation = isMock;
    _hasFix = true;
  }

  void _clearFix(String reason) {
    _hasFix = false;
    _currentLatitude = 0;
    _currentLongitude = 0;
    _accuracyMeters = 0;
    _isMockLocation = false;
    _lastError = reason;
  }
}