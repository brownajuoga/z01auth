import 'package:flutter/material.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/z01_theme.dart';
import '../../../services/user_service.dart';

/// Settings bottom sheet: theme, background check-ins, sign out.
class SettingsDrawer extends StatefulWidget {
  const SettingsDrawer({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const SettingsDrawer(),
    );
  }

  @override
  State<SettingsDrawer> createState() => _SettingsDrawerState();
}

class _SettingsDrawerState extends State<SettingsDrawer> {
  // Local only for now. Saving this setting comes with the background-service phase.
  bool _backgroundCheckIns = true;

  @override
  Widget build(BuildContext context) {
    final p = Z01Palette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: p.muted.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: p.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      UserService.instance.currentUser.email,
                      style: TextStyle(color: p.muted, fontSize: 12),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 22, color: p.text),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ---------- Profile shortcut ----------
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/profile');
              },
              child: _card(
                p,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: p.brand,
                      child: Text(
                        UserService.instance.currentUser.initials,
                        style: TextStyle(
                          color: p.onBrand,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            UserService.instance.currentUser.displayName,
                            style: TextStyle(
                              color: p.text,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${UserService.instance.studentId} • View Profile & Devices',
                            style: TextStyle(color: p.muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: p.muted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ---------- Appearance ----------
            _card(
              p,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appearance',
                    style: TextStyle(
                      color: p.text,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: p.cardElevated,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Row(
                      children: [
                        _themeOption(
                          p,
                          label: 'Dark',
                          icon: Icons.dark_mode_outlined,
                          selected: isDark,
                          onTap: () => ThemeController.instance.setDark(),
                        ),
                        _themeOption(
                          p,
                          label: 'Light',
                          icon: Icons.light_mode_outlined,
                          selected: !isDark,
                          onTap: () => ThemeController.instance.setLight(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ---------- Background check-ins ----------
            _card(
              p,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Background check-ins',
                          style: TextStyle(
                            color: p.text,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Keep your Time Out up to date while you are on campus.',
                          style: TextStyle(color: p.muted, fontSize: 12, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch(
                    value: _backgroundCheckIns,
                    activeThumbColor: p.onBrand,
                    activeTrackColor: p.brand,
                    inactiveThumbColor: p.muted,
                    inactiveTrackColor: p.cardElevated,
                    trackOutlineColor: WidgetStatePropertyAll(
                      _backgroundCheckIns ? p.brand : p.border,
                    ),
                    onChanged: (val) => setState(() => _backgroundCheckIns = val),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ---------- Biometric rule (information only) ----------
            _card(
              p,
              child: Row(
                children: [
                  Icon(Icons.fingerprint_rounded, size: 22, color: p.brand),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Biometrics on campus only',
                          style: TextStyle(
                            color: p.text,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Fingerprint unlock needs campus Wi-Fi or GPS. '
                          'This rule is always on.',
                          style: TextStyle(color: p.muted, fontSize: 12, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ---------- Sign out ----------
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/auth',
                  (route) => false,
                );
              },
              icon: Icon(Icons.logout_rounded, size: 18, color: p.text),
              label: const Text('Sign out'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _card(Z01Palette p, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
      ),
      child: child,
    );
  }

  Widget _themeOption(
    Z01Palette p, {
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? p.text : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: selected ? p.bg : p.muted),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? p.bg : p.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}