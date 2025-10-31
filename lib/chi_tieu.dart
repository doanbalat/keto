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
      final expenses = await _expenseService.getTodayExpenses();
      final total = await _expenseService.getTotalExpensesToday();

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

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Thêm Chi Tiêu'),
              contentPadding: const EdgeInsets.fromLTRB(24.0, 20.0, 24.0, 0.0),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category Dropdown
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        decoration: InputDecoration(
                          labelText: 'Danh Mục',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: ExpenseService.defaultCategories
                            .map(
                              (category) => DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setStateDialog(() {
                              selectedCategory = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextField(
                        controller: descriptionController,
                        decoration: InputDecoration(
                          labelText: 'Mô Tả',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          hintText: 'Nhập mô tả chi tiêu',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Amount
                      TextField(
                        controller: amountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Số Tiền (VND)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          hintText: 'Nhập số tiền',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Payment Method
                      DropdownButtonFormField<String>(
                        value: selectedPaymentMethod,
                        decoration: InputDecoration(
                          labelText: 'Phương Thức Thanh Toán',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
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
                      TextField(
                        controller: noteController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: 'Ghi Chú (Tùy Chọn)',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          hintText: 'Ghi chú thêm',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Receipt Image Picker
                      Column(
                        children: [
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
                                                await PermissionService.openSettings();
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
                          ),
                          if (pickedReceipt != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Stack(
                                children: [
                                  Image.file(
                                    File(pickedReceipt!.path),
                                    height: 100,
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
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Hủy'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final description = descriptionController.text.trim();
                    final amountText = amountController.text.trim();
                    final note = noteController.text.trim();

                    if (description.isEmpty || amountText.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Vui lòng điền đầy đủ thông tin'),
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

                    // Add expense to database
                    final success = await _expenseService.addExpense(
                      category: selectedCategory,
                      description: description,
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
                          content: Text('Chi tiêu "$description" đã được thêm'),
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
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.blue,
                  ),
                  child: const Text('Thêm'),
                ),
              ],
            );
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
                          'Tổng Chi Tiêu $_selectedFilter',
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
                              // TODO: Implement filter logic for week/month
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
                    const Text(
                      'Danh Mục Chi Tiêu',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 80,
                      child: FutureBuilder<Map<String, int>>(
                        future: _expenseService.getExpensesByCategoryToday(),
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
                          const Text(
                            'Chi tiêu hôm nay',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
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
                color: Colors.red[50],
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Chi tiêu hôm nay: ${todayExpenses.length} mục',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
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
