import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  final bool isDarkMode;
  final Function(bool) onThemeChanged;
  final int lowStockThreshold;
  final Function(int) onLowStockThresholdChanged;
  final String shopName;
  final Function(String) onShopNameChanged;
  final bool soundEnabled;
  final Function(bool) onSoundEnabledChanged;

  const SettingsPage({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.lowStockThreshold,
    required this.onLowStockThresholdChanged,
    required this.shopName,
    required this.onShopNameChanged,
    required this.soundEnabled,
    required this.onSoundEnabledChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool _isDarkMode;
  late int _lowStockThreshold;
  late bool _notificationsEnabled;
  late bool _soundEnabled;
  late TextEditingController _thresholdController;
  late TextEditingController _shopNameController;

  @override
  void initState() {
    super.initState();
    _isDarkMode = widget.isDarkMode;
    _lowStockThreshold = widget.lowStockThreshold;
    _notificationsEnabled = true;
    _soundEnabled = widget.soundEnabled;
    // Set initial value to 5 if not provided
    if (_lowStockThreshold <= 0) {
      _lowStockThreshold = 5;
      widget.onLowStockThresholdChanged(5);
    }
    _thresholdController = TextEditingController(text: _lowStockThreshold.toString());
    _shopNameController = TextEditingController(text: widget.shopName);
  }

  @override
  void dispose() {
    _thresholdController.dispose();
    _shopNameController.dispose();
    super.dispose();
  }

  static const String _defaultShopName = 'Keto - Sổ tay kinh doanh';

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
                  const Divider(height: 10),
                  ListTile(
                    leading: Icon(
                      _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                      color: Colors.blue,
                    ),
                    title: const Text('Chế độ tối'),
                    subtitle: Text(
                      _isDarkMode ? 'Bật' : 'Tắt',
                      style: TextStyle(
                        color: _isDarkMode ? Colors.green : Colors.grey,
                      ),
                    ),
                    trailing: Switch(
                      value: _isDarkMode,
                      onChanged: (value) {
                        setState(() {
                          _isDarkMode = value;
                        });
                        print('Theme changed to: $_isDarkMode');
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
                    trailing: Switch(
                      value: _notificationsEnabled,
                      onChanged: (value) {
                        setState(() {
                          _notificationsEnabled = value;
                        });
                        // TODO: Implement notification logic
                      },
                      activeThumbColor: Colors.blue,
                    ),
                  ),
                  const Divider(height: 10),
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
