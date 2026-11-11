import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/theme/z01_theme.dart';
import '../../services/location_service.dart';
import '../../services/wifi_service.dart';
import 'widgets/biometric_auth_modal.dart';
import 'widgets/proximity_shield_hero.dart';

/// Frame 1: Auth (Google sign-in + proximity-gated biometrics)
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final WifiService _wifi = WifiService.instance;
  final LocationService _location = LocationService.instance;

  // Fail closed: not near campus until the sensors say so.
  bool _isNearPremises = false;
  bool _checking = true;
  bool _permissionNeeded = false;
  int? _distanceMeters;

  // Debug builds only: set once the test toggle has been used, so the real
  // sensor result no longer overrides it.
  bool _debugForced = false;

  String? _warningMessage;

  @override
  void initState() {
    super.initState();
    _refreshProximity();
  }

  /// Reads the real Wi-Fi and GPS. Never triggers a permission prompt: the
  /// permissions screen does that after sign-in.
  Future<void> _refreshProximity() async {
    final granted = await _location.hasGrantedPermission();
    if (granted) {
      await Future.wait([
        _wifi.refreshWifiInfo(),
        _location.refreshLocation(),
      ]);
    }
    if (!mounted || _debugForced) return;

    setState(() {
      _permissionNeeded = !granted;
      _isNearPremises =
          granted && (_wifi.isCampusWifiMatched() || _location.isWithinGeofence());
      _distanceMeters = (granted && _location.hasFix)
          ? _location.calculateDistanceToCampus().round()
          : null;
      _checking = false;
    });
  }

  String _formatDistance(int meters) => meters >= 1000
      ? '${(meters / 1000).toStringAsFixed(1)} km'
      : '$meters m';

  String get _statusText {
    if (_debugForced) {
      return _isNearPremises ? 'On premises (test)' : 'Off premises (test)';
    }
    if (_checking) return 'Checking your location...';
    if (_permissionNeeded) return 'Location access needed';
    final d = _distanceMeters;
    if (_isNearPremises) {
      return d != null ? 'On premises · ${_formatDistance(d)}' : 'On campus Wi-Fi';
    }
    return d != null
        ? 'Off premises · ${_formatDistance(d)}'
        : 'Location unavailable';
  }

  void _toggleProximityGate() {
    setState(() {
      _debugForced = true;
      _checking = false;
      _isNearPremises = !_isNearPremises;
      _warningMessage = null;
    });

    final p = Z01Palette.of(context);
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1400),
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.cardElevated,
        content: Row(
          children: [
            Icon(
              _isNearPremises ? Icons.shield_rounded : Icons.lock_outline_rounded,
              color: p.brand,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _isNearPremises
                    ? 'Test mode: on premises'
                    : 'Test mode: off premises',
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

  void _handleBiometricAuth() {
    if (!_isNearPremises) {
      setState(() {
        _warningMessage = _permissionNeeded
            ? 'Location access is needed to unlock biometrics. '
                'You will be asked for it after you sign in with Google.'
            : 'Biometrics are locked. Connect to campus Wi-Fi or enter the 50 m perimeter.';
      });
      return;
    }

    BiometricAuthModal.show(
      context: context,
      title: 'Biometric Sign-In',
      subtitle: 'Touch the fingerprint sensor to verify your identity at Zone01.',
      proximityTag: 'ON PREMISES',
      onSuccess: () {
        Navigator.pushReplacementNamed(context, '/permissions');
      },
    );
  }

  void _handleGoogleSignIn() {
    // Signing in only proves who you are. Attendance is recorded separately
    // and only counts when you are on premises.
    Navigator.pushNamed(context, '/permissions');
  }

  @override
  Widget build(BuildContext context) {
    final p = Z01Palette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // ---------- TOP: wordmark + theme toggle + shield ----------
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Z01 Authentication App',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: p.text,
                                      ),
                                    ),
                                    Text(
                                      'ZONE01 KISUMU',
                                      style: TextStyle(
                                        fontSize: 11,
                                        letterSpacing: 0.9,
                                        color: p.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                iconSize: 20,
                                tooltip: 'Toggle theme',
                                icon: Icon(
                                  isDark
                                      ? Icons.light_mode_outlined
                                      : Icons.dark_mode_outlined,
                                  color: p.text,
                                ),
                                onPressed: () =>
                                    ThemeController.instance.toggleTheme(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // The test toggle only works in debug builds.
                          ProximityShieldHero(
                            isNearPremises: _isNearPremises,
                            onToggleProximity:
                                kDebugMode ? _toggleProximityGate : () {},
                          ),
                        ],
                      ),

                      // ---------- MIDDLE: headline + status ----------
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          children: [
                            Text(
                              'Log in to mark attendance',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(fontSize: 26, height: 1.25),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Campus Wi-Fi and location confirm where you are. '
                              'Your fingerprint confirms it\'s you.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: p.muted,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _statusPill(p),
                          ],
                        ),
                      ),

                      // ---------- BOTTOM: actions ----------
                      Column(
                        children: [
                          if (_warningMessage != null)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: p.card,
                                borderRadius: BorderRadius.circular(14),
                                border:
                                    Border.all(color: p.borderStrong, width: 1),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline_rounded,
                                      size: 16, color: p.text),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _warningMessage!,
                                      style: TextStyle(
                                        color: p.text,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          // Primary: Google
                          FilledButton.icon(
                            onPressed: _handleGoogleSignIn,
                            icon: Text(
                              'G',
                              style: Z01Theme.monoStyle(
                                context: context,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: p.accentFg,
                              ),
                            ),
                            label: const Text('Continue with Google'),
                          ),
                          const SizedBox(height: 12),

                          // Secondary: Biometrics (locked look when off premises)
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor:
                                  _isNearPremises ? p.text : p.muted,
                            ),
                            onPressed: _handleBiometricAuth,
                            icon: Icon(
                              _isNearPremises
                                  ? Icons.fingerprint_rounded
                                  : Icons.lock_outline_rounded,
                              size: 20,
                            ),
                            label: Text(
                              _isNearPremises
                                  ? 'Sign in with biometrics'
                                  : 'Biometrics unlock on campus',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Biometrics never leave your device.',
                            style: TextStyle(color: p.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _statusPill(Z01Palette p) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: Container(
        key: ValueKey(_statusText),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: p.cardElevated,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isNearPremises ? p.brand : p.muted,
              ),
            ),
            const SizedBox(width: 6),
            Text(_statusText, style: TextStyle(fontSize: 12, color: p.text)),
          ],
        ),
      ),
    );
  }
}