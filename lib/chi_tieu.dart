import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'models/expense_model.dart';
import 'models/recurring_expense_model.dart';
import 'services/expense_service.dart';
import 'services/permission_service.dart';
import 'services/recurring_expense_service.dart';
import 'services/currency_service.dart';
import 'services/statistics_cache_service.dart';

class DateRange {
  final DateTime start;
  final DateTime end;
  DateRange({required this.start, required this.end});
}

class ExpensesPage extends StatefulWidget {
  final ExpenseService? expenseService;
  final RecurringExpenseService? recurringExpenseService;

  const ExpensesPage({
    super.key,
    this.expenseService,
    this.recurringExpenseService,
  });

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  late final ExpenseService _expenseService;
  late final RecurringExpenseService _recurringExpenseService;
  final ScrollController _expenseListScrollController = ScrollController();

  List<Expense> todayExpenses = [];
  int totalExpensesToday = 0;
  String _selectedFilter = 'Hôm nay';
  DateTime? _selectedDate;
  Map<String, bool> expandedCategories = {};
  List<RecurringExpense> recurringExpenses = [];

  @override
  void initState() {
    super.initState();
    // Use injected services or create defaults
    _expenseService = widget.expenseService ?? ExpenseService();
    _recurringExpenseService = widget.recurringExpenseService ?? RecurringExpenseService();
    _loadExpenses();
  }

  String _getFrequencyLabel(String frequency) {
    return frequency == 'DAILY'
        ? 'Hàng ngày'
        : frequency == 'WEEKLY'
            ? 'Hàng tuần'
            : frequency == 'MONTHLY'
                ? 'Hàng tháng'
                : 'Hàng năm';
  }

  DateRange _getDateRangeForFilter() {
    final now = DateTime.now();
    if (_selectedFilter == 'Hôm nay') {
      return DateRange(
        start: DateTime(now.year, now.month, now.day),
        end: DateTime(now.year, now.month, now.day, 23, 59, 59),
      );
    } else if (_selectedFilter == 'Tuần này') {
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final startOfWeekDate = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      return DateRange(
        start: startOfWeekDate,
        end: startOfWeekDate.add(const Duration(days: 7)),
      );
    } else if (_selectedFilter == 'Tháng này') {
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 1);
      return DateRange(start: startOfMonth, end: endOfMonth);
    } else if (_selectedFilter == 'Chọn ngày' && _selectedDate != null) {
      final startDate = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
      return DateRange(
        start: startDate,
        end: startDate.add(const Duration(days: 1)),
      );
    }
    return DateRange(
      start: DateTime(now.year, now.month, now.day),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  Future<void> _loadExpenses() async {
    try {
      // Auto-generate recurring expenses first
      await _recurringExpenseService.generateDueRecurringExpenses();
      
      late List<Expense> expenses;
      late int total;

      if (_selectedFilter == 'Hôm nay') {
        expenses = await _expenseService.getTodayExpenses();
        total = await _expenseService.getTotalExpensesToday();
      } else {
        final dateRange = _getDateRangeForFilter();
        expenses = await _expenseService.getExpensesByDateRange(dateRange.start, dateRange.end);
        total = await _expenseService.getTotalExpensesByDateRange(dateRange.start, dateRange.end);
      }

      // Load all recurring expenses (active and inactive)
      final recurring = await _recurringExpenseService.getAllRecurringExpenses();

      if (!mounted) return;

      setState(() {
        todayExpenses = expenses;
        totalExpensesToday = total;
        recurringExpenses = recurring;
      });
    } catch (e) {
      print('Error loading expenses: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading expenses: $e')));
    }
  }

  String _getFilterDisplayText() {
    if (_selectedFilter == 'Chọn ngày' && _selectedDate != null) {
      return '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}';
    }
    return _selectedFilter;
  }

  void _showAddExpenseDialog() {
    final descriptionController = TextEditingController();
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String selectedCategory = ExpenseService.defaultCategories[0];
    String selectedPaymentMethod = 'Tiền mặt';
    DateTime selectedExpenseDate = DateTime.now();
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

                          // Date Picker
                          const Text(
                            'Ngày Chi Tiêu',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () async {
                              final pickedDate = await showDatePicker(
                                context: context,
                                initialDate: selectedExpenseDate,
                                firstDate: DateTime(DateTime.now().year - 2),
                                lastDate: DateTime.now(),
                              );
                              if (pickedDate != null) {
                                setStateDialog(() {
                                  selectedExpenseDate = pickedDate;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.grey[400]!,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '${selectedExpenseDate.day}/${selectedExpenseDate.month}/${selectedExpenseDate.year}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Icon(Icons.calendar_today, size: 20),
                                ],
                              ),
                            ),
                          ),
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
                            initialValue: selectedPaymentMethod,
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
                        expenseDate: selectedExpenseDate,
                      );

                      if (success) {
                        // Invalidate statistics cache when an expense is added
                        StatisticsCacheService.invalidateCache();

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

    Future<Map<String, int>> _getExpensesByCategoryForFilter() async {
    try {
      late List<Expense> expenses;
      
      if (_selectedFilter == 'Hôm nay') {
        expenses = await _expenseService.getTodayExpenses();
      } else {
        final dateRange = _getDateRangeForFilter();
        expenses = await _expenseService.getExpensesByDateRange(dateRange.start, dateRange.end);
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

  Future<List<Expense>> _getExpensesByCategoryDetailed(String category) async {
    try {
      late List<Expense> expenses;
      
      if (_selectedFilter == 'Hôm nay') {
        expenses = await _expenseService.getTodayExpenses();
      } else {
        final dateRange = _getDateRangeForFilter();
        expenses = await _expenseService.getExpensesByDateRange(dateRange.start, dateRange.end);
      }
      
      // Filter by category and sort by newest first
      final categoryExpenses = expenses
          .where((expense) => expense.category == category)
          .toList();
      categoryExpenses.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      
      return categoryExpenses;
    } catch (e) {
      print('Error getting expenses by category detailed: $e');
      return [];
    }
  }

  void _showExpenseDetailsDialog(Expense expense) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            expense.category,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          contentPadding: const EdgeInsets.all(24.0),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description
                const Text(
                  'Mô Tả',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  expense.description,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),

                // Amount
                const Text(
                  'Số Tiền',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  CurrencyService.formatCurrency(expense.amount),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 16),

                // Date & Time
                const Text(
                  'Thời Gian',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${expense.timestamp.day}/${expense.timestamp.month}/${expense.timestamp.year} lúc ${expense.timestamp.hour.toString().padLeft(2, '0')}:${expense.timestamp.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),

                // Payment Method
                const Text(
                  'Phương Thức Thanh Toán',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    expense.paymentMethod,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Note (if exists)
                if (expense.note != null && expense.note!.isNotEmpty) ...[
                  const Text(
                    'Ghi Chú',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Text(
                      expense.note!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Receipt Image (if exists)
                if (expense.receiptImagePath != null &&
                    expense.receiptImagePath!.isNotEmpty) ...[
                  const Text(
                    'Ảnh Hóa Đơn',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 200,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(expense.receiptImagePath!),
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[300],
                            child: const Center(
                              child: Text('Không thể tải ảnh'),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () async {
                // Show confirmation dialog
                showDialog(
                  context: context,
                  builder: (BuildContext confirmContext) {
                    return AlertDialog(
                      title: const Text('Xóa Chi Tiêu'),
                      content: Text('Bạn có chắc muốn xóa chi tiêu "${expense.description}"?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(confirmContext),
                          child: const Text('Hủy'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            try {
                              await _expenseService.deleteExpense(expense.id);
                              await _loadExpenses();
                              
                              if (!mounted) return;
                              
                              Navigator.pop(confirmContext); // Close confirmation dialog
                              Navigator.pop(dialogContext); // Close details dialog
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Chi tiêu đã được xóa'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } catch (e) {
                              if (!mounted) return;
                              Navigator.pop(confirmContext);
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Lỗi khi xóa: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('Xóa'),
                        ),
                      ],
                    );
                  },
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Xóa'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey[800]
                    : Colors.grey[300],
                foregroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }

  void _showAddRecurringExpenseDialog({RecurringExpense? existingRecurring}) {
    final descriptionController = TextEditingController(text: existingRecurring?.description ?? '');
    final amountController = TextEditingController(text: existingRecurring?.amount.toString() ?? '');
    final noteController = TextEditingController(text: existingRecurring?.note ?? '');
    String selectedCategory = existingRecurring?.category ?? ExpenseService.defaultCategories[0];
    String selectedPaymentMethod = existingRecurring?.paymentMethod ?? 'Tiền mặt';
    String selectedFrequency = existingRecurring?.frequency ?? 'MONTHLY';
    DateTime startDate = existingRecurring?.startDate ?? DateTime.now();
    DateTime? endDate = existingRecurring?.endDate;
    bool hasEndDate = endDate != null;
    bool isActive = existingRecurring?.isActive ?? true;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(
                existingRecurring != null ? 'Chỉnh sửa Chi Phí Cố Định' : 'Thêm Chi Phí Cố Định',
                style: const TextStyle(fontSize: 18),
              ),
              contentPadding: const EdgeInsets.all(24.0),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category
                      const Text(
                        'Danh Mục',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: selectedCategory,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        items: ExpenseService.defaultCategories.map((category) {
                          return DropdownMenuItem(value: category, child: Text(category));
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setStateDialog(() => selectedCategory = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Active Status Toggle - only show for existing recurring expenses
                      if (existingRecurring != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Trạng Thái',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Switch(
                              value: isActive,
                              onChanged: (value) {
                                setStateDialog(() => isActive = value);
                              },
                              activeThumbColor: Colors.green,
                            ),
                          ],
                        ),
                      if (existingRecurring != null)
                        const SizedBox(height: 16),

                      // Amount
                      const Text(
                        'Số Tiền (VND)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blue, width: 2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: '0',
                            hintStyle: TextStyle(fontSize: 24, color: Colors.grey[400]),
                            suffixText: 'đ',
                            suffixStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Description
                      const Text(
                        'Mô Tả',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: descriptionController,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          hintText: 'Nhập mô tả chi phí cố định',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Frequency
                      const Text(
                        'Tần Suất',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: selectedFrequency,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        items: ['DAILY', 'WEEKLY', 'MONTHLY', 'YEARLY'].map((freq) {
                          final label = freq == 'DAILY'
                              ? 'Hàng ngày'
                              : freq == 'WEEKLY'
                                  ? 'Hàng tuần'
                                  : freq == 'MONTHLY'
                                      ? 'Hàng tháng'
                                      : 'Hàng năm';
                          return DropdownMenuItem(value: freq, child: Text(label));
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setStateDialog(() => selectedFrequency = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Start Date
                      const Text(
                        'Ngày Bắt Đầu',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: startDate,
                            firstDate: DateTime(DateTime.now().year - 1),
                            lastDate: DateTime(DateTime.now().year + 2),
                          );
                          if (pickedDate != null) {
                            setStateDialog(() => startDate = pickedDate);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[400]!, width: 1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${startDate.day}/${startDate.month}/${startDate.year}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                              ),
                              const Icon(Icons.calendar_today, size: 20),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // End Date Checkbox
                      Row(
                        children: [
                          Checkbox(
                            value: hasEndDate,
                            onChanged: (value) {
                              setStateDialog(() {
                                hasEndDate = value ?? false;
                                if (!hasEndDate) endDate = null;
                              });
                            },
                          ),
                          const Text('Có ngày kết thúc', style: TextStyle(fontSize: 14)),
                        ],
                      ),

                      // End Date (if enabled)
                      if (hasEndDate) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () async {
                            final pickedDate = await showDatePicker(
                              context: context,
                              initialDate: endDate ?? startDate.add(const Duration(days: 365)),
                              firstDate: startDate,
                              lastDate: DateTime(DateTime.now().year + 5),
                            );
                            if (pickedDate != null) {
                              setStateDialog(() => endDate = pickedDate);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey[400]!, width: 1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  endDate != null ? '${endDate!.day}/${endDate!.month}/${endDate!.year}' : 'Chọn ngày',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                ),
                                const Icon(Icons.calendar_today, size: 20),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Payment Method
                      const Text(
                        'Phương Thức Thanh Toán',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: selectedPaymentMethod,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        items: ['Tiền mặt', 'Chuyển khoản', 'Thẻ']
                            .map((method) => DropdownMenuItem(value: method, child: Text(method)))
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setStateDialog(() => selectedPaymentMethod = value);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Notes
                      const Text(
                        'Ghi Chú',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: noteController,
                        maxLines: 2,
                        style: const TextStyle(fontSize: 14),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          hintText: 'Ghi chú thêm (tùy chọn)',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                Row(
                  children: [
                    // Delete button - only show for existing recurring expenses
                    if (existingRecurring != null)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          Navigator.pop(context);
                          showDialog(
                            context: context,
                            builder: (context) {
                              return AlertDialog(
                                title: const Text('Xác nhận xóa'),
                                content: const Text('Bạn có chắc chắn muốn xóa chi phí cố định này?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Hủy'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () async {
                                      try {
                                        await _recurringExpenseService.deleteRecurringExpense(existingRecurring.id);
                                        await _loadExpenses();
                                        
                                        if (!mounted) return;
                                        Navigator.pop(context);
                                        
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Chi phí cố định đã được xóa'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            backgroundColor: Colors.red,
                                            content: Text('Lỗi: $e'),
                                          ),
                                        );
                                      }
                                    },
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
                        },
                      )
                    else
                      const SizedBox(width: 48), // Spacer to maintain alignment
                    const Spacer(),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Hủy', style: TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final amountText = amountController.text.trim();
                        final description = descriptionController.text.trim();
                        final note = noteController.text.trim();

                        if (amountText.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Vui lòng nhập số tiền')),
                          );
                          return;
                        }

                        final amount = int.tryParse(amountText);
                        if (amount == null || amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ')),
                          );
                          return;
                        }

                        try {
                          if (existingRecurring != null) {
                            // Update existing - include isActive status
                            final updated = existingRecurring.copyWith(
                              description: description.isEmpty ? existingRecurring.category : description,
                              amount: amount,
                              frequency: selectedFrequency,
                              startDate: startDate,
                              endDate: endDate,
                              paymentMethod: selectedPaymentMethod,
                              note: note.isEmpty ? null : note,
                              isActive: isActive,
                            );
                            await _recurringExpenseService.updateRecurringExpense(updated);
                          } else {
                            // Create new
                            await _recurringExpenseService.addRecurringExpense(
                              category: selectedCategory,
                              description: description.isEmpty ? selectedCategory : description,
                              amount: amount,
                              frequency: selectedFrequency,
                              startDate: startDate,
                              endDate: endDate,
                              paymentMethod: selectedPaymentMethod,
                              note: note.isEmpty ? null : note,
                            );
                          }

                          await _loadExpenses();

                          if (!mounted) return;

                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(existingRecurring != null ? 'Chi phí cố định đã được cập nhật' : 'Chi phí cố định đã được thêm'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              backgroundColor: Colors.red,
                              content: Text('Lỗi: $e'),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      child: const Text('Lưu', style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
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
          // Main Content - Scrollable
          SingleChildScrollView(
            controller: _expenseListScrollController,
            child: Column(
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
                          Expanded(
                            child: Text(
                              'Tổng Chi Tiêu - ${_getFilterDisplayText()}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<String>(
                            value: _selectedFilter,
                            dropdownColor: Colors.grey[800],
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                            underline: Container(height: 2, color: Colors.white),
                            items: ['Hôm nay', 'Tuần này', 'Tháng này', 'Chọn ngày']
                                .map(
                                  (filter) => DropdownMenuItem(
                                    value: filter,
                                    child: Text(filter),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) async {
                              if (value != null) {
                                if (value == 'Chọn ngày') {
                                  // Show date picker
                                  final pickedDate = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedDate ?? DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now(),
                                  );
                                  if (pickedDate != null) {
                                    setState(() {
                                      _selectedFilter = value;
                                      _selectedDate = pickedDate;
                                    });
                                    _loadExpenses();
                                  }
                                } else {
                                  setState(() {
                                    _selectedFilter = value;
                                    _selectedDate = null;
                                  });
                                  _loadExpenses();
                                }
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Card(
                        color: Colors.grey[50],
                        elevation: 2,
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
                                    CurrencyService.formatCurrency(totalExpensesToday),
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

                // Quick Add Buttons
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _showAddRecurringExpenseDialog,
                          icon: const Icon(Icons.repeat, size: 28),
                          label: const Text(
                            'Chi Phí Cố Định',
                            style: TextStyle(fontSize: 18),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade400,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Recurring Expenses Section (all expenses)
                if (recurringExpenses.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chi Phí Cố Định',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 160,
                          child: RepaintBoundary(
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: recurringExpenses.length,
                            itemBuilder: (context, index) {
                              final recurring = recurringExpenses[index];
                              final nextOccurrence = _recurringExpenseService.getNextOccurrenceDate(recurring);
                              return Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: GestureDetector(
                                  onTap: () {
                                    _showAddRecurringExpenseDialog(existingRecurring: recurring);
                                  },
                                  child: Card(
                                    elevation: 2,
                                    child: Container(
                                      width: 280,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        gradient: LinearGradient(
                                          colors: recurring.isActive ?
                                            [Colors.blueAccent, Colors.orangeAccent] :
                                            [Colors.blueAccent, Colors.black54],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                      ),
                                      child: Stack(
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Amount
                                              Text(
                                                CurrencyService.formatCurrency(recurring.amount),
                                                style: const TextStyle(
                                                  color: Color.fromARGB(255, 160, 0, 0),
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 20,
                                                ),
                                              ),
                                              const SizedBox(height: 1),
                                              // Title
                                              Text(
                                                recurring.description,
                                                style: TextStyle(
                                                  color: Colors.amberAccent.shade100,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 17,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              // Category and frequency
                                              Text(
                                                _getFrequencyLabel(recurring.frequency),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 2),
                                              // Next occurrence
                                              Text(
                                                'Ngày thanh toán tiếp theo: ${nextOccurrence.day}/${nextOccurrence.month}/${nextOccurrence.year}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              // Status
                                              Row(
                                                children: [
                                                  Icon(
                                                    recurring.isActive ? Icons.check_circle : Icons.cancel,
                                                    color: recurring.isActive ? Colors.greenAccent : Colors.redAccent,
                                                    size: 14,
                                                  ),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    recurring.isActive ? 'Đang hoạt động' : 'Đã tắt',
                                                    style: TextStyle(
                                                      color: Colors.amberAccent.shade100,
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          // Toggle button on top right
                                          Positioned(
                                            top: 0,
                                            right: 0,
                                            child: GestureDetector(
                                              onTap: () async {
                                                final updated = recurring.copyWith(
                                                  isActive: !recurring.isActive,
                                                );
                                                await _recurringExpenseService.updateRecurringExpense(updated);
                                                _loadExpenses();
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(1),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.white.withValues(alpha: 0.15),
                                                ),
                                                child: Icon(
                                                  recurring.isActive ? Icons.power_settings_new : Icons.power_settings_new,
                                                  color: recurring.isActive ? Colors.greenAccent : Colors.redAccent,
                                                  size: 28,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),

                // Category Summary List (Sorted by highest to lowest)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Danh Mục Chi Tiêu - ${_getFilterDisplayText()}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FutureBuilder<Map<String, int>>(
                        future: _getExpensesByCategoryForFilter(),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                            final categories = snapshot.data!;
                            
                            // Sort categories by amount (highest to lowest)
                            final sortedEntries = categories.entries.toList()
                              ..sort((a, b) => b.value.compareTo(a.value));
                            
                            return RepaintBoundary(
                              child: ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: sortedEntries.length,
                              itemBuilder: (context, index) {
                                final category = sortedEntries[index].key;
                                final amount = sortedEntries[index].value;
                                final isExpanded = expandedCategories[category] ?? false;
                                
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Card(
                                    elevation: 0,
                                    color: isExpanded
                                        ? (Theme.of(context).brightness == Brightness.dark
                                            ? Colors.grey[700]
                                            : Colors.grey[200])
                                        : (Theme.of(context).brightness == Brightness.dark
                                            ? Colors.grey[850]
                                            : Colors.grey[50]),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(
                                        color: Theme.of(context).brightness == Brightness.dark
                                            ? Colors.grey[700]!
                                            : Colors.grey[300]!,
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      children: [
                                        // Main Category Row
                                        Material(
                                          borderRadius: BorderRadius.circular(8),
                                          color: Theme.of(context).brightness == Brightness.dark
                                            ? const Color.fromARGB(255, 61, 61, 61)
                                            : const Color.fromARGB(255, 255, 238, 193),
                                          child: InkWell(
                                            onTap: () {
                                              setState(() {
                                                expandedCategories[category] = !isExpanded;
                                              });
                                            },
                                            child: Padding(
                                              padding: const EdgeInsets.all(16),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          category,
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 16,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 4),
                                                        FutureBuilder<List<Expense>>(
                                                          future: _getExpensesByCategoryDetailed(category),
                                                          builder: (context, snapshot) {
                                                            if (snapshot.hasData) {
                                                              return Text(
                                                                '${snapshot.data!.length} giao dịch',
                                                                style: TextStyle(
                                                                  color: Theme.of(context).brightness == Brightness.dark
                                                                    ? Colors.white
                                                                    : Colors.black87,
                                                                  fontSize: 12,
                                                                ),
                                                              );
                                                            }
                                                            return const SizedBox.shrink();
                                                          },
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.end,
                                                    children: [
                                                      Text(
                                                        CurrencyService.formatCurrency(amount),
                                                        style: const TextStyle(
                                                          color: Colors.red,
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Icon(
                                                        isExpanded ? Icons.expand_less : Icons.expand_more,
                                                        color: Colors.black87,
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                        
                                        // Expanded Details Section
                                        if (isExpanded)
                                          FutureBuilder<List<Expense>>(
                                            future: _getExpensesByCategoryDetailed(category),
                                            builder: (context, snapshot) {
                                              if (snapshot.hasData) {
                                                final expenses = snapshot.data!;
                                                return Column(
                                                  children: [
                                                    Divider(
                                                      height: 1,
                                                      color: Theme.of(context).brightness == Brightness.dark
                                                          ? Colors.white54
                                                          : Colors.black54,
                                                    ),
                                                    ListView.builder(
                                                      shrinkWrap: true,
                                                      physics: const NeverScrollableScrollPhysics(),
                                                      itemCount: expenses.length,
                                                      itemBuilder: (context, expIndex) {
                                                        final expense = expenses[expIndex];
                                                        final date = expense.timestamp;
                                                        final dateStr = '${date.day}/${date.month}/${date.year}';
                                                        return Material(
                                                          color: Theme.of(context).brightness == Brightness.dark
                                                            ? const Color.fromARGB(255, 92, 85, 74)
                                                            : const Color.fromARGB(255, 243, 255, 200),
                                                          child: InkWell(
                                                            onTap: () => _showExpenseDetailsDialog(expense),
                                                            child: Container(
                                                              padding: const EdgeInsets.symmetric(
                                                                horizontal: 16,
                                                                vertical: 12,
                                                              ),
                                                              decoration: BoxDecoration(
                                                                border: Border(
                                                                  bottom: BorderSide(
                                                                    color: Colors.grey[300]!,
                                                                    width: 0.5,
                                                                  ),
                                                                ),
                                                              ),
                                                              child: Row(
                                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                                children: [
                                                                  Expanded(
                                                                    child: Column(
                                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                                      children: [
                                                                        // Description - Main content
                                                                        Text(
                                                                          expense.description,
                                                                          style: const TextStyle(
                                                                            fontWeight: FontWeight.w600,
                                                                            fontSize: 15,
                                                                          ),
                                                                          maxLines: 1,
                                                                          overflow: TextOverflow.ellipsis,
                                                                        ),
                                                                        const SizedBox(height: 8),
                                                                        // Date and payment method row
                                                                        SingleChildScrollView(
                                                                          scrollDirection: Axis.horizontal,
                                                                          child: Row(
                                                                            children: [
                                                                              // Date
                                                                              Text(
                                                                                dateStr,
                                                                                style: TextStyle(
                                                                                  fontSize: 13,
                                                                                  color: Colors.grey[600],
                                                                                  fontWeight: FontWeight.w400,
                                                                                ),
                                                                              ),
                                                                              const SizedBox(width: 8),
                                                                              // Divider
                                                                              Container(
                                                                                width: 1,
                                                                                height: 16,
                                                                                color: Colors.grey[400],
                                                                              ),
                                                                              const SizedBox(width: 8),
                                                                              // Payment method badge
                                                                              Container(
                                                                                padding: const EdgeInsets.symmetric(
                                                                                  horizontal: 8,
                                                                                  vertical: 4,
                                                                                ),
                                                                                decoration: BoxDecoration(
                                                                                  color: Colors.blue.withValues(alpha: 0.15),
                                                                                  borderRadius: BorderRadius.circular(6),
                                                                                ),
                                                                                child: Text(
                                                                                  expense.paymentMethod,
                                                                                  style: TextStyle(
                                                                                    fontSize: 11,
                                                                                    color: Theme.of(context).brightness == Brightness.dark
                                                                                      ? Colors.blue[200]
                                                                                      : Colors.blue[700],
                                                                                    fontWeight: FontWeight.w500,
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ],
                                                                        ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                  const SizedBox(width: 16),
                                                                  // Amount - Right aligned
                                                                  Column(
                                                                    crossAxisAlignment: CrossAxisAlignment.end,
                                                                    children: [
                                                                      Text(
                                                                        CurrencyService.formatCurrency(expense.amount),
                                                                        style: const TextStyle(
                                                                          color: Colors.red,
                                                                          fontWeight: FontWeight.bold,
                                                                          fontSize: 16,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                );
                                              }
                                              return const Padding(
                                                padding: EdgeInsets.all(12),
                                                child: CircularProgressIndicator(),
                                              );
                                            },
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              ),
                            );
                          }
                          return const Center(
                            child: Text('Chưa có chi tiêu nào'),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
