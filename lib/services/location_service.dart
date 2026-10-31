import 'dart:math';
import 'package:geolocator/geolocator.dart';
import '../core/constants/api_endpoints.dart';

/// Campus Location & Geofencing Service utilizing Geolocator for live GPS fix and mock location detection
class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  double _currentLatitude = ApiEndpoints.defaultCampusLatitude;
  double _currentLongitude = ApiEndpoints.defaultCampusLongitude;
  double _accuracyMeters = 8.5;
  bool _isMockLocation = false;
  bool _hasPermission = false;
  String _lastError = '';

  double get currentLatitude => _currentLatitude;
  double get currentLongitude => _currentLongitude;
  double get accuracyMeters => _accuracyMeters;
  bool get isMockLocation => _isMockLocation;
  bool get hasPermission => _hasPermission;
  String get lastError => _lastError;

  /// Request runtime location permissions from the user
  Future<bool> requestPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      _hasPermission = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      return _hasPermission;
    } catch (e) {
      _lastError = e.toString();
      return false;
    }
  }

  /// Refreshes current GPS coordinates from the device hardware sensor
  Future<Position?> refreshLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _lastError = 'Location services are disabled.';
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          _lastError = 'Location permission denied.';
          return null;
        }
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
      return position;
    } catch (e) {
      _lastError = e.toString();
      return null;
    }
  }

  /// Calculate distance in meters to campus using Geolocator or Haversine formula
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
      // Fallback to Haversine
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

  /// Verifies if user is within the 50m campus perimeter
  bool isWithinGeofence({double radiusMeters = ApiEndpoints.defaultGeofenceRadiusMeters}) {
    final distance = calculateDistanceToCampus();
    return distance <= radiusMeters;
  }

  /// Update simulated coordinates for testing
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
  }
}
