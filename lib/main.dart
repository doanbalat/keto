import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'dart:io' show Platform;
import 'ban_hang.dart';
import 'chi_tieu.dart';
import 'thong_ke.dart';
import 'quan_ly_database.dart';
import 'kho_hang.dart';
import 'cong_thuc_co_ban.dart';
import 'privacy_policy_page.dart';
import 'settings_page.dart';
import 'quan_ly_san_pham.dart';
import 'about_page.dart';
import 'theme/app_theme.dart';
import 'theme/theme_manager.dart';
import 'services/notification_service.dart';
import 'services/currency_service.dart';
import 'services/admob_service.dart';
import 'services/firebase_service.dart';
import 'services/localization_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize FFI for desktop platforms only (not web or mobile)
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize ThemeManager
  await ThemeManager().init();

  // Initialize NotificationService
  await NotificationService().init();

  // Initialize CurrencyService
  await CurrencyService.init();

  // Load language preference
  final prefs = await SharedPreferences.getInstance();
  final savedLanguage = prefs.getString('language') ?? 'vi';
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

  @override
  void initState() {
    super.initState();
    _isDarkMode = ThemeManager().isDarkMode;
    _language = LocalizationService.language;
    _loadShopName();
    _loadSoundEnabled();
    print('KetoApp initialized - isDarkMode: $_isDarkMode, language: $_language');
  }

  Future<void> _loadShopName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _shopName = prefs.getString('shopName') ?? 'Keto - Sổ Tay Bán Hàng';
    });
  }

  Future<void> _loadSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _soundEnabled = prefs.getBool('soundEnabled') ?? true;
    });
  }

  void _setTheme(bool isDarkMode) async {
    print('Setting theme to: $isDarkMode');
    await ThemeManager().setDarkMode(isDarkMode);
    setState(() {
      _isDarkMode = isDarkMode;
      print('KetoApp state updated - isDarkMode: $_isDarkMode');
    });
  }

  void _setShopName(String shopName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('shopName', shopName);
    setState(() {
      _shopName = shopName;
    });
  }

  void _setSoundEnabled(bool soundEnabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('soundEnabled', soundEnabled);
    setState(() {
      _soundEnabled = soundEnabled;
    });
  }

  void _setLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', language);
    LocalizationService.setLanguage(language);
    setState(() {
      _language = language;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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

class KetoHomepage extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onThemeChanged;
  final String shopName;
  final Function(String) onShopNameChanged;
  final bool soundEnabled;
  final Function(bool) onSoundEnabledChanged;
  final String language;
  final Function(String) onLanguageChanged;

  const KetoHomepage({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.shopName,
    required this.onShopNameChanged,
    required this.soundEnabled,
    required this.onSoundEnabledChanged,
    required this.language,
    required this.onLanguageChanged,
  });

  @override
  State<KetoHomepage> createState() => _KetoHomepageState();
}

class _KetoHomepageState extends State<KetoHomepage> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _lowStockThreshold = 5;
  bool _notificationsEnabled = true;
  // Keys for each page to force rebuild on refresh
  UniqueKey _salesPageKey = UniqueKey();
  UniqueKey _expensesPageKey = UniqueKey();
  UniqueKey _inventoryPageKey = UniqueKey();
  UniqueKey _statisticsPageKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _loadLowStockThreshold();
    _loadNotificationsEnabled();
  }

  Future<void> _loadLowStockThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lowStockThreshold = prefs.getInt('lowStockThreshold') ?? 5;
    });
  }

  Future<void> _loadNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? false;
    });
  }

  Future<void> _saveLowStockThreshold(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lowStockThreshold', value);
  }

  List<Widget> _buildPages() {
    return [
      SalesPage(key: _salesPageKey, soundEnabled: widget.soundEnabled, lowStockThreshold: _lowStockThreshold, notificationsEnabled: _notificationsEnabled),
      ExpensesPage(key: _expensesPageKey),
      InventoryPage(key: _inventoryPageKey, lowStockThreshold: _lowStockThreshold),
      StatisticsPage(key: _statisticsPageKey),
    ];
  }

  void _refreshCurrentPage() {
    setState(() {
      // Create new keys to force rebuild of pages
      _salesPageKey = UniqueKey();
      _expensesPageKey = UniqueKey();
      _inventoryPageKey = UniqueKey();
      _statisticsPageKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(widget.shopName),
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
      ),
      drawer: NavigationDrawer(
        selectedIndex: _selectedIndex,
        children: [
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: const AssetImage('assets/images/bg.png'),
                fit: BoxFit.cover,
                // Optional: Add color overlay for better text readability
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.3),
                  BlendMode.darken,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 2.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Keto - Sổ Tay Bán Hàng',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Coming Soon!'),
                        content: const Text('Bản Pro sẽ sớm ra mắt với nhiều tính năng hơn! Hãy chờ đón nhé!'),
                        actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('OK'),
                        ),
                        ],
                      ),
                      );
                    },
                    icon: const Icon(Icons.star, color: Colors.red),
                    label: const Text('Upgrade to Pro'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.yellow,
                      foregroundColor: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Theme Toggle
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          widget.onThemeChanged(!widget.isDarkMode);
                        },
                        borderRadius: BorderRadius.circular(28),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.light_mode,
                                color: Colors.yellow,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 32,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: widget.isDarkMode
                                      ? Colors.black54
                                      : Colors.grey[400],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Stack(
                                  children: [
                                    AnimatedAlign(
                                      alignment: widget.isDarkMode
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      duration:
                                          const Duration(milliseconds: 200),
                                      child: Container(
                                        width: 16,
                                        height: 16,
                                        margin: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(7),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black
                                                  .withValues(alpha: 0.2),
                                              blurRadius: 4,
                                              offset:
                                                  const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.dark_mode,
                                color: Colors.yellow[200],
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          const Divider(),
          // Main Pages
          NavigationDrawerDestination(
            icon: const Icon(Icons.monetization_on, color: Colors.green),
            label: Text(LocalizationService.getString('nav_sales')),
          ),
          NavigationDrawerDestination(
            icon: const Icon(Icons.monetization_on, color: Colors.red),
            label: Text(LocalizationService.getString('nav_expenses')),
          ),
          NavigationDrawerDestination(
            icon: const Icon(Icons.shelves, color: Colors.orange),
            label: Text(LocalizationService.getString('nav_inventory')),
          ),
          NavigationDrawerDestination(
            icon: const Icon(Icons.poll, color: Colors.blue),
            label: Text(LocalizationService.getString('nav_statistics')),
          ),
          const Divider(),
          // Product Management & Data Management
          NavigationDrawerDestination(
            icon: const Icon(Icons.shopping_bag, color: Colors.purple),
            label: Text(LocalizationService.getString('nav_product_management')),
          ),
          NavigationDrawerDestination(
            icon: const Icon(Icons.auto_stories, color: Colors.teal),
            label: Text(LocalizationService.getString('nav_data_management')),
          ),
          const Divider(),
          // Settings & Utilities
          NavigationDrawerDestination(
            icon: const Icon(Icons.settings),
            label: Text(LocalizationService.getString('nav_settings')),
          ),
          NavigationDrawerDestination(
            icon: const Icon(Icons.calculate),
            label: Text(LocalizationService.getString('nav_formulas')),
          ),
          NavigationDrawerDestination(
            icon: const Icon(Icons.privacy_tip),
            label: Text(LocalizationService.getString('nav_privacy')),
          ),
          NavigationDrawerDestination(
            icon: const Icon(Icons.person),
            label: Text(LocalizationService.getString('nav_about')),
          ),
        ],
        onDestinationSelected: (index) async {
          Navigator.pop(context); // Close drawer

          // Main pages (0-3)
          if (index == 0) {
            // Sales
            setState(() {
              _selectedIndex = 0;
            });
          } else if (index == 1) {
            // Expenses
            setState(() {
              _selectedIndex = 1;
            });
          } else if (index == 2) {
            // Inventory
            setState(() {
              _selectedIndex = 2;
            });
          } else if (index == 3) {
            // Statistics
            setState(() {
              _selectedIndex = 3;
            });
          }
          // Product Management & Settings & Utilities (4-8)
          else if (index == 4) {
            // Product Management
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ProductManagementPage(),
              ),
            );
            
            // Refresh the app when user closes the product management page
            if (mounted) {
              _refreshCurrentPage();
            }
          } else if (index == 5) {
            // Data Management
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DebugScreen()),
            );
            
            // If data was modified, refresh the current page
            if (result == true && mounted) {
              _refreshCurrentPage();
            }
          } else if (index == 6) {
            // Settings
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SettingsPage(
                  lowStockThreshold: _lowStockThreshold,
                  onLowStockThresholdChanged: (value) {
                    setState(() {
                      _lowStockThreshold = value;
                    });
                    _saveLowStockThreshold(value);
                    _refreshCurrentPage();
                  },
                  shopName: widget.shopName,
                  onShopNameChanged: widget.onShopNameChanged,
                  soundEnabled: widget.soundEnabled,
                  onSoundEnabledChanged: widget.onSoundEnabledChanged,
                  onThemeChanged: widget.onThemeChanged,
                  language: widget.language,
                  onLanguageChanged: widget.onLanguageChanged,
                ),
              ),
            ).then((_) {
              // Reload notification settings when returning from settings page
              _loadNotificationsEnabled().then((_) {
                _refreshCurrentPage();
              });
            });
          } else if (index == 7) {
            // Basic Formulas
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BasicFormulasPage(),
              ),
            );
          } else if (index == 8) {
            // Privacy Policy
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PrivacyPolicyPage(),
              ),
            );
          } else if (index == 9) {
            // About
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AboutPage(),
              ),
            );
          }
        },
      ),
      body: _buildPages()[_selectedIndex],
    );
  }
}

class AccountingPage extends StatelessWidget {
  const AccountingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand();
  }
}
