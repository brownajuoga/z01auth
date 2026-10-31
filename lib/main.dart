import 'package:flutter/material.dart';
import 'core/theme/theme_controller.dart';
import 'core/theme/z01_theme.dart';
import 'features/auth/auth_screen.dart';
import 'features/dashboard/dashboard_shell.dart';
import 'features/permissions/permissions_screen.dart';
import 'features/profile/profile_screen.dart';
import 'services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BackgroundService.instance.initialize();
  runApp(const Z01AuthApp());
}

class Z01AuthApp extends StatelessWidget {
  const Z01AuthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'Z01 Authentication App',
          debugShowCheckedModeBanner: false,
          theme: Z01Theme.lightTheme,
          darkTheme: Z01Theme.darkTheme,
          themeMode: themeMode,
          initialRoute: '/auth',
          routes: {
            '/auth': (context) => const AuthScreen(),
            '/permissions': (context) => const PermissionsScreen(),
            '/dashboard': (context) => const DashboardShell(),
            '/profile': (context) => const ProfileScreen(),
          },
        );
      },
    );
  }
}
