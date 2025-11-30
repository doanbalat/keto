import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:shared_preferences/shared_preferences.dart';
import 'services/permission_service.dart';
import 'services/currency_service.dart';
import 'services/product_category_service.dart';
import 'services/localization_service.dart';
import 'theme/theme_manager.dart';
import 'privacy_policy_page.dart';

class SettingsPage extends StatefulWidget {
  final int lowStockThreshold;
  final Function(int) onLowStockThresholdChanged;
  final String shopName;
  final Function(String) onShopNameChanged;
  final bool soundEnabled;
  final Function(bool) onSoundEnabledChanged;
  final Function(bool) onThemeChanged;
  final String language;
  final Function(String) onLanguageChanged;

  const SettingsPage({
    super.key,
    required this.lowStockThreshold,
    required this.onLowStockThresholdChanged,
    required this.shopName,
    required this.onShopNameChanged,
    required this.soundEnabled,
    required this.onSoundEnabledChanged,
    required this.onThemeChanged,
    required this.language,
    required this.onLanguageChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late int _lowStockThreshold;
  late bool _notificationsEnabled;
  late bool _soundEnabled;
  late String _selectedCurrency;
  late bool _isDarkMode;
  late String _selectedLanguage;
  String _defaultProductCategory = 'Khác'; // Initialize directly with default value
  late TextEditingController _thresholdController;
  late TextEditingController _shopNameController;

  @override
  void initState() {
    super.initState();
    _lowStockThreshold = widget.lowStockThreshold;
    _loadNotificationsEnabled();
    _soundEnabled = widget.soundEnabled;
    _isDarkMode = false; // Default value
    _loadDarkMode(); // Load actual dark mode asynchronously
    _selectedCurrency = 'VND'; // Default value
    _loadCurrency(); // Load actual currency asynchronously
    _selectedLanguage = widget.language;
    _defaultProductCategory = 'Khác'; // Default value
    _loadDefaultProductCategory(); // Load actual default category asynchronously
    // Set initial value to 5 if not provided
    if (_lowStockThreshold <= 0) {
      _lowStockThreshold = 5;
      widget.onLowStockThresholdChanged(5);
    }
    _thresholdController = TextEditingController(text: _lowStockThreshold.toString());
    _shopNameController = TextEditingController(text: widget.shopName);
  }

  Future<void> _loadDefaultProductCategory() async {
    try {
      final category = await ProductCategoryService.getDefaultCategory();
      setState(() {
        _defaultProductCategory = category;
      });
    } catch (e) {
      // Fallback to default if service not ready
      setState(() {
        _defaultProductCategory = 'Khác';
      });
    }
  }

  Future<void> _loadDarkMode() async {
    try {
      setState(() {
        _isDarkMode = ThemeManager().isDarkMode;
      });
    } catch (e) {
      // Fallback to default if theme manager not ready
      setState(() {
        _isDarkMode = false;
      });
    }
  }

  Future<void> _loadCurrency() async {
    try {
      setState(() {
        _selectedCurrency = CurrencyService.getCurrency();
      });
    } catch (e) {
      // Fallback to default if currency service not ready
      setState(() {
        _selectedCurrency = 'VND';
      });
    }
  }

  @override
  void dispose() {
    _thresholdController.dispose();
    _shopNameController.dispose();
    super.dispose();
  }

  static const String _defaultShopName = 'Keto - Sổ tay kinh doanh';

  Future<void> _loadNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? false;
    });
  }

  Future<void> _saveNotificationsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', value);
  }

  void _resetShopName() {
    setState(() {
      _shopNameController.text = _defaultShopName;
    });
    widget.onShopNameChanged(_defaultShopName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(LocalizationService.getString('settings_title')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocalizationService.getString('settings_display'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.storefront, color: Colors.blue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            LocalizationService.getString('settings_shop_name'),
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.grey),
                          tooltip: LocalizationService.getString('settings_reset_default'),
                          onPressed: _resetShopName,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: TextField(
                      controller: _shopNameController,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        hintText: _defaultShopName,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        suffixIcon: null,
                      ),
                      onChanged: (value) {
                        widget.onShopNameChanged(value);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                      color: Colors.blue,
                    ),
                    title: Text(LocalizationService.getString('settings_dark_mode')),
                    subtitle: Text(
                      _isDarkMode ? LocalizationService.getString('settings_on') : LocalizationService.getString('settings_off'),
                      style: TextStyle(
                        color: _isDarkMode ? Colors.blue : Colors.grey,
                      ),
                    ),
                    trailing: Switch(
                      value: _isDarkMode,
                      onChanged: (value) {
                        setState(() {
                          _isDarkMode = value;
                        });
                        widget.onThemeChanged(value);
                      },
                      activeThumbColor: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              LocalizationService.getString('settings_language'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.language, color: Colors.purple),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        LocalizationService.getString('settings_select_language'),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    DropdownButton<String>(
                      value: _selectedLanguage,
                      items: LocalizationService.getAvailableLanguages().map((String lang) {
                        return DropdownMenuItem<String>(
                          value: lang,
                          child: Text(
                            LocalizationService.getLanguageDisplayName(lang),
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedLanguage = newValue;
                          });
                          widget.onLanguageChanged(newValue);
                        }
                      },
                      underline: Container(),
                      style: const TextStyle(color: Colors.purple),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              LocalizationService.getString('settings_currency'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.currency_exchange, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        LocalizationService.getString('settings_select_currency'),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    DropdownButton<String>(
                      value: _selectedCurrency,
                      items: CurrencyService.getAvailableCurrencies().map((String currency) {
                        return DropdownMenuItem<String>(
                          value: currency,
                          child: Text(
                            '$currency ${CurrencyService.getSymbol(currency)}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (String? newValue) async {
                        if (newValue != null) {
                          setState(() {
                            _selectedCurrency = newValue;
                          });
                          await CurrencyService.setCurrency(newValue);
                        }
                      },
                      underline: Container(),
                      style: const TextStyle(color: Colors.blue),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              LocalizationService.getString('settings_sound'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      _soundEnabled ? Icons.volume_up : Icons.volume_off,
                      color: Colors.blue,
                    ),
                    title: Text(LocalizationService.getString('settings_sound_on_sale')),
                    subtitle: Text(
                      _soundEnabled ? LocalizationService.getString('settings_on') : LocalizationService.getString('settings_off'),
                      style: TextStyle(
                        color: _soundEnabled ? Colors.green : Colors.grey,
                      ),
                    ),
                    trailing: Switch(
                      value: _soundEnabled,
                      onChanged: (value) {
                        setState(() {
                          _soundEnabled = value;
                        });
                        widget.onSoundEnabledChanged(value);
                      },
                      activeThumbColor: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              LocalizationService.getString('settings_products'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.category, color: Colors.purple),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            LocalizationService.getString('settings_default_category'),
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[800]
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: DropdownButton<String>(
                        value: _defaultProductCategory,
                        items: ProductCategoryService.categories.map((String category) {
                          final displayName = ProductCategoryService.getCategoryDisplayName(category);
                          return DropdownMenuItem<String>(
                            value: category,
                            child: Text(
                              displayName,
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.orange[200]
                                    : Colors.green,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (String? newValue) async {
                          if (newValue != null) {
                            setState(() {
                              _defaultProductCategory = newValue;
                            });
                            await ProductCategoryService.setDefaultCategory(newValue);
                          }
                        },
                        underline: Container(),
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.orange[200]
                            : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                        isExpanded: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              LocalizationService.getString('settings_inventory'),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            LocalizationService.getString('settings_low_stock_threshold'),
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: TextField(
                            keyboardType: TextInputType.number,
                            controller: _thresholdController,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                            onChanged: (value) {
                              if (value.isNotEmpty) {
                                final threshold = int.tryParse(value);
                                if (threshold != null && threshold > 0) {
                                  setState(() {
                                    _lowStockThreshold = threshold;
                                  });
                                  widget.onLowStockThresholdChanged(threshold);
                                }
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 10),
                  ListTile(
                    leading: const Icon(Icons.notifications, color: Colors.blue),
                    title: Text(LocalizationService.getString('settings_notifications')),
                    subtitle: Text(
                      _notificationsEnabled ? LocalizationService.getString('settings_on') : LocalizationService.getString('settings_off'),
                      style: TextStyle(
                        color: _notificationsEnabled ? Colors.green : Colors.grey,
                      ),
                    ),
                    trailing: Switch(
                      value: _notificationsEnabled,
                      onChanged: (value) async {
                        // If user is enabling notifications, request permission first
                        if (value) {
                          final hasPermission = await PermissionService.requestNotificationPermission();
                          
                          if (!hasPermission) {
                            // Permission denied - show dialog
                            if (!mounted) return;
                            showDialog(
                              context: context,
                              builder: (BuildContext ctx) {
                                return AlertDialog(
                                  title: Text(LocalizationService.getString('dialog_notification_permission')),
                                  content: Text(
                                    LocalizationService.getString('dialog_notification_message'),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: Text(LocalizationService.getString('dialog_later')),
                                    ),
                                    ElevatedButton(
                                      onPressed: () async {
                                        Navigator.pop(ctx);
                                        await PermissionService.openSettings();
                                      },
                                      child: Text(LocalizationService.getString('dialog_open_settings')),
                                    ),
                                  ],
                                );
                              },
                            );
                            return;
                          }
                        }
                        
                        // Update state and save
                        setState(() {
                          _notificationsEnabled = value;
                        });
                        _saveNotificationsEnabled(value);
                      },
                      activeThumbColor: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Test Crash Button (Debug only - hidden in production)
            if (kDebugMode)
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  ),
                  onPressed: () {
                    // Force a crash to test Crashlytics
                    throw Exception('Test crash from settings page');
                  },
                  child: const Text(
                    'Test Crash (Debug Only)',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Center(
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PrivacyPolicyPage(),
                    ),
                  );
                },
                icon: const Icon(Icons.privacy_tip),
                label: const Text('View Privacy Policy'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  backgroundColor: Colors.blue,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Column(
                children: [
                  Text(
                    'v${LocalizationService.appVersion}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 200),
          ],
        ),
      ),
    );
  }
}
