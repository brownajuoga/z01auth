import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:z01auth/features/auth/widgets/proximity_shield_hero.dart';
import 'package:z01auth/features/dashboard/dashboard_shell.dart';
import 'package:z01auth/features/permissions/permissions_screen.dart';
import 'package:z01auth/features/profile/profile_screen.dart';
import 'package:z01auth/main.dart';

void main() {
  testWidgets('Z01AuthApp loads and displays auth screen with Lock & Shield centerpiece', (WidgetTester tester) async {
    await tester.pumpWidget(const Z01AuthApp());
    await tester.pump(const Duration(milliseconds: 300));

    // Verify Brand Title
    expect(find.text('Z01 Authentication App'), findsOneWidget);

    // Verify Proximity Shield Hero is present
    expect(find.byType(ProximityShieldHero), findsOneWidget);

    // Verify Initial In-Range State
    expect(find.text('On premises · 18 m'), findsOneWidget);
    expect(find.text('Wi-Fi verified'), findsOneWidget);
    expect(find.text('Biometrics ready'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Sign in with biometrics'), findsOneWidget);

    // Tap the Proximity Shield Hero to toggle proximity gate simulation
    await tester.tap(find.byType(ProximityShieldHero));
    await tester.pump(const Duration(milliseconds: 400));

    // Verify Gated / Locked State
    expect(find.text('Off premises · >150 m'), findsOneWidget);
    expect(find.text('Wi-Fi not detected'), findsOneWidget);
    expect(find.text('Biometrics locked'), findsOneWidget);
    expect(find.text('Biometrics unlock on campus'), findsOneWidget);

    // Tap again to toggle back
    await tester.tap(find.byType(ProximityShieldHero));
    await tester.pump(const Duration(milliseconds: 400));

    // Verify restored In-Range State
    expect(find.text('On premises · 18 m'), findsOneWidget);
    expect(find.text('Wi-Fi verified'), findsOneWidget);
    expect(find.text('Biometrics ready'), findsOneWidget);

    // Test Theme toggle button
    final themeToggleFinder = find.byTooltip('Toggle theme');
    expect(themeToggleFinder, findsOneWidget);
    await tester.tap(themeToggleFinder);
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('PermissionsScreen renders checklist items', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: PermissionsScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Set up automatic check-in'), findsOneWidget);
    expect(find.text('Precise location'), findsOneWidget);
    expect(find.text('Background location'), findsOneWidget);
    expect(find.text('Wi-Fi access'), findsOneWidget);
    expect(find.text('Biometrics'), findsOneWidget);
  });

  testWidgets('DashboardShell renders tabs and bottom navigation', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DashboardShell(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Live'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Insights'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);

    // Unmount to cleanly cancel tickers and timers
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('DashboardScreen profile avatar navigates to ProfileScreen', (WidgetTester tester) async {
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
