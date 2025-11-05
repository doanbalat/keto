import 'package:flutter/material.dart';
import 'ban_hang.dart';
import 'chi_tieu.dart';
import 'thong_ke.dart';
import 'debug_screen.dart';
import 'kho_hang.dart';
import 'cong_thuc_co_ban.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Note: Permissions are requested on-demand when user needs them
  // Camera/Photo permissions: requested when user chooses "Add Image"
  // Storage permission: automatically granted on iOS, optional on Android

  runApp(const KetoApp());
}

class KetoApp extends StatelessWidget {
  const KetoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Keto',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const KetoHomepage(),
    );
  }
}

class KetoHomepage extends StatefulWidget {
  const KetoHomepage({super.key});

  @override
  State<KetoHomepage> createState() => _KetoHomepageState();
}

class _KetoHomepageState extends State<KetoHomepage> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Widget> _pages = [
    const SalesPage(),
    const ExpensesPage(),
    const InventoryPage(),
    const StatisticsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Keto - Sổ Tay Bán Hàng'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            _scaffoldKey.currentState?.openDrawer();
          },
        ),
      ),
      drawer: NavigationDrawer(
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
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Keto (Free version)',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
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
                    icon: const Icon(Icons.star),
                    label: const Text('Upgrade to Pro'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          NavigationDrawerDestination(
            icon: const Icon(Icons.calculate),
            label: const Text('Các công thức cơ bản'),
          ),
          NavigationDrawerDestination(
            icon: const Icon(Icons.settings),
            label: const Text('Cài đặt'),
          ),
          NavigationDrawerDestination(
            icon: const Icon(Icons.auto_stories),
            label: const Text('Quản lý Dữ liệu'),
          ),
          NavigationDrawerDestination(
            icon: const Icon(Icons.privacy_tip),
            label: const Text('Chính sách bảo mật'),
          ),
          NavigationDrawerDestination(
            icon: const Icon(Icons.person),
            label: const Text('Tác giả'),
          ),
        ],
        onDestinationSelected: (index) {
          Navigator.pop(context); // Close drawer

          if (index == 0) {
            // Basic Formulas
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const BasicFormulasPage(),
              ),
            );
          } else if (index == 2) {
            // Debug screen (Data Management)
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const DebugScreen()),
            );
          }
          // Add other menu actions here
        },
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.white70,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.monetization_on, color: Colors.green),
            label: 'Bán Hàng',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.monetization_on, color: Colors.red),
            label: 'Chi Tiêu',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shelves, color: Colors.orange),
            label: 'Kho Hàng',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.poll, color: Colors.blue),
            label: 'Thống Kê',
          ),
        ],
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.black,
      ),
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
