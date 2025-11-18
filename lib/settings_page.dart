import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/permission_service.dart';
import 'services/currency_service.dart';
import 'services/product_category_service.dart';
import 'theme/theme_manager.dart';

class SettingsPage extends StatefulWidget {
  final int lowStockThreshold;
  final Function(int) onLowStockThresholdChanged;
  final String shopName;
  final Function(String) onShopNameChanged;
  final bool soundEnabled;
  final Function(bool) onSoundEnabledChanged;
  final Function(bool) onThemeChanged;

  const SettingsPage({
    super.key,
    required this.lowStockThreshold,
    required this.onLowStockThresholdChanged,
    required this.shopName,
    required this.onShopNameChanged,
    required this.soundEnabled,
    required this.onSoundEnabledChanged,
    required this.onThemeChanged,
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
        title: const Text('Cài đặt'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hiển thị',
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
                            'Tên cửa hàng',
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.grey),
                          tooltip: 'Đặt lại tên mặc định',
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
                    title: const Text('Chế độ tối'),
                    subtitle: Text(
                      _isDarkMode ? 'Bật' : 'Tắt',
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
              'Tiền tệ',
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
                        'Chọn loại tiền tệ',
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
              'Âm thanh',
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
                    title: const Text('Âm thanh khi bán hàng'),
                    subtitle: Text(
                      _soundEnabled ? 'Bật' : 'Tắt',
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
              'Sản phẩm',
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
                            'Loại sản phẩm mặc định',
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
              'Kho hàng',
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
                            'Ngưỡng sắp hết hàng',
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
                    title: const Text('Nhận thông báo về kho hàng'),
                    subtitle: Text(
                      _notificationsEnabled ? 'Bật' : 'Tắt',
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
                                  title: const Text('Yêu cầu quyền thông báo'),
                                  content: const Text(
                                    'Ứng dụng cần quyền gửi thông báo để nhắc nhở bạn khi hàng sắp hết. '
                                    'Vui lòng cấp quyền trong cài đặt.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('Để sau'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () async {
                                        Navigator.pop(ctx);
                                        await PermissionService.openSettings();
                                      },
                                      child: const Text('Mở cài đặt'),
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
            const SizedBox(height: 200),
            Center(
              child: Text(
              'Phiên bản 1.0.0',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
