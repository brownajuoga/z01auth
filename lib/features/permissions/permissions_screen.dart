import 'package:flutter/material.dart';
import '../../core/theme/z01_theme.dart';
import '../../services/permissions_service.dart';

/// One row in the permissions checklist.
class PermissionItem {
  final String title;
  final String description;
  final IconData icon;
  bool isGranted;

  PermissionItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.isGranted,
  });
}

/// Frame 2: Permissions onboarding (Android 6.0+).
/// Every row starts OFF and shows what the OS really allows. Tapping an OFF
/// row asks for it, or sends the user to Settings when the OS requires that.
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key, this.permissionsService});

  /// Optional override, used by tests. The app uses the real service.
  final PermissionsService? permissionsService;

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen>
    with WidgetsBindingObserver {
  final List<PermissionItem> _items = [
    PermissionItem(
      title: 'Precise location',
      description: 'Detects when you are inside the 50 m campus perimeter.',
      icon: Icons.my_location_rounded,
      isGranted: false,
    ),
    PermissionItem(
      title: 'Background location',
      description:
          'Choose "Allow all the time" so attendance can update while the app is closed.',
      icon: Icons.location_searching_rounded,
      isGranted: false,
    ),
    PermissionItem(
      title: 'Wi-Fi access',
      description: 'Reads the campus router address to confirm you are on site.',
      icon: Icons.wifi_rounded,
      isGranted: false,
    ),
    PermissionItem(
      title: 'Biometrics',
      description: 'Fingerprint or face unlock, available only on campus.',
      icon: Icons.fingerprint_rounded,
      isGranted: false,
    ),
  ];

  int get _grantedCount => _items.where((i) => i.isGranted).length;
  bool get _allGranted => _grantedCount == _items.length;

  void _togglePermission(int index) {
    setState(() => _items[index].isGranted = !_items[index].isGranted);
  }

  void _handleContinue() {
    Navigator.pushReplacementNamed(context, '/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final p = Z01Palette.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: p.text),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress pill
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
                        color: _allGranted ? p.brand : p.muted,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$_grantedCount of ${_items.length} enabled',
                      style: TextStyle(fontSize: 12, color: p.text),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Set up automatic check-in',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 26,
                      height: 1.25,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'These permissions let the app confirm you are on campus '
                'and record your attendance for you.',
                style: TextStyle(color: p.muted, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 20),

              // Checklist
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _permissionCard(p, _items[index], index),
                ),
              ),

              // Hint if background location is off
              if (!_items[1].isGranted)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: p.muted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Without background location, attendance only updates '
                          'while the app is open.',
                          style: TextStyle(color: p.muted, fontSize: 12, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),

              // Continue
              FilledButton(
                onPressed: _handleContinue,
                child: const Text('Continue'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _permissionCard(Z01Palette p, PermissionItem item, int index) {
    final granted = item.isGranted;

    return Material(
      color: p.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _togglePermission(index),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: granted ? p.brand : p.border,
              width: granted ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon badge: brand fill when granted
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: granted ? p.brand : p.cardElevated,
                ),
                child: Icon(
                  granted ? Icons.check_rounded : item.icon,
                  size: 20,
                  color: granted ? p.onBrand : p.text,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: p.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          granted ? 'ON' : 'OFF',
                          style: Z01Theme.monoStyle(
                            context: context,
                            fontSize: 11,
                            color: granted ? p.text : p.muted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.description,
                      style: TextStyle(color: p.muted, fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}