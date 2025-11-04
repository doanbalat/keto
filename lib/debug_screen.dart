import 'package:flutter/material.dart';
import 'database/database_helper.dart';
import 'scripts/generate_test_data.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final DatabaseHelper _db = DatabaseHelper();

  bool _isLoading = false;
  String _statusMessage = '';

  Future<void> _resetDatabase() async {
    final confirmed = await _showConfirmationDialog(
      'Xóa toàn bộ dữ liệu',
      'Bạn có chắc chắn muốn xóa TẤT CẢ dữ liệu? Hành động này không thể hoàn tác!',
      isDangerous: true,
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Đang xóa dữ liệu...';
    });

    try {
      await _db.clearAllData();

      setState(() {
        _statusMessage = '✅ Đã xóa toàn bộ dữ liệu thành công!';
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database đã được reset thành công'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Lỗi: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteAllSales() async {
    final confirmed = await _showConfirmationDialog(
      'Xóa tất cả dữ liệu bán hàng',
      'Bạn có chắc chắn muốn xóa tất cả dữ liệu bán hàng?',
      isDangerous: true,
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Đang xóa dữ liệu bán hàng...';
    });

    try {
      final soldItems = await _db.getAllSoldItems();
      for (var item in soldItems) {
        await _db.deleteSoldItem(item.id);
      }

      setState(() {
        _statusMessage = '✅ Đã xóa ${soldItems.length} giao dịch bán hàng!';
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xóa ${soldItems.length} giao dịch bán hàng'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Lỗi: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteAllExpenses() async {
    final confirmed = await _showConfirmationDialog(
      'Xóa tất cả chi phí',
      'Bạn có chắc chắn muốn xóa tất cả dữ liệu chi phí?',
      isDangerous: true,
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Đang xóa chi phí...';
    });

    try {
      final expenses = await _db.getAllExpenses();
      for (var expense in expenses) {
        await _db.deleteExpense(expense.id);
      }

      setState(() {
        _statusMessage = '✅ Đã xóa ${expenses.length} chi phí!';
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã xóa ${expenses.length} chi phí'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Lỗi: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _showDatabaseStats() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Đang tải thông tin database...';
    });

    try {
      final products = await _db.getAllProducts();
      final soldItems = await _db.getAllSoldItems();
      final expenses = await _db.getAllExpenses();

      final totalRevenue = await _db.getTotalSalesToday();
      final totalExpenses = await _db.getTotalExpensesToday();

      setState(() {
        _statusMessage =
            '''
📊 Thống kê Database:
━━━━━━━━━━━━━━━━━━━━━━
📦 Sản phẩm: ${products.length}
💰 Giao dịch bán: ${soldItems.length}
💸 Chi phí: ${expenses.length}
━━━━━━━━━━━━━━━━━━━━━━
Hôm nay:
  Doanh thu: ${_formatCurrency(totalRevenue)}
  Chi phí: ${_formatCurrency(totalExpenses)}
''';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Lỗi: $e';
        _isLoading = false;
      });
    }
  }

  String _formatCurrency(int amount) {
    return '${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}₫';
  }

  Future<void> _generateTestData() async {
    final confirmed = await _showConfirmationDialog(
      'Tạo dữ liệu test',
      'Bạn có muốn tạo 2 tháng dữ liệu test (bao gồm 10 sản phẩm, 60 ngày giao dịch và chi phí)?',
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Đang tạo dữ liệu test...';
    });

    try {
      await TestDataGenerator.generateTestData();

      setState(() {
        _statusMessage = '✅ Đã tạo dữ liệu test thành công!';
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dữ liệu test đã được tạo'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Lỗi: $e';
        _isLoading = false;
      });
    }
  }

  Future<bool?> _showConfirmationDialog(
    String title,
    String message, {
    bool isDangerous = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: isDangerous ? Colors.red : Colors.blue,
              ),
              child: const Text('Xác nhận'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Database'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Warning banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Cảnh báo: Các thao tác này có thể xóa dữ liệu vĩnh viễn!\nKhông thể khôi phúc dữ liệu sau khi xóa!',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Status message
                  if (_statusMessage.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _statusMessage,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Database Stats
                  _buildSectionTitle('Thông tin Database'),
                  _buildActionButton(
                    icon: Icons.info_outline,
                    label: 'Xem thống kê Database',
                    color: Colors.blue,
                    onPressed: _showDatabaseStats,
                  ),
                  const SizedBox(height: 24),

                  // Test Data Generation
                  _buildSectionTitle('Tạo dữ liệu Test'),
                  _buildActionButton(
                    icon: Icons.auto_awesome,
                    label: 'Tạo 2 tháng dữ liệu test',
                    color: Colors.purple,
                    onPressed: _generateTestData,
                  ),
                  const SizedBox(height: 24),

                  // Selective Delete
                  _buildSectionTitle('Xóa từng phần'),
                  _buildActionButton(
                    icon: Icons.delete_outline,
                    label: 'Xóa tất cả dữ liệu bán hàng',
                    color: Colors.red.shade300,
                    onPressed: _deleteAllSales,
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    icon: Icons.delete_outline,
                    label: 'Xóa tất cả chi phí',
                    color: Colors.red.shade300,
                    onPressed: _deleteAllExpenses,
                  ),
                  const SizedBox(height: 24),

                  // Danger Zone
                  _buildSectionTitle('⚠️ Vùng nguy hiểm'),
                  _buildActionButton(
                    icon: Icons.delete_forever,
                    label: 'XÓA TOÀN BỘ DATABASE',
                    color: Colors.red,
                    onPressed: _resetDatabase,
                  ),
                  const SizedBox(height: 24),

                  // Info card
                  Card(
                    color: Colors.blue.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
                                color: Colors.blue.shade700,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Gợi ý',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '• Sử dụng "Xem thống kê" để kiểm tra dữ liệu hiện tại\n'
                            '• "Tạo dữ liệu test" tạo 2 tháng dữ liệu test (10 sản phẩm, 60 ngày giao dịch)\n'
                            '• "Xóa dữ liệu bán hàng/chi phí" xóa từng phần dữ liệu\n'
                            '• Dữ liệu bị xóa KHÔNG THỂ khôi phục',
                            style: TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
