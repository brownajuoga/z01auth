import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:z01auth/features/auth/widgets/proximity_shield_hero.dart';
import 'package:z01auth/features/dashboard/dashboard_shell.dart';
import 'package:z01auth/features/permissions/permissions_screen.dart';
import 'package:z01auth/features/profile/profile_screen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:z01auth/features/auth/auth_screen.dart';
import 'package:z01auth/services/location_service.dart';
import 'package:z01auth/services/wifi_service.dart';

/// Answers instantly with "no Wi-Fi", so the login screen can finish its check.
class FakeWifiService extends WifiService {
  @override
  Future<void> refreshWifiInfo() async {}
}

/// Answers instantly with "no permission, no fix".
class FakeLocationService extends LocationService {
  @override
  Future<bool> hasGrantedPermission() async => false;

  @override
  Future<Position?> refreshLocation() async => null;
}

void main() {
  testWidgets('Login screen starts fail-closed and the debug toggle works', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          wifiService: FakeWifiService(),
          locationService: FakeLocationService(),
        ),
      ),
    );

    // The screen first shows "Checking your location...". Keep pumping until
    // that finishes (or give up after about 5 seconds of fake time).
    for (
      var i = 0;
      i < 50 && find.text('Checking your location...').evaluate().isNotEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Brand and shield
    expect(find.text('Z01 Authentication App'), findsOneWidget);
    expect(find.byType(ProximityShieldHero), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);

    // In a test there are no real sensors, so the screen must fail closed.
    expect(find.text('Location access needed'), findsOneWidget);
    expect(find.text('Wi-Fi not detected'), findsOneWidget);
    expect(find.text('Biometrics locked'), findsOneWidget);
    expect(find.text('Biometrics unlock on campus'), findsOneWidget);

    // Debug toggle: tap the shield to simulate being on campus.
    await tester.tap(find.byType(ProximityShieldHero));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('On premises (test)'), findsOneWidget);
    expect(find.text('Wi-Fi verified'), findsOneWidget);
    expect(find.text('Biometrics ready'), findsOneWidget);
    expect(find.text('Sign in with biometrics'), findsOneWidget);

    // Tap again: back to off premises.
    await tester.tap(find.byType(ProximityShieldHero));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Off premises (test)'), findsOneWidget);
    expect(find.text('Wi-Fi not detected'), findsOneWidget);

    // Theme toggle
    final themeToggleFinder = find.byTooltip('Toggle theme');
    expect(themeToggleFinder, findsOneWidget);
    await tester.tap(themeToggleFinder);
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('PermissionsScreen renders checklist items', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: PermissionsScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Set up automatic check-in'), findsOneWidget);
    expect(find.text('Precise location'), findsOneWidget);
    expect(find.text('Background location'), findsOneWidget);
    expect(find.text('Wi-Fi access'), findsOneWidget);
    expect(find.text('Biometrics'), findsOneWidget);
  });

  testWidgets('DashboardShell renders tabs and bottom navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DashboardShell()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Live'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Insights'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Unmount to cleanly cancel tickers and timers
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('DashboardScreen profile avatar navigates to ProfileScreen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        initialRoute: '/dashboard',
        routes: {
          '/dashboard': (context) => const DashboardShell(),
          '/profile': (context) => const ProfileScreen(),
        },
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final profileFinder = find.byTooltip('View Profile');
    expect(profileFinder, findsOneWidget);
    await tester.tap(profileFinder);
    await tester.pumpAndSettle();

    expect(find.text('Student Profile'), findsOneWidget);
    expect(find.text('Aaron Brown'), findsOneWidget);
    expect(find.text('aaron.b@zone01kisumu.ke'), findsOneWidget);
    expect(find.text('Test Device Biometric Sensor'), findsOneWidget);
  });
}
