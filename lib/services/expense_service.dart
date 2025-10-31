import '../database/database_helper.dart';
import '../models/expense_model.dart';

class ExpenseService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // Common expense categories for quick selection
  static const List<String> defaultCategories = [
    'Tiền thuê',
    'Điện nước',
    'Nhập hàng',
    'Lương nhân viên',
    'Vận chuyển',
    'Marketing',
    'Bảo trì',
    'Văn phòng phẩm',
    'Ăn uống',
    'Khác',
  ];

  /// Add a new expense
  Future<bool> addExpense({
    required String category,
    required String description,
    required int amount,
    String? receiptImagePath,
    String? note,
    String paymentMethod = 'Tiền mặt',
  }) async {
    try {
      final expense = Expense(
        id: 0, // Auto-generate ID
        category: category,
        description: description,
        amount: amount,
        timestamp: DateTime.now(),
        receiptImagePath: receiptImagePath,
        note: note,
        paymentMethod: paymentMethod,
      );

      final id = await _dbHelper.insertExpense(expense);
      return id > 0;
    } catch (e) {
      print('Error adding expense: $e');
      return false;
    }
  }

  /// Get all expenses (ordered by timestamp, newest first)
  Future<List<Expense>> getAllExpenses() async {
    try {
      return await _dbHelper.getAllExpenses();
    } catch (e) {
      print('Error getting all expenses: $e');
      return [];
    }
  }

  /// Get today's expenses
  Future<List<Expense>> getTodayExpenses() async {
    try {
      return await _dbHelper.getExpensesForToday();
    } catch (e) {
      print('Error getting today expenses: $e');
      return [];
    }
  }

  /// Get expenses by date range
  Future<List<Expense>> getExpensesByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    try {
      return await _dbHelper.getExpensesByDateRange(start, end);
    } catch (e) {
      print('Error getting expenses by date range: $e');
      return [];
    }
  }

  /// Get expenses by category
  Future<List<Expense>> getExpensesByCategory(String category) async {
    try {
      return await _dbHelper.getExpensesByCategory(category);
    } catch (e) {
      print('Error getting expenses by category: $e');
      return [];
    }
  }

  /// Delete an expense
  Future<bool> deleteExpense(int id) async {
    try {
      final result = await _dbHelper.deleteExpense(id);
      return result > 0;
    } catch (e) {
      print('Error deleting expense: $e');
      return false;
    }
  }

  /// Get total expenses for today
  Future<int> getTotalExpensesToday() async {
    try {
      return await _dbHelper.getTotalExpensesToday();
    } catch (e) {
      print('Error getting total expenses today: $e');
      return 0;
    }
  }

  /// Get total expenses for date range
  Future<int> getTotalExpensesByDateRange(DateTime start, DateTime end) async {
    try {
      return await _dbHelper.getTotalExpensesByDateRange(start, end);
    } catch (e) {
      print('Error getting total expenses by date range: $e');
      return 0;
    }
  }

  /// Get expenses grouped by category for today
  Future<Map<String, int>> getExpensesByCategoryToday() async {
    try {
      final expenses = await getTodayExpenses();
      final Map<String, int> categoryTotals = {};

      for (var expense in expenses) {
        categoryTotals[expense.category] =
            (categoryTotals[expense.category] ?? 0) + expense.amount;
      }

      return categoryTotals;
    } catch (e) {
      print('Error getting expenses by category today: $e');
      return {};
    }
  }
}
