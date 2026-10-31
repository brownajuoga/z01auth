import 'package:flutter/material.dart';
import '../../core/theme/z01_theme.dart';
import '../../services/biometric_service.dart';
import '../../services/location_service.dart';
import '../../services/user_service.dart';
import '../../services/wifi_service.dart';

/// User Profile Screen displaying verified student identity, hardware security,
/// device binding, and interactive biometric diagnostics.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = UserService.instance;
  final BiometricService _biometricService = BiometricService.instance;
  final WifiService _wifiService = WifiService.instance;
  final LocationService _locationService = LocationService.instance;

  bool _isTestingSensor = false;

  Future<void> _testBiometrics() async {
    if (_isTestingSensor) return;
    setState(() => _isTestingSensor = true);

    final p = Z01Palette.of(context);
    final success = await _biometricService.authenticate(
      reason: 'Diagnosing device biometric hardware for Zone01 campus auth',
      proximityVerified: true,
    );

    if (!mounted) return;
    setState(() => _isTestingSensor = false);

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.cardElevated,
        content: Row(
          children: [
            Icon(
              success ? Icons.verified_user_rounded : Icons.error_outline_rounded,
              color: p.brand,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                success
                    ? 'Biometric hardware verified! Sensor is active & healthy.'
                    : (_biometricService.lastErrorMessage.isNotEmpty
                        ? _biometricService.lastErrorMessage
                        : 'Biometric verification cancelled or failed.'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: p.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSignOut() {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/auth',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Z01Palette.of(context);
    final user = _userService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Profile'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: p.bg,
        foregroundColor: p.text,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              // ---------- Profile Header ----------
              Center(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 46,
                          backgroundColor: p.brand,
                          child: Text(
                            user.initials,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: p.onBrand,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: p.bg,
                            shape: BoxShape.circle,
                          ),
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: p.brand,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      user.displayName,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.email,
                      style: TextStyle(
                        fontSize: 13,
                        color: p.muted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        _chip(p, 'STUDENT', isPrimary: true),
                        _chip(p, user.cohort, isPrimary: false),
                        _chip(p, _userService.studentId, isPrimary: false),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ---------- Academy & Track Card ----------
              _sectionHeader(p, 'ACADEMIC & CAMPUS ENROLLMENT'),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: p.border),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _infoRow(p, 'Campus', _userService.campus, Icons.location_on_outlined),
                    Divider(color: p.border, height: 20),
                    _infoRow(p, 'Track', _userService.track, Icons.code_rounded),
                    Divider(color: p.border, height: 20),
                    _infoRow(p, 'Student ID', _userService.studentId, Icons.badge_outlined),
                    Divider(color: p.border, height: 20),
                    _infoRow(p, 'Verification Status', 'Active & Enrolled', Icons.check_circle_outline_rounded, highlight: true),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ---------- Hardware Security & Sensor Diagnostics ----------
              _sectionHeader(p, 'DEVICE BINDING & SENSORS'),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: p.border),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _infoRow(p, 'Bound Device', _userService.deviceModel, Icons.phone_android_rounded),
                    Divider(color: p.border, height: 20),
                    _infoRow(p, 'Device ID', _userService.deviceId, Icons.fingerprint_rounded, isMono: true),
                    Divider(color: p.border, height: 20),
                    _infoRow(p, 'Campus Wi-Fi', '${_wifiService.currentSsid} (${_wifiService.currentBssid})', Icons.wifi_rounded, isMono: true),
                    Divider(color: p.border, height: 20),
                    _infoRow(p, 'GPS Geofence', 'Within ${_locationService.accuracyMeters.toStringAsFixed(1)} m of Zone01 perimeter', Icons.my_location_rounded),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ---------- Interactive Hardware Sensor Test ----------
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                onPressed: _isTestingSensor ? null : _testBiometrics,
                icon: _isTestingSensor
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: p.accentFg,
                        ),
                      )
                    : const Icon(Icons.fingerprint_rounded, size: 20),
                label: Text(_isTestingSensor
                    ? 'Invoking Biometric Sensor...'
                    : 'Test Device Biometric Sensor'),
              ),
              const SizedBox(height: 12),

              // ---------- Sign Out Button ----------
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: p.muted,
                ),
                onPressed: _handleSignOut,
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text('Sign Out'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(Z01Palette p, String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 0.9,
          fontWeight: FontWeight.w600,
          color: p.muted,
        ),
      ),
    );
  }

  Widget _chip(Z01Palette p, String label, {required bool isPrimary}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPrimary ? p.brand : p.cardElevated,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: Z01Theme.monoStyle(
          context: context,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isPrimary ? p.onBrand : p.text,
        ),
      ),
    );
  }

  Widget _infoRow(
    Z01Palette p,
    String label,
    String value,
    IconData icon, {
    bool isMono = false,
    bool highlight = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: highlight ? p.brand : p.muted),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: p.muted),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: isMono
                    ? Z01Theme.monoStyle(
                        context: context,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: highlight ? p.brand : p.text,
                      )
                    : TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: highlight ? p.brand : p.text,
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
