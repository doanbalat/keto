import 'dart:io';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;

enum AdPlacement {
  bannerStatistics,
  bannerAdPage,
  interstitialStatistics,
  interstitialAdPage,
}

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
  static const String _interstitialAdUnitIdAndroid = 'ca-app-pub-3940256099942544/1033173712'; // Google test interstitial ad for Android
  static const String _interstitialAdUnitIdIOS = 'ca-app-pub-3940256099942544/4411468910'; // Google test interstitial ad for iOS

  // Map to store multiple ad unit IDs for different placements
  // In production, replace test IDs with your real AdMob ad unit IDs
  // Structure: {Platform: {AdPlacement: AdUnitId}}
  static const Map<String, Map<AdPlacement, String>> _adUnitIds = {
    'android': {
      AdPlacement.bannerStatistics: 'ca-app-pub-3940256099942544/6300978111',
      AdPlacement.bannerAdPage: 'ca-app-pub-3940256099942544/6300978111',
      AdPlacement.interstitialStatistics: 'ca-app-pub-3940256099942544/1033173712',
      AdPlacement.interstitialAdPage: 'ca-app-pub-3940256099942544/1033173712',
    },
    'ios': {
      AdPlacement.bannerStatistics: 'ca-app-pub-3940256099942544/2934735716',
      AdPlacement.bannerAdPage: 'ca-app-pub-3940256099942544/2934735716',
      AdPlacement.interstitialStatistics: 'ca-app-pub-3940256099942544/4411468910',
      AdPlacement.interstitialAdPage: 'ca-app-pub-3940256099942544/4411468910',
    },
  };

  static bool _isInitialized = false;

  /// Initialize Google Mobile Ads SDK
  /// Call this in main() before running the app
  static Future<void> initialize() async {
    if (_isInitialized) return;

    // Only initialize on mobile platforms (iOS and Android)
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
      if (kDebugMode) print('Google Mobile Ads not supported on this platform');
      _isInitialized = true;
      return;
    }

    try {
      await MobileAds.instance.initialize();
      _isInitialized = true;
      if (kDebugMode) print('Google Mobile Ads SDK initialized');
    } catch (e) {
      if (kDebugMode) print('Failed to initialize Google Mobile Ads: $e');
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

  /// Get interstitial ad unit ID based on platform
  /// These are Google's official test ad unit IDs - safe for development
  static String getInterstitialAdUnitId() {
    if (Platform.isAndroid) {
      return _interstitialAdUnitIdAndroid;
    } else if (Platform.isIOS) {
      return _interstitialAdUnitIdIOS;
    }

    // Not supported on other platforms
    return '';
  }

  /// Get ad unit ID for a specific placement
  /// Uses platform-specific IDs from the _adUnitIds map
  /// Falls back to default banner/interstitial IDs if placement not found
  static String getAdUnitId(AdPlacement placement) {
    final platform = Platform.isAndroid ? 'android' : Platform.isIOS ? 'ios' : '';
    
    if (platform.isEmpty) {
      return ''; // Not supported on this platform
    }

    // Try to get ad unit ID for the specific placement
    final adUnitId = _adUnitIds[platform]?[placement];
    
    if (adUnitId != null && adUnitId.isNotEmpty) {
      return adUnitId;
    }

    // Fallback to default IDs if placement not found
    if (placement.toString().contains('banner')) {
      return getBannerAdUnitId();
    } else if (placement.toString().contains('interstitial')) {
      return getInterstitialAdUnitId();
    }

    return '';
  }

  /// Check if ads are supported on this platform
  static bool isAdsSupportedOnPlatform() {
    return !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  }
}

