// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io' show Platform;
import 'package:shared_preferences/shared_preferences.dart';

import 'theme/theme_manager.dart';
import 'services/notification_service.dart';
import 'services/currency_service.dart';
import 'services/admob_service.dart';
import 'services/firebase_service.dart';
import 'services/localization_service.dart';
import 'services/preference_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize FFI for desktop platforms only (not web or mobile)
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize Shared Services
  await ThemeManager().init();
  await PreferenceService().init();
  
  // Initialize NotificationService
  await NotificationService().init();

  // Initialize CurrencyService
  await CurrencyService.init();

  // Load language preference from our new service
  final prefs = PreferenceService(); 
  final savedLanguage = prefs.language;
  LocalizationService.setLanguage(savedLanguage);

  // Initialize Firebase (only on mobile platforms)
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await Firebase.initializeApp();
    await FirebaseService.initialize();
  }

  // Initialize AdMob (only on mobile platforms)
  await AdMobService.initialize();

  // Note: Permissions are requested on-demand when user needs them
  // Camera/Photo permissions: requested when user chooses "Add Image"
  // Storage permission: automatically granted on iOS, optional on Android

  runApp(const KetoApp());
}
