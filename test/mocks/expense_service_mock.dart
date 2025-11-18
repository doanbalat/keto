import 'package:keto/models/expense_model.dart';
import 'package:keto/services/expense_service.dart';

/// Mock ExpenseService for testing
class MockExpenseService extends ExpenseService {
  List<Expense> _expenses = [];
  bool throwError = false;
  String? errorMessage;

  /// Set mock expenses data
  void setExpenses(List<Expense> expenses) {
    _expenses = List.from(expenses);
  }

  /// Add a mock expense for testing
  void addMockExpense(Expense expense) {
    _expenses.add(expense);
  }

  /// Clear all expenses
  void clear() {
    _expenses.clear();
  }

  @override
  Future<List<Expense>> getAllExpenses() async {
    if (throwError) {
      throw Exception(errorMessage ?? 'Mock error');
    }
    return Future.value(List.from(_expenses));
  }

  @override
  Future<List<Expense>> getTodayExpenses() async {
    if (throwError) {
      throw Exception(errorMessage ?? 'Mock error');
    }
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);
    
    return Future.value(
      _expenses
          .where((e) => e.timestamp.isAfter(todayStart) && e.timestamp.isBefore(todayEnd))
          .toList(),
    );
  }

  @override
  Future<int> getTotalExpensesToday() async {
    if (throwError) {
      throw Exception(errorMessage ?? 'Mock error');
    }
    final expenses = await getTodayExpenses();
    return expenses.fold<int>(0, (sum, e) => sum + e.amount);
  }

  @override
  Future<List<Expense>> getExpensesByDateRange(DateTime start, DateTime end) async {
    if (throwError) {
      throw Exception(errorMessage ?? 'Mock error');
    }
    return Future.value(
      _expenses
          .where((e) => e.timestamp.isAfter(start) && e.timestamp.isBefore(end))
          .toList(),
    );
  }

  @override
  Future<int> getTotalExpensesByDateRange(DateTime start, DateTime end) async {
    if (throwError) {
      throw Exception(errorMessage ?? 'Mock error');
    }
    final expenses = await getExpensesByDateRange(start, end);
    return expenses.fold<int>(0, (sum, e) => sum + e.amount);
  }

  @override
  Future<bool> deleteExpense(int id) async {
    if (throwError) {
      throw Exception(errorMessage ?? 'Mock error');
    }
    final initialLength = _expenses.length;
    _expenses.removeWhere((e) => e.id == id);
    return _expenses.length < initialLength;
  }

  @override
  Future<List<Expense>> getExpensesByCategory(String category) async {
    if (throwError) {
      throw Exception(errorMessage ?? 'Mock error');
    }
    return Future.value(
      _expenses.where((e) => e.category == category).toList(),
    );
  }

  @override
  Future<Map<String, int>> getExpensesByCategoryToday() async {
    if (throwError) {
      throw Exception(errorMessage ?? 'Mock error');
    }
    final expenses = await getTodayExpenses();
    final Map<String, int> categoryTotals = {};

    for (var expense in expenses) {
      categoryTotals[expense.category] =
          (categoryTotals[expense.category] ?? 0) + expense.amount;
    }

    return categoryTotals;
  }

  @override
  Future<bool> addExpense({
    required String category,
    required String description,
    required int amount,
    String? receiptImagePath,
    String? note,
    String paymentMethod = 'Tiền mặt',
    DateTime? expenseDate,
  }) async {
    if (throwError) {
      throw Exception(errorMessage ?? 'Mock error');
    }
    final expense = Expense(
      id: _expenses.isEmpty ? 1 : _expenses.fold<int>(0, (max, e) => e.id > max ? e.id : max) + 1,
      category: category,
      description: description,
      amount: amount,
      timestamp: expenseDate ?? DateTime.now(),
      receiptImagePath: receiptImagePath,
      note: note,
      paymentMethod: paymentMethod,
    );
    _expenses.add(expense);
    return true;
  }
}
