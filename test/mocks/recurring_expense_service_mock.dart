import 'package:keto/models/recurring_expense_model.dart';
import 'package:keto/services/recurring_expense_service.dart';

/// Mock RecurringExpenseService for testing
class MockRecurringExpenseService extends RecurringExpenseService {
  List<RecurringExpense> _recurringExpenses = [];
  bool throwError = false;
  String? errorMessage;

  /// Set mock recurring expenses
  void setRecurringExpenses(List<RecurringExpense> expenses) {
    _recurringExpenses = List.from(expenses);
  }

  /// Add a mock recurring expense
  void addMockRecurringExpense(RecurringExpense expense) {
    _recurringExpenses.add(expense);
  }

  /// Clear all recurring expenses
  void clear() {
    _recurringExpenses.clear();
  }

  @override
  Future<List<RecurringExpense>> getActiveRecurringExpenses() async {
    if (throwError) {
      throw Exception(errorMessage ?? 'Mock error');
    }
    return Future.value(
      _recurringExpenses.where((e) => e.isActive).toList(),
    );
  }

  @override
  Future<List<RecurringExpense>> getAllRecurringExpenses() async {
    if (throwError) {
      throw Exception(errorMessage ?? 'Mock error');
    }
    return Future.value(List.from(_recurringExpenses));
  }

  @override
  Future<bool> addRecurringExpense({
    required String category,
    required String description,
    required int amount,
    required String frequency,
    required DateTime startDate,
    DateTime? endDate,
    required String paymentMethod,
    String? note,
  }) async {
    if (throwError) {
      throw Exception(errorMessage ?? 'Mock error');
    }
    final recurringExpense = RecurringExpense(
      id: _recurringExpenses.isEmpty ? 1 : _recurringExpenses.fold<int>(0, (max, e) => e.id > max ? e.id : max) + 1,
      category: category,
      description: description,
      amount: amount,
      frequency: frequency,
      startDate: startDate,
      endDate: endDate,
      paymentMethod: paymentMethod,
      note: note,
      isActive: true,
      createdAt: DateTime.now(),
      lastGeneratedDate: null,
    );
    _recurringExpenses.add(recurringExpense);
    return true;
  }

  @override
  Future<bool> updateRecurringExpense(RecurringExpense recurringExpense) async {
    if (throwError) {
      throw Exception(errorMessage ?? 'Mock error');
    }
    final index = _recurringExpenses.indexWhere((e) => e.id == recurringExpense.id);
    if (index != -1) {
      _recurringExpenses[index] = recurringExpense;
      return true;
    }
    return false;
  }

  @override
  Future<bool> toggleRecurringExpense(int id, bool isActive) async {
    if (throwError) {
      throw Exception(errorMessage ?? 'Mock error');
    }
    final index = _recurringExpenses.indexWhere((e) => e.id == id);
    if (index != -1) {
      _recurringExpenses[index] = _recurringExpenses[index].copyWith(isActive: isActive);
      return true;
    }
    return false;
  }

  @override
  Future<bool> deleteRecurringExpense(int id) async {
    if (throwError) {
      throw Exception(errorMessage ?? 'Mock error');
    }
    final initialLength = _recurringExpenses.length;
    _recurringExpenses.removeWhere((e) => e.id == id);
    return _recurringExpenses.length < initialLength;
  }

  @override
  Future<void> generateDueRecurringExpenses() async {
    if (throwError) {
      throw Exception(errorMessage ?? 'Mock error');
    }
    // Mock implementation: do nothing for testing
    // In real implementation, this would generate expenses from recurring items
    return Future.value();
  }
}
