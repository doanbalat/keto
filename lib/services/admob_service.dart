import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AdMobService {
  static final AdMobService _instance = AdMobService._internal();

  factory AdMobService() {
    return _instance;
  }

  AdMobService._internal();

  // Google's official test ad unit IDs for development/testing
  // See: https://developers.google.com/admob/android/test-ads
  static const String _bannerAdUnitIdAndroid = 'ca-app-pub-3940256099942544/6300978111'; // Google test banner ad for Android
  static const String _bannerAdUnitIdIOS = 'ca-app-pub-3940256099942544/2934735716'; // Google test banner ad for iOS

  static bool _isInitialized = false;

  /// Initialize Google Mobile Ads SDK
  /// Call this in main() before running the app
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Only initialize on mobile platforms (iOS and Android)
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      print('Google Mobile Ads not supported on this platform');
      _isInitialized = true;
      return;
    }

    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      print('Google Mobile Ads SDK initialized');
    } catch (e) {
      print('Failed to initialize Google Mobile Ads: $e');
      // Don't throw - allow app to continue even if AdMob fails
      _isInitialized = true;
    }
  }

  /// Get banner ad unit ID based on platform
  /// These are Google's official test ad unit IDs - safe for development
  static String getBannerAdUnitId() {
    if (Platform.isAndroid) {
      return _bannerAdUnitIdAndroid;
    } else if (Platform.isIOS) {
      return _bannerAdUnitIdIOS;
    }

    // Not supported on other platforms
    return '';
  }

  /// Check if ads are supported on this platform
  static bool isAdsSupportedOnPlatform() {
    return !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  }
}

