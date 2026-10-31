import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/theme/theme_controller.dart';
import '../../core/theme/z01_theme.dart';
import '../../models/presence_state.dart';
import '../../services/attendance_service.dart';
import '../../services/user_service.dart';
import '../auth/widgets/biometric_auth_modal.dart';
import 'widgets/radar_ring.dart';

/// Frame 3: Dashboard (live presence + Time In / Time Out + recent detections)
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AttendanceService _attendanceService = AttendanceService.instance;

  static const _days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  static const _months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  @override
  void initState() {
    super.initState();
    _attendanceService.initialize();
  }

  @override
  void dispose() {
    _attendanceService.stop();
    super.dispose();
  }

  String get _todayLabel {
    final now = DateTime.now();
    return '${_days[now.weekday - 1]} · ${now.day} ${_months[now.month - 1]}';
  }

  void _triggerBiometricSync() {
    if (_attendanceService.presenceState == PresenceState.offPremises) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Biometrics are locked. Move near the campus to unlock.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    BiometricAuthModal.show(
      context: context,
      title: 'Confirm your presence',
      subtitle: 'Scan your fingerprint to sync your attendance.',
      proximityTag: 'ON PREMISES',
      onSuccess: () async {
        final success = await _attendanceService.authenticateAndSync(
          triggerType: AttendanceTriggerType.manualBiometricSync,
        );
        if (mounted && success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              content: Text(
                'Attendance synced',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Z01Palette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: _attendanceService,
      builder: (context, _) {
        final state = _attendanceService.presenceState;
        final isPinging = _attendanceService.isSyncing;
        final lastSeenTime = _attendanceService.lastSeenEat;
        final detections = _attendanceService.recentDetections;

        final isOff = state == PresenceState.offPremises;
        final isIn = state == PresenceState.checkedIn;

        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                children: [
                  // ---------- Header ----------
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _todayLabel,
                            style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 0.9,
                              color: p.muted,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isPinging ? 'Syncing...' : 'Today',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: p.text,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          // Debug-only: cycles the radar through its 3 states
                          if (kDebugMode)
                            IconButton(
                              tooltip: 'Cycle state (debug)',
                              icon: Icon(Icons.tune_rounded, size: 20, color: p.muted),
                              onPressed: _attendanceService.cycleStateForDemo,
                            ),
                          IconButton(
                            tooltip: 'Toggle theme',
                            icon: Icon(
                              isDark
                                  ? Icons.light_mode_outlined
                                  : Icons.dark_mode_outlined,
                              size: 20,
                              color: p.text,
                            ),
                            onPressed: () => ThemeController.instance.toggleTheme(),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            borderRadius: BorderRadius.circular(99),
                            onTap: () => Navigator.pushNamed(context, '/profile'),
                            child: Tooltip(
                              message: 'View Profile',
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: p.brand,
                                child: Text(
                                  UserService.instance.currentUser.initials,
                                  style: TextStyle(
                                    color: p.onBrand,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ---------- Presence ring ----------
                  PresenceRadarRing(
                    state: state,
                    onTap: kDebugMode
                        ? _attendanceService.cycleStateForDemo
                        : () {},
                  ),
                  const SizedBox(height: 16),

                  // ---------- Verification pills ----------
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _statusPill(
                        p,
                        Icons.wifi_rounded,
                        isIn
                            ? 'Wi-Fi verified'
                            : state == PresenceState.approaching
                                ? 'Wi-Fi scanning'
                                : 'Wi-Fi not detected',
                        verified: isIn,
                      ),
                      _statusPill(
                        p,
                        Icons.my_location_rounded,
                        isOff ? 'Outside campus' : 'On campus',
                        verified: !isOff,
                      ),
                      _statusPill(
                        p,
                        isOff ? Icons.lock_outline_rounded : Icons.fingerprint_rounded,
                        isIn
                            ? 'Biometric verified'
                            : state == PresenceState.approaching
                                ? 'Biometric ready'
                                : 'Biometric locked',
                        verified: isIn,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ---------- Time In / Time Out ----------
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: p.brand,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'FIRST SEEN · IN',
                                    style: TextStyle(
                                      fontSize: 10,
                                      letterSpacing: 0.8,
                                      color: p.onBrand,
                                    ),
                                  ),
                                  Icon(Icons.lock_outline_rounded,
                                      size: 14, color: p.onBrand),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _attendanceService.firstSeenEat,
                                style: Z01Theme.monoStyle(
                                  context: context,
                                  fontSize: 18,
                                  color: p.onBrand,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Locked for today',
                                style: TextStyle(fontSize: 11, color: p.onBrand),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: p.card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: p.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'LAST SEEN · OUT',
                                    style: TextStyle(
                                      fontSize: 10,
                                      letterSpacing: 0.8,
                                      color: p.muted,
                                    ),
                                  ),
                                  Icon(Icons.sync_rounded, size: 14, color: p.muted),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                lastSeenTime,
                                style: Z01Theme.monoStyle(
                                  context: context,
                                  fontSize: 18,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Updates with each ping',
                                style: TextStyle(fontSize: 11, color: p.muted),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ---------- Action button ----------
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      disabledBackgroundColor: p.card,
                      disabledForegroundColor: p.muted,
                    ),
                    onPressed: isOff ? null : _triggerBiometricSync,
                    icon: isPinging
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: p.accentFg,
                            ),
                          )
                        : Icon(
                            isOff
                                ? Icons.lock_outline_rounded
                                : Icons.fingerprint_rounded,
                            size: 20,
                          ),
                    label: Text(
                      isIn
                          ? 'Verify & sync attendance'
                          : state == PresenceState.approaching
                              ? 'Scan fingerprint to check in'
                              : 'Move near campus to unlock',
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ---------- Recent detections ----------
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'RECENT DETECTIONS',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.9,
                        color: p.muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (detections.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                      decoration: BoxDecoration(
                        color: p.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: p.border),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.sensors_off_rounded, size: 28, color: p.muted),
                          const SizedBox(height: 10),
                          Text(
                            'No check-ins recorded yet today',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: p.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Scan your fingerprint or verify presence to register your arrival.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11, color: p.muted),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: p.card,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: p.border),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: detections.length,
                        separatorBuilder: (_, _) =>
                            Divider(color: p.border, height: 1),
                        itemBuilder: (context, index) {
                          final log = detections[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: index == 0 ? p.brand : p.muted,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        log.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                          color: p.text,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        log.subtitle,
                                        style: Z01Theme.monoStyle(
                                          context: context,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: p.muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  log.timeEat,
                                  style: Z01Theme.monoStyle(
                                    context: context,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _statusPill(
    Z01Palette p,
    IconData icon,
    String text, {
    required bool verified,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: p.cardElevated,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: verified ? p.brand : p.muted),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: verified ? p.text : p.muted,
            ),
          ),
        ],
      ),
    );
  }
}