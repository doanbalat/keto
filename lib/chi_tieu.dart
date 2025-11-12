import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'models/expense_model.dart';
import 'services/expense_service.dart';
import 'services/permission_service.dart';

class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  final ExpenseService _expenseService = ExpenseService();
  final ScrollController _expenseListScrollController = ScrollController();

  List<Expense> todayExpenses = [];
  int totalExpensesToday = 0;
  bool _showExpensesList = false;
  String _selectedFilter = 'Hôm nay';

  @override
  void initState() {
    super.initState();
    _loadExpenses();
  }

  Future<void> _loadExpenses() async {
    try {
      late List<Expense> expenses;
      late int total;

      final now = DateTime.now();
      
      if (_selectedFilter == 'Hôm nay') {
        expenses = await _expenseService.getTodayExpenses();
        total = await _expenseService.getTotalExpensesToday();
      } else if (_selectedFilter == 'Tuần này') {
        // Calculate the start of the current week (Monday)
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final startOfWeekDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        final endOfWeekDate = startOfWeekDate.add(const Duration(days: 7));
        
        expenses = await _expenseService.getExpensesByDateRange(startOfWeekDate, endOfWeekDate);
        total = await _expenseService.getTotalExpensesByDateRange(startOfWeekDate, endOfWeekDate);
      } else if (_selectedFilter == 'Tháng này') {
        // Calculate the start and end of the current month
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 1);
        
        expenses = await _expenseService.getExpensesByDateRange(startOfMonth, endOfMonth);
        total = await _expenseService.getTotalExpensesByDateRange(startOfMonth, endOfMonth);
      }

      if (!mounted) return;

      setState(() {
        todayExpenses = expenses;
        totalExpensesToday = total;
      });
    } catch (e) {
      print('Error loading expenses: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading expenses: $e')));
    }
  }

  void _showAddExpenseDialog() {
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String selectedCategory = ExpenseService.defaultCategories[0];
    String selectedPaymentMethod = 'Tiền mặt';
    XFile? pickedReceipt;
    int step = 1; // 1 for amount/category, 2 for details
    bool showMoreDetails = false;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            if (step == 1) {
              // STEP 1: Amount
              return AlertDialog(
                title: const Text('Bước 1: Số Tiền'),
                contentPadding: const EdgeInsets.all(24.0),
                content: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Category Selection (First)
                        const Text(
                          'Chọn Danh Mục',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 5),
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: GridView.count(
                            crossAxisCount: 2,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 1.8,
                            children: ExpenseService.defaultCategories
                                .map((category) {
                              final isSelected =
                                  category == selectedCategory;
                              return Material(
                                child: InkWell(
                                  onTap: () {
                                    setStateDialog(() {
                                      selectedCategory = category;
                                    });
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: isSelected
                                            ? Colors.blue
                                            : Colors.grey[400]!,
                                        width: isSelected ? 3 : 2,
                                      ),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      color: isSelected
                                          ? Colors.blue
                                          : Colors.grey[200],
                                    ),
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(6.0),
                                        child: Text(
                                          category,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.black,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),

                        // Large Amount Input (Second)
                        const Text(
                          'Số Tiền (VND)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.blue, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TextField(
                            controller: amountController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: '0',
                              hintStyle: TextStyle(
                                fontSize: 32,
                                color: Colors.grey[400],
                              ),
                              suffixText: 'đ',
                              suffixStyle: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Hủy', style: TextStyle(fontSize: 16)),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final amountText = amountController.text.trim();
                      if (amountText.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Vui lòng nhập số tiền'),
                          ),
                        );
                        return;
                      }

                      final amount = int.tryParse(amountText);
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Vui lòng nhập số tiền hợp lệ'),
                          ),
                        );
                        return;
                      }

                      setStateDialog(() {
                        step = 2;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Tiếp Tục', style: TextStyle(fontSize: 16)),
                  ),
                ],
              );
            } else {
              // STEP 2: Optional Details
              return AlertDialog(
                title: const Text('Bước 2: Chi Tiết (Tùy Chọn)', style: TextStyle(fontSize: 18)),
                contentPadding: const EdgeInsets.all(24.0),
                content: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Description (Main field - always visible)
                        const Text(
                          'Mô Tả Ngắn Gọn',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: descriptionController,
                          style: const TextStyle(fontSize: 16),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            hintText: 'Nhập mô tả chi tiêu',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // More Details Toggle Button
                        Material(
                          child: InkWell(
                            onTap: () {
                              setStateDialog(() {
                                showMoreDetails = !showMoreDetails;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(context).brightness == Brightness.dark
                                      ? Colors.grey[700]!
                                      : Colors.grey[400]!,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[800]
                                    : Colors.grey[100],
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Chi tiết thêm',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Theme.of(context).brightness == Brightness.dark
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                  Icon(
                                    showMoreDetails
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    color: Theme.of(context).brightness == Brightness.dark
                                        ? Colors.grey[400]
                                        : Colors.grey[700],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Collapsible More Details Section
                        if (showMoreDetails) ...[
                          const SizedBox(height: 16),

                          // Payment Method
                          const Text(
                            'Phương Thức Thanh Toán',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: selectedPaymentMethod,
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            items: ['Tiền mặt', 'Chuyển khoản', 'Thẻ']
                                .map(
                                  (method) => DropdownMenuItem(
                                    value: method,
                                    child: Text(method),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setStateDialog(() {
                                  selectedPaymentMethod = value;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 16),

                          // Note
                          const Text(
                            'Ghi Chú',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: noteController,
                            maxLines: 2,
                            style: const TextStyle(fontSize: 14),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              hintText: 'Ghi chú thêm (tùy chọn)',
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Receipt Image Picker
                          const Text(
                            'Ảnh Hóa Đơn',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.receipt_long),
                            label: const Text('Chọn Ảnh Hóa Đơn'),
                            onPressed: () async {
                              // Check if permission is already granted
                              bool hasPermission =
                                  await PermissionService.isPhotoLibraryPermissionGranted();

                              // If not granted, request permission
                              if (!hasPermission) {
                                hasPermission =
                                    await PermissionService.requestPhotoLibraryPermission();

                                // If still not granted after request, user denied it
                                if (!hasPermission) {
                                  if (mounted) {
                                    showDialog(
                                      context: dialogContext,
                                      builder: (BuildContext ctx) {
                                        return AlertDialog(
                                          title: const Text(
                                            'Permission Required',
                                          ),
                                          content: const Text(
                                            'This app needs access to your photos to select receipt images. '
                                            'Please grant permission in settings.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () async {
                                                Navigator.pop(ctx);
                                                await PermissionService
                                                    .openSettings();
                                              },
                                              child: const Text(
                                                'Open Settings',
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  }
                                  return;
                                }
                              }

                              // Permission granted - open image picker
                              final ImagePicker picker = ImagePicker();
                              final XFile? image = await picker.pickImage(
                                source: ImageSource.gallery,
                              );
                              if (image != null) {
                                setStateDialog(() {
                                  pickedReceipt = image;
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[400],
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                          if (pickedReceipt != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12.0),
                              child: Stack(
                                children: [
                                  Image.file(
                                    File(pickedReceipt!.path),
                                    height: 150,
                                    fit: BoxFit.cover,
                                  ),
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        color: Colors.red,
                                      ),
                                      onPressed: () {
                                        setStateDialog(() {
                                          pickedReceipt = null;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      setStateDialog(() {
                        step = 1;
                      });
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Quay Lại', style: TextStyle(fontSize: 16)),
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      final amountText = amountController.text.trim();
                      final description = descriptionController.text.trim();
                      final note = noteController.text.trim();

                      final amount = int.tryParse(amountText);
                      if (amount == null || amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Số tiền không hợp lệ'),
                          ),
                        );
                        return;
                      }

                      // Add expense to database
                      final success = await _expenseService.addExpense(
                        category: selectedCategory,
                        description: description.isEmpty
                            ? selectedCategory
                            : description,
                        amount: amount,
                        receiptImagePath: pickedReceipt?.path,
                        note: note.isEmpty ? null : note,
                        paymentMethod: selectedPaymentMethod,
                      );

                      if (success) {
                        await _loadExpenses();

                        if (!mounted) return;

                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Chi tiêu đã được thêm',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: Colors.red,
                            content: Text('Lỗi khi thêm chi tiêu'),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 12,
                      ),
                    ),
                    child: const Text('Lưu', style: TextStyle(fontSize: 16)),
                  ),
                ],
              );
            }
          },
        );
      },
    );
  }

  void _showExpenseDetails(Expense expense, int index) {
    final timeString =
        '${expense.timestamp.hour.toString().padLeft(2, '0')}:${expense.timestamp.minute.toString().padLeft(2, '0')}:${expense.timestamp.second.toString().padLeft(2, '0')}';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Chi Tiết Chi Tiêu'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('STT:', '${index + 1}'),
                const SizedBox(height: 8),
                _buildDetailRow('Danh mục:', expense.category),
                const SizedBox(height: 8),
                _buildDetailRow('Mô tả:', expense.description),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Số tiền:',
                  '${expense.amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} VND',
                  valueColor: Colors.red,
                  valueWeight: FontWeight.bold,
                ),
                const SizedBox(height: 8),
                _buildDetailRow('Thanh toán:', expense.paymentMethod),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Thời gian:',
                  '$timeString - ${expense.timestamp.day}/${expense.timestamp.month}/${expense.timestamp.year}',
                ),
                if (expense.note != null && expense.note!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildDetailRow('Ghi chú:', expense.note!),
                ],
                if (expense.receiptImagePath != null) ...[
                  const SizedBox(height: 16),
                  const Text(
                    'Hóa đơn:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Image.file(File(expense.receiptImagePath!), height: 200),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    Color? valueColor,
    FontWeight? valueWeight,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: valueColor, fontWeight: valueWeight),
          ),
        ),
      ],
    );
  }

  void _deleteExpense(Expense expense) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Xác nhận xóa'),
          content: Text('Bạn có chắc chắn muốn xóa chi tiêu này?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      final success = await _expenseService.deleteExpense(expense.id);
      if (success) {
        await _loadExpenses();

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã xóa chi tiêu'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<Map<String, int>> _getExpensesByCategoryForFilter() async {
    try {
      late List<Expense> expenses;
      final now = DateTime.now();
      
      if (_selectedFilter == 'Hôm nay') {
        expenses = await _expenseService.getTodayExpenses();
      } else if (_selectedFilter == 'Tuần này') {
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final startOfWeekDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        final endOfWeekDate = startOfWeekDate.add(const Duration(days: 7));
        expenses = await _expenseService.getExpensesByDateRange(startOfWeekDate, endOfWeekDate);
      } else if (_selectedFilter == 'Tháng này') {
        final startOfMonth = DateTime(now.year, now.month, 1);
        final endOfMonth = DateTime(now.year, now.month + 1, 1);
        expenses = await _expenseService.getExpensesByDateRange(startOfMonth, endOfMonth);
      }
      
      final Map<String, int> categoryTotals = {};
      for (var expense in expenses) {
        categoryTotals[expense.category] =
            (categoryTotals[expense.category] ?? 0) + expense.amount;
      }
      
      return categoryTotals;
    } catch (e) {
      print('Error getting expenses by category for filter: $e');
      return {};
    }
  }

  @override
  void dispose() {
    _expenseListScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Main Content
          Column(
            children: [
              // Header with Summary Card
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.blue, Colors.redAccent.shade700],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Tổng Chi Tiêu - $_selectedFilter',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        DropdownButton<String>(
                          value: _selectedFilter,
                          dropdownColor: Colors.grey[800],
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          underline: Container(height: 2, color: Colors.white),
                          items: ['Hôm nay', 'Tuần này', 'Tháng này']
                              .map(
                                (filter) => DropdownMenuItem(
                                  value: filter,
                                  child: Text(filter),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedFilter = value;
                              });
                              _loadExpenses();
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Card(
                      color: Colors.white,
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Tổng Chi',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.blueGrey,
                                  ),
                                ),
                                Text(
                                  '${totalExpensesToday.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} VND',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Quick Add Button
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showAddExpenseDialog,
                    icon: const Icon(Icons.add, size: 28),
                    label: const Text(
                      'Thêm Chi Tiêu',
                      style: TextStyle(fontSize: 18),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade400,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),

              // Category Summary Cards
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Danh Mục Chi Tiêu - $_selectedFilter',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 80,
                      child: FutureBuilder<Map<String, int>>(
                        future: _getExpensesByCategoryForFilter(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                            final categories = snapshot.data!;
                            return ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: categories.length,
                              itemBuilder: (context, index) {
                                final category = categories.keys.elementAt(
                                  index,
                                );
                                final amount = categories[category]!;
                                return Card(
                                  margin: const EdgeInsets.only(right: 12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          category,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} đ',
                                          style: const TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          }
                          return const Center(
                            child: Text('Chưa có chi tiêu nào'),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Spacer to push expense list indicator to bottom
              const Expanded(child: SizedBox()),
            ],
          ),

          // Expense List Section - Fixed at bottom (when expanded)
          if (todayExpenses.isNotEmpty && _showExpensesList)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.red[50],
                padding: const EdgeInsets.all(8),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Chi tiêu $_selectedFilter',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _showExpensesList = false;
                              });
                            },
                            icon: const Icon(Icons.visibility_off, size: 16),
                            label: const Text('Ẩn'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              textStyle: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: RawScrollbar(
                        controller: _expenseListScrollController,
                        thickness: 10,
                        thumbColor: Colors.black54,
                        radius: const Radius.circular(4),
                        thumbVisibility: true,
                        child: ListView.builder(
                          controller: _expenseListScrollController,
                          itemCount: todayExpenses.length,
                          itemBuilder: (context, index) {
                            final expense = todayExpenses[index];
                            final timeString =
                                '${expense.timestamp.hour.toString().padLeft(2, '0')}:${expense.timestamp.minute.toString().padLeft(2, '0')}';
                            return InkWell(
                              onTap: () => _showExpenseDetails(expense, index),
                              child: Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 1,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 1,
                                  ),
                                  child: Row(
                                    children: [
                                      // Index number
                                      Container(
                                        width: 30,
                                        alignment: Alignment.center,
                                        child: Text(
                                          '${index + 1}.',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              expense.description,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Row(
                                              children: [
                                                Text(
                                                  expense.category,
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  '${expense.amount.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} đ',
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.red,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Text(
                                                  timeString,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () =>
                                            _deleteExpense(expense),
                                        icon: const Icon(
                                          Icons.close,
                                          size: 20,
                                          color: Colors.red,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 25,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Show Button for Expense List (when hidden and items exist)
          if (todayExpenses.isNotEmpty && !_showExpensesList)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF2A2A2A)
                    : Colors.red[50],
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Chi tiêu $_selectedFilter: ${todayExpenses.length} mục',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showExpensesList = true;
                        });
                      },
                      icon: const Icon(Icons.visibility, size: 16),
                      label: const Text('Hiển thị'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
