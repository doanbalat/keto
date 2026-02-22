import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'services/preference_service.dart';

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
  
  // Keys for each page to force rebuild on refresh
  UniqueKey _salesPageKey = UniqueKey();
  UniqueKey _expensesPageKey = UniqueKey();
  UniqueKey _inventoryPageKey = UniqueKey();
  UniqueKey _statisticsPageKey = UniqueKey();
  
  // Local state managed by PreferenceService but needed here for UI
  int _lowStockThreshold = 5;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }
  
  Future<void> _loadPreferences() async {
    final prefs = PreferenceService();
    // Assuming PreferenceService is initialized in main
    setState(() {
      _lowStockThreshold = prefs.lowStockThreshold;
      _notificationsEnabled = prefs.notificationsEnabled;
    });
  }

  void _updatePreferences() async {
    // Reload if needed after returning from settings
    await _loadPreferences();
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

  List<Widget> _buildPages() {
    return [
      SalesPage(
        key: _salesPageKey, 
        soundEnabled: widget.soundEnabled, // Use widget property passed from app
        lowStockThreshold: _lowStockThreshold, 
        notificationsEnabled: _notificationsEnabled
      ),
      ExpensesPage(key: _expensesPageKey),
      InventoryPage(
        key: _inventoryPageKey, 
        lowStockThreshold: _lowStockThreshold
      ),
      StatisticsPage(key: _statisticsPageKey),
    ];
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _refreshCurrentPage();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Đã làm mới dữ liệu')),
              );
            },
            tooltip: 'Làm mới dữ liệu',
          ),
        ],
      ),
      drawer: NavigationDrawer(
        selectedIndex: _selectedIndex,
        children: [
          Container(
            height: 160,
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
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Keto - Sổ Tay Bán Hàng',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.shopName,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.shopping_cart),
            title: const Text('Bán Hàng'),
            selected: _selectedIndex == 0,
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _selectedIndex = 0;
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.attach_money),
            title: const Text('Chi Tiêu'),
            selected: _selectedIndex == 1,
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _selectedIndex = 1;
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.inventory),
            title: const Text('Kho Hàng'),
            selected: _selectedIndex == 2,
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _selectedIndex = 2;
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart),
            title: const Text('Thống Kê'),
            selected: _selectedIndex == 3,
            onTap: () {
              Navigator.pop(context);
              setState(() {
                _selectedIndex = 3;
              });
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Cài Đặt'),
            onTap: () async {
              Navigator.pop(context);
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsPage(
                    // isDarkMode removed as it is not in SettingsPage constructor
                    onThemeChanged: widget.onThemeChanged,
                    shopName: widget.shopName,
                    onShopNameChanged: widget.onShopNameChanged,
                    onSoundEnabledChanged: widget.onSoundEnabledChanged,
                    soundEnabled: widget.soundEnabled,
                    language: widget.language,
                    onLanguageChanged: widget.onLanguageChanged,
                    // Added missing required parameters
                    lowStockThreshold: _lowStockThreshold,
                    onLowStockThresholdChanged: (value) async {
                      final prefs = PreferenceService();
                      await prefs.setLowStockThreshold(value);
                      setState(() {
                        _lowStockThreshold = value;
                      });
                    },
                  ),
                ),
              );
              // Refresh preferences after returning from settings
              _updatePreferences(); 
            },
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('Quản Lý Database'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DatabaseManagementPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.inventory_2_outlined),
            title: const Text('Quản Lý Sản Phẩm'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProductManagementPage()),
              );
            },
          ),
          const Divider(),
          // Recipe calculator
           ListTile(
            leading: const Icon(Icons.calculate),
            title: const Text('Công Thức Cơ Bản'),
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (context) => const BasicFormulasPage(),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Chính Sách Bảo Mật'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PrivacyPolicyPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Giới Thiệu'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AboutPage()),
              );
            },
          ),
        ],
      ),
      body: _buildPages()[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Bán Hàng',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.attach_money),
            label: 'Chi Tiêu',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory),
            label: 'Kho Hàng',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Thống Kê',
          ),
        ],
        currentIndex: _selectedIndex,
        // Using fixed type for >3 items
        type: BottomNavigationBarType.fixed,
        onTap: _onItemTapped,
      ),
    );
  }
}
