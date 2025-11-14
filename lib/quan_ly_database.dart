import 'package:flutter/material.dart';
import 'dart:io';
import 'database/database_helper.dart';
import 'scripts/generate_test_data.dart';
import 'services/export_service.dart';
import 'services/permission_service.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final DatabaseHelper _db = DatabaseHelper();

  bool _isLoading = false;
  String _statusMessage = '';
  String _currentStage = '';
  int _progress = 0;
  int _progressTotal = 100;

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
        _statusMessage = '✅ Đã xóa toàn bộ dữ liệu thành công!\n\nDang làm mới ứng dụng...';
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Database đã được reset thành công'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Auto-refresh the app by popping with true
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.of(context).pop(true);
        }
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
      'Bạn có muốn tạo 1 tháng dữ liệu test (bao gồm 10 sản phẩm, 30 ngày giao dịch và chi phí)?',
    );

    if (confirmed != true) return;

    // Set progress callback
    TestDataGenerator.setProgressCallback((stage, current, total) {
      if (mounted) {
        setState(() {
          _currentStage = stage;
          _progress = current;
          _progressTotal = total;
        });
      }
    });

    setState(() {
      _isLoading = true;
      _statusMessage = 'Đang tạo dữ liệu test...';
      _currentStage = '';
      _progress = 0;
      _progressTotal = 100;
    });

    try {
      await TestDataGenerator.generateTestData();

      setState(() {
        _statusMessage = '✅ Đã tạo dữ liệu test thành công!';
        _isLoading = false;
        _currentStage = '';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Dữ liệu test đã được tạo'),
            backgroundColor: Colors.green,
          ),
        );
        // Auto-refresh the app by popping with true
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      setState(() {
        _statusMessage = '❌ Lỗi: $e';
        _isLoading = false;
        _currentStage = '';
      });
    } finally {
      // Clear callback
      TestDataGenerator.setProgressCallback((stage, current, total) {});
    }
  }

  Future<void> _showExportDialog() async {
    await showDialog<ExportFormat>(
      context: context,
      builder: (BuildContext context) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Icon(
                        Icons.download,
                        color: Colors.green.shade700,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Xuất dữ liệu',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isDarkMode ? Colors.white : Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Chọn định dạng xuất dữ liệu',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Export options
                _buildExportOption(
                  context,
                  icon: '{..}',
                  title: 'JSON',
                  description: 'Để backup hoặc import vào hệ thống khác',
                  onTap: () {
                    Navigator.of(context).pop();
                    _exportData(ExportFormat.json);
                  },
                ),
                const SizedBox(height: 12),
                _buildExportOption(
                  context,
                  icon: '📊',
                  title: 'CSV',
                  description: 'Để mở trong Excel hoặc Google Sheets',
                  onTap: () {
                    Navigator.of(context).pop();
                    _exportData(ExportFormat.csv);
                  },
                ),
                const SizedBox(height: 24),
                
                // Cancel button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(
                        color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Hủy',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[700],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExportOption(
    BuildContext context, {
    required String icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[800] : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
              width: 1.5,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                icon,
                style: const TextStyle(fontSize: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 18,
                color: isDarkMode ? Colors.grey[500] : Colors.grey[400],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportData(ExportFormat format) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Đang chuẩn bị dữ liệu xuất...';
    });

    try {
      // Request storage permission on Android
      if (Platform.isAndroid) {
        bool hasPermission = await PermissionService.isStoragePermissionGranted();
        if (!hasPermission) {
          hasPermission = await PermissionService.requestStoragePermission();
          if (!hasPermission) {
            if (mounted) {
              setState(() {
                _statusMessage = '❌ Lỗi: Cần cấp quyền truy cập bộ nhớ để xuất dữ liệu';
                _isLoading = false;
              });
            }
            return;
          }
        }
      }

      final products = await _db.getAllProducts();
      final soldItems = await _db.getAllSoldItems();
      final expenses = await _db.getAllExpenses();

      if (mounted) {
        setState(() {
          _statusMessage = 'Đang xuất dữ liệu sang ${ExportService.getFormatDisplayName(format)}...';
        });
      }

      String content;
      switch (format) {
        case ExportFormat.json:
          content = await ExportService.exportToJson(
            products: products,
            soldItems: soldItems,
            expenses: expenses,
          );
          break;
        case ExportFormat.csv:
          content = await ExportService.exportToCsv(
            products: products,
            soldItems: soldItems,
            expenses: expenses,
          );
          break;
      }

      final file = await ExportService.saveExportFile(content, format);

      if (mounted) {
        final fileName = file.path.split('/').last;
        print('🎉 EXPORT SUCCESS! File saved at: ${file.path}');
        print('📊 File details: $fileName | Size: ${(file.lengthSync() / 1024).toStringAsFixed(2)} KB');
        
        setState(() {
          _statusMessage =
              '''✅ Xuất dữ liệu thành công!
              
Tên file: $fileName
Đường dẫn: ${file.path}
Kích thước: ${(file.lengthSync() / 1024).toStringAsFixed(2)} KB

Sản phẩm: ${products.length}
Giao dịch bán: ${soldItems.length}
Chi phí: ${expenses.length}

💡 Cách tìm file trên Android:
📁 Files app → Internal Storage → Android → Data → com.example.keto → files
🔍 Tìm file: keto_export_*.csv hoặc keto_export_*.json

📌 DEBUG: ${file.path}
''';
          _isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('✅ Xuất dữ liệu thành công: $fileName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = '''❌ Lỗi xuất dữ liệu: $e

Chi tiết lỗi:
$e

Vui lòng kiểm tra:
• Bộ nhớ có đủ không?
• Ứng dụng có quyền lưu file không?
• Thử lại hoặc liên hệ hỗ trợ
''';
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Lỗi xuất dữ liệu: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
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
          ? Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 24),
                    if (_statusMessage.isNotEmpty) ...[
                      Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    if (_currentStage.isNotEmpty) ...[
                      Text(
                        _currentStage,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _progress / _progressTotal,
                          minHeight: 30,
                          backgroundColor: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey.shade700
                              : Colors.grey.shade300,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.blue.shade500,
                          ),
                          semanticsLabel: 'Progress bar',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${_progress}/${_progressTotal}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white70
                              : Colors.black87,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
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
                    child: Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.orange),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Cảnh báo: Các thao tác này có thể xóa dữ liệu vĩnh viễn!\nKhông thể khôi phúc dữ liệu sau khi xóa!',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.orange[300]
                                  : Colors.red,
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
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[800]
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _statusMessage,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.white70
                              : Colors.black87,
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

                  // Export Data Section
                  _buildSectionTitle('📤 Xuất dữ liệu'),
                  _buildActionButton(
                    icon: Icons.download,
                    label: 'Xuất dữ liệu (JSON, CSV, XLSX)',
                    color: Colors.green,
                    onPressed: _showExportDialog,
                  ),
                  const SizedBox(height: 24),

                  // Test Data Generation
                  _buildSectionTitle('Test Thử Nghiệm App'),
                  _buildActionButton(
                    icon: Icons.auto_awesome,
                    label: 'Tạo dữ liệu để test (30 ngày)',
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
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.blue[900]
                        : Colors.blue.shade50,
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
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.blue[300]
                                      : Colors.blue.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '• Sử dụng "Xem thống kê" để kiểm tra dữ liệu hiện tại\n'
                            '• "Xuất dữ liệu" để tải về máy tính dưới các định dạng:\n'
                            '  - JSON: Để backup hoặc import vào hệ thống khác\n'
                            '  - CSV: Để mở trong Excel hoặc Google Sheets\n'
                            '  - XLSX: Định dạng Excel chuẩn (được khuyến nghị)\n'
                            '• "Tạo dữ liệu test" tạo 2 tháng dữ liệu test (10 sản phẩm, 60 ngày giao dịch)\n'
                            '• "Xóa dữ liệu bán hàng/chi phí" xóa từng phần dữ liệu\n'
                            '• Dữ liệu bị xóa KHÔNG THỂ khôi phục',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white70
                                  : Colors.black87,
                            ),
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: isDarkMode ? Colors.white : Colors.black87,
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
