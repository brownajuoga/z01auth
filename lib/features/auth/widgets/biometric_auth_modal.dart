import 'package:flutter/material.dart';
import '../../../core/theme/z01_theme.dart';
import '../../../services/biometric_service.dart';

/// Bottom sheet that invokes real Android & device biometric (fingerprint/face) verification.
/// Interacts directly with physical hardware sensors via BiometricService and local_auth.
class BiometricAuthModal extends StatefulWidget {
  final String title;
  final String subtitle;
  final String proximityTag;
  final VoidCallback onSuccess;

  const BiometricAuthModal({
    super.key,
    required this.title,
    required this.subtitle,
    required this.proximityTag,
    required this.onSuccess,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String proximityTag,
    required VoidCallback onSuccess,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BiometricAuthModal(
        title: title,
        subtitle: subtitle,
        proximityTag: proximityTag,
        onSuccess: onSuccess,
      ),
    );
  }

  @override
  State<BiometricAuthModal> createState() => _BiometricAuthModalState();
}

class _BiometricAuthModalState extends State<BiometricAuthModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _isSuccess = false;
  bool _isAuthenticating = false;
  String _statusMessage = 'Touch sensor or tap to verify';

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    // Auto-prompt physical sensor prompt after the bottom sheet opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted && !_isSuccess && !_isAuthenticating) {
          _handleScan();
        }
      });
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _handleScan() async {
    if (_isSuccess || _isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
      _statusMessage = 'Sensor active. Verify your fingerprint...';
    });

    final success = await BiometricService.instance.authenticate(
      reason: widget.subtitle,
      proximityVerified: true,
    );

    if (!mounted) return;

    if (success) {
      setState(() {
        _isSuccess = true;
        _isAuthenticating = false;
        _statusMessage = 'Verified. Signing you in...';
      });
      _pulse.stop();

      await Future.delayed(const Duration(milliseconds: 650));
      if (mounted) {
        Navigator.pop(context);
        widget.onSuccess();
      }
    } else {
      setState(() {
        _isAuthenticating = false;
        final err = BiometricService.instance.lastErrorMessage;
        _statusMessage = err.isNotEmpty ? err : 'Authentication failed. Tap to try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Z01Palette.of(context);

    return Container(
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: p.border, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: p.muted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Proximity tag (small pill with a brand dot)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                      color: p.brand,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    widget.proximityTag,
                    style: Z01Theme.monoStyle(
                      context: context,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: p.text,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Text(
              widget.title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 6),
            Text(
              widget.subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: p.muted, fontSize: 13, height: 1.45),
            ),
            const SizedBox(height: 28),

            // Fingerprint button with physical sensor trigger and ripple animation
            GestureDetector(
              onTap: _handleScan,
              child: SizedBox(
                width: 150,
                height: 150,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (!_isSuccess)
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, _) {
                          final t = _pulse.value;
                          return Opacity(
                            opacity: (1 - t) * 0.4,
                            child: Container(
                              width: 90 + t * 60,
                              height: 90 + t * 60,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: p.brand, width: 1.5),
                              ),
                            ),
                          );
                        },
                      ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isSuccess
                            ? p.brand
                            : _isAuthenticating
                                ? p.cardElevated
                                : p.card,
                        border: Border.all(
                          color: _isSuccess ? p.brand : p.border,
                          width: 1.5,
                        ),
                      ),
                      child: _isAuthenticating
                          ? Center(
                              child: SizedBox(
                                width: 34,
                                height: 34,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: p.brand,
                                ),
                              ),
                            )
                          : Icon(
                              _isSuccess
                                  ? Icons.check_rounded
                                  : Icons.fingerprint_rounded,
                              size: 46,
                              color: _isSuccess ? p.onBrand : p.text,
                            ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _isSuccess ? p.text : p.muted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),

            // Cancel button
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: p.muted,
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _isSuccess ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}