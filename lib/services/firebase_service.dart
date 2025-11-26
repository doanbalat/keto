import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';

/// Service for Firebase Crashlytics and Analytics integration
/// 
/// Provides crash reporting, error logging, and user analytics
/// Only works on mobile platforms (iOS and Android)
class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  
  factory FirebaseService() {
    return _instance;
  }
  
  FirebaseService._internal();

  static FirebaseCrashlytics? _crashlytics;
  static FirebaseAnalytics? _analytics;
  static bool _isInitialized = false;

  /// Initialize Firebase services
  /// Call this in main() before runApp()
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize Crashlytics
      _crashlytics = FirebaseCrashlytics.instance;
      
      // Initialize Analytics
      _analytics = FirebaseAnalytics.instance;

      // Pass all uncaught errors to Crashlytics
      FlutterError.onError = (errorDetails) {
        if (kDebugMode) {
          print('Flutter Error: ${errorDetails.exception}');
        }
        _crashlytics?.recordFlutterFatalError(errorDetails);
      };

      // Pass all uncaught asynchronous errors to Crashlytics
      PlatformDispatcher.instance.onError = (error, stack) {
        if (kDebugMode) {
          print('Async Error: $error');
        }
        _crashlytics?.recordError(error, stack, fatal: true);
        return true;
      };

      _isInitialized = true;
      if (kDebugMode) print('Firebase services initialized');
    } catch (e) {
      if (kDebugMode) print('Failed to initialize Firebase: $e');
      // Continue without Firebase rather than crashing
    }
  }

  /// Log a non-fatal error to Crashlytics
  static Future<void> logError(
    dynamic exception,
    StackTrace? stack, {
    String? reason,
    bool fatal = false,
  }) async {
    if (_crashlytics == null) return;

    try {
      await _crashlytics!.recordError(
        exception,
        stack,
        reason: reason,
        fatal: fatal,
      );
      if (kDebugMode) print('Error logged to Crashlytics: $exception');
    } catch (e) {
      if (kDebugMode) print('Failed to log error to Crashlytics: $e');
    }
  }

  /// Log a custom message to Crashlytics
  static Future<void> log(String message) async {
    if (_crashlytics == null) return;

    try {
      await _crashlytics!.log(message);
    } catch (e) {
      if (kDebugMode) print('Failed to log message: $e');
    }
  }

  /// Set user identifier for crash reports
  static Future<void> setUserId(String userId) async {
    if (_crashlytics == null || _analytics == null) return;

    try {
      await _crashlytics!.setUserIdentifier(userId);
      await _analytics!.setUserId(id: userId);
      if (kDebugMode) print('User ID set: $userId');
    } catch (e) {
      if (kDebugMode) print('Failed to set user ID: $e');
    }
  }

  /// Set custom key-value pairs for crash reports
  static Future<void> setCustomKey(String key, dynamic value) async {
    if (_crashlytics == null) return;

    try {
      await _crashlytics!.setCustomKey(key, value);
    } catch (e) {
      if (kDebugMode) print('Failed to set custom key: $e');
    }
  }

  /// Log an analytics event
  static Future<void> logEvent(
    String name, {
    Map<String, Object>? parameters,
  }) async {
    if (_analytics == null) return;

    try {
      await _analytics!.logEvent(
        name: name,
        parameters: parameters,
      );
      if (kDebugMode) print('Analytics event logged: $name');
    } catch (e) {
      if (kDebugMode) print('Failed to log analytics event: $e');
    }
  }

  /// Log screen view
  static Future<void> logScreenView(String screenName) async {
    if (_analytics == null) return;

    try {
      await _analytics!.logScreenView(
        screenName: screenName,
      );
      if (kDebugMode) print('Screen view logged: $screenName');
    } catch (e) {
      if (kDebugMode) print('Failed to log screen view: $e');
    }
  }

  /// Check if Crashlytics collection is enabled
  static bool isCrashlyticsCollectionEnabled() {
    if (_crashlytics == null) return false;
    
    try {
      return _crashlytics!.isCrashlyticsCollectionEnabled;
    } catch (e) {
      return false;
    }
  }

  /// Enable/disable Crashlytics collection
  static Future<void> setCrashlyticsCollectionEnabled(bool enabled) async {
    if (_crashlytics == null) return;

    try {
      await _crashlytics!.setCrashlyticsCollectionEnabled(enabled);
      if (kDebugMode) print('Crashlytics collection ${enabled ? "enabled" : "disabled"}');
    } catch (e) {
      if (kDebugMode) print('Failed to set Crashlytics collection: $e');
    }
  }

  /// Force a crash (for testing - use in debug mode only)
  static void testCrash() {
    if (kDebugMode) {
      _crashlytics?.crash();
    }
  }

  /// Get Analytics instance
  static FirebaseAnalytics? get analytics => _analytics;

  /// Get Crashlytics instance
  static FirebaseCrashlytics? get crashlytics => _crashlytics;
}
