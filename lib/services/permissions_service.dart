import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'biometric_service.dart';

/// What the app is actually allowed to do right now.
/// FAIL CLOSED: every field is false until a real check says otherwise.
class PermissionSnapshot {
  const PermissionSnapshot({
    this.preciseLocation = false,
    this.backgroundLocation = false,
    this.wifiAccess = false,
    this.biometrics = false,
    this.locationPermanentlyDenied = false,
  });

  final bool preciseLocation;
  final bool backgroundLocation;
  final bool wifiAccess;
  final bool biometrics;

  /// The OS will no longer show the location prompt; only Settings can change it.
  final bool locationPermanentlyDenied;
}

class PermissionsService {
  PermissionsService({BiometricService? biometrics})
      : _biometrics = biometrics ?? BiometricService.instance;

  static final PermissionsService instance = PermissionsService();

  final BiometricService _biometrics;

  /// Reads the real state without showing any prompt.
  Future<PermissionSnapshot> check() async {
    var permission = LocationPermission.denied;
    var locationSwitchOn = false;
    try {
      permission = await Geolocator.checkPermission();
      locationSwitchOn = await Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('Permission check failed: $e');
    }

    var biometrics = false;
    try {
            biometrics = await _biometrics.hasEnrolledBiometrics();
    } catch (e) {
      debugPrint('Biometric check failed: $e');
    }

    final precise = permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;

    return PermissionSnapshot(
      preciseLocation: precise,
      backgroundLocation: permission == LocationPermission.always,
      // Android only returns the real router address when location is
      // allowed and the phone's location switch is on.
      wifiAccess: precise && locationSwitchOn,
      biometrics: biometrics,
      locationPermanentlyDenied: permission == LocationPermission.deniedForever,
    );
  }

  /// Shows the location prompt if the OS still allows it, then re-checks.
  Future<PermissionSnapshot> requestLocation() async {
    try {
      final current = await Geolocator.checkPermission();
      if (current == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
    } catch (e) {
      debugPrint('Location request failed: $e');
    }
    return check();
  }

  /// Opens this app's page in system Settings.
  Future<bool> openSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (_) {
      return false;
    }
  }
}