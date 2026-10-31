import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

/// On-device Biometric Authentication Service utilizing hardware sensors via local_auth
class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();

  bool _isHardwareSupported = true;
  bool _canCheckBiometrics = true;
  String _lastErrorMessage = '';

  String get lastErrorMessage => _lastErrorMessage;
  bool get isHardwareSupported => _isHardwareSupported;
  bool get canCheckBiometrics => _canCheckBiometrics;

  /// Check if device has hardware biometrics and enrolled credentials
  Future<bool> checkBiometricAvailability() async {
    if (kIsWeb) {
      return _isHardwareSupported && _canCheckBiometrics;
    }
    try {
      final isSupported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      _isHardwareSupported = isSupported;
      _canCheckBiometrics = canCheck;
      return isSupported && canCheck;
    } catch (e) {
      _lastErrorMessage = e.toString();
      return _isHardwareSupported && _canCheckBiometrics;
    }
  }

  /// Get list of available biometric sensors enrolled on the device
  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (kIsWeb) return const [];
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return const [];
    }
  }

  /// Authenticate user via physical biometric sensor prompt
  Future<bool> authenticate({
    required String reason,
    bool proximityVerified = true,
  }) async {
    _lastErrorMessage = '';

    // Proximity gating rule: biometrics are strictly blocked if user is outside campus perimeter
    if (!proximityVerified) {
      _lastErrorMessage = 'Proximity verification required. Move near campus to unlock biometrics.';
      return false;
    }

    if (kIsWeb) {
      await Future.delayed(const Duration(milliseconds: 500));
      return true;
    }

    try {
      final didAuthenticate = await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
      return didAuthenticate;
    } on LocalAuthException catch (e) {
      switch (e.code) {
        case LocalAuthExceptionCode.noBiometricHardware:
          _lastErrorMessage = 'Biometric sensor not available on this device.';
          break;
        case LocalAuthExceptionCode.noBiometricsEnrolled:
          _lastErrorMessage = 'No biometrics enrolled. Please set up a fingerprint in Android Settings.';
          break;
        case LocalAuthExceptionCode.temporaryLockout:
        case LocalAuthExceptionCode.biometricLockout:
          _lastErrorMessage = 'Too many attempts. Biometrics temporarily locked.';
          break;
        case LocalAuthExceptionCode.noCredentialsSet:
          _lastErrorMessage = 'No screen lock or passcode set on this device.';
          break;
        case LocalAuthExceptionCode.userCanceled:
          _lastErrorMessage = 'Authentication canceled.';
          break;
        default:
          _lastErrorMessage = e.description ?? 'Biometric authentication failed.';
      }
      return false;
    } catch (e) {
      _lastErrorMessage = e.toString();
      return false;
    }
  }

  /// For testing/debug toggle
  void setHardwareSupported(bool supported) {
    _isHardwareSupported = supported;
  }

  void setCanCheckBiometrics(bool canCheck) {
    _canCheckBiometrics = canCheck;
  }
}
