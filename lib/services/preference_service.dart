import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class PreferenceService {
  static final PreferenceService _instance = PreferenceService._internal();
  late SharedPreferences _prefs;

  factory PreferenceService() {
    return _instance;
  }

  PreferenceService._internal();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Shop Name
  String get shopName => _prefs.getString('shopName') ?? 'Keto - Sổ Tay Bán Hàng';
  Future<void> setShopName(String value) async {
    await _prefs.setString('shopName', value);
  }

  // Sound
  bool get soundEnabled => _prefs.getBool('soundEnabled') ?? true;
  Future<void> setSoundEnabled(bool value) async {
    await _prefs.setBool('soundEnabled', value);
  }

  // Language
  String get language => _prefs.getString('language') ?? 'vi';
  Future<void> setLanguage(String value) async {
    await _prefs.setString('language', value);
  }

  // Low Stock Threshold
  int get lowStockThreshold => _prefs.getInt('lowStockThreshold') ?? 5;
  Future<void> setLowStockThreshold(int value) async {
    await _prefs.setInt('lowStockThreshold', value);
  }

  // Notifications
  bool get notificationsEnabled => _prefs.getBool('notificationsEnabled') ?? true;
  Future<void> setNotificationsEnabled(bool value) async {
    await _prefs.setBool('notificationsEnabled', value);
  }
}
