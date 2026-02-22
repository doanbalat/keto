import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'theme/app_theme.dart';
import 'theme/theme_manager.dart';
import 'services/preference_service.dart';
import 'services/localization_service.dart';
import 'home_page.dart';

class KetoApp extends StatefulWidget {
  const KetoApp({super.key});

  @override
  State<KetoApp> createState() => _KetoAppState();
}

class _KetoAppState extends State<KetoApp> {
  bool _isDarkMode = false;
  String _shopName = 'Keto - Sổ Tay Bán Hàng';
  bool _soundEnabled = true;
  String _language = 'vi';
  final PreferenceService _prefs = PreferenceService();

  @override
  void initState() {
    super.initState();
    _isDarkMode = ThemeManager().isDarkMode;
    _shopName = _prefs.shopName;
    _soundEnabled = _prefs.soundEnabled;
    _language = _prefs.language;
    
    if (kDebugMode) print('KetoApp initialized - isDarkMode: $_isDarkMode, language: $_language');
  }

  void _setTheme(bool isDarkMode) async {
    if (kDebugMode) print('Setting theme to: $isDarkMode');
    await ThemeManager().setDarkMode(isDarkMode);
    setState(() {
      _isDarkMode = isDarkMode;
    });
  }

  void _setShopName(String shopName) async {
    await _prefs.setShopName(shopName);
    setState(() {
      _shopName = shopName;
    });
  }

  void _setSoundEnabled(bool soundEnabled) async {
    await _prefs.setSoundEnabled(soundEnabled);
    setState(() {
      _soundEnabled = soundEnabled;
    });
  }

  void _setLanguage(String language) async {
    await _prefs.setLanguage(language);
    LocalizationService.setLanguage(language);
    setState(() {
      _language = language;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Keto',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      home: KetoHomepage(
        isDarkMode: _isDarkMode,
        onThemeChanged: _setTheme,
        shopName: _shopName,
        onShopNameChanged: _setShopName,
        soundEnabled: _soundEnabled,
        onSoundEnabledChanged: _setSoundEnabled,
        language: _language,
        onLanguageChanged: _setLanguage,
      ),
    );
  }
}
