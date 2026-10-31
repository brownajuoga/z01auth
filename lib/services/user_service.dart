import 'package:flutter/foundation.dart';
import '../models/presence_state.dart';

/// Central User & Profile Management Service
class UserService extends ChangeNotifier {
  UserService._();
  static final UserService instance = UserService._();

  UserProfile _currentUser = const UserProfile(
    uid: 'z01_usr_0428',
    email: 'aaron.b@zone01kisumu.ke',
    displayName: 'Aaron Brown',
    initials: 'AB',
    cohort: 'Cohort 2026',
  );

  final String _studentId = 'Z01-KSM-0428';
  final String _campus = 'Zone01 Kisumu Campus';
  final String _track = 'Full-Stack Software Engineering';
  final String _deviceModel = 'Android 14 (Pixel 8 Pro)';
  final String _deviceId = 'android_9f8a7b6c5d4e3f2a';

  UserProfile get currentUser => _currentUser;
  String get studentId => _studentId;
  String get campus => _campus;
  String get track => _track;
  String get deviceModel => _deviceModel;
  String get deviceId => _deviceId;

  void updateUserProfile(UserProfile profile) {
    _currentUser = profile;
    notifyListeners();
  }
}
