import 'package:flutter_test/flutter_test.dart';
import 'package:z01auth/core/constants/api_endpoints.dart';
import 'package:z01auth/services/location_service.dart';

void main() {
  const lat = ApiEndpoints.defaultCampusLatitude;
  const lng = ApiEndpoints.defaultCampusLongitude;
  late LocationService location;

  setUp(() => location = LocationService());

  test('starts with no fix and is not inside the geofence', () {
    expect(location.hasFix, isFalse);
    expect(location.isWithinGeofence(radiusMeters: 50), isFalse);
  });

  test('a fix at the campus centre is inside', () {
    location.setCoordinates(latitude: lat, longitude: lng);
    expect(location.isWithinGeofence(radiusMeters: 50), isTrue);
  });

  test('about 30 m away is inside a 50 m radius', () {
    location.setCoordinates(latitude: lat + 0.00027, longitude: lng);
    expect(location.isWithinGeofence(radiusMeters: 50), isTrue);
  });

  test('about 110 m away is outside a 50 m radius', () {
    location.setCoordinates(latitude: lat + 0.001, longitude: lng);
    expect(location.isWithinGeofence(radiusMeters: 50), isFalse);
  });

  test('a mock location at the campus centre does not count', () {
    location.setCoordinates(latitude: lat, longitude: lng, isMock: true);
    expect(location.isMockLocation, isTrue);
    expect(location.isWithinGeofence(radiusMeters: 50), isFalse);
  });

  test('distance is roughly 111 m per 0.001 degrees of latitude', () {
    final d = location.calculateDistanceToCampus(
      latitude: lat + 0.001,
      longitude: lng,
    );
    expect(d, closeTo(111.2, 2.0));
  });
}
