import 'package:shared_preferences/shared_preferences.dart';

class ThemeManager {
  static final ThemeManager _instance = ThemeManager._internal();
  late SharedPreferences _prefs;
  bool _isDarkMode = false;

  factory ThemeManager() {
    return _instance;
  }

  ThemeManager._internal();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _isDarkMode = _prefs.getBool('darkMode') ?? false;
    print('ThemeManager initialized - isDarkMode: $_isDarkMode');
  }

  bool get isDarkMode => _isDarkMode;

  Future<void> setDarkMode(bool isDarkMode) async {
    _isDarkMode = isDarkMode;
    await _prefs.setBool('darkMode', isDarkMode);
    print('ThemeManager - Dark mode set to: $_isDarkMode');
  }
}
