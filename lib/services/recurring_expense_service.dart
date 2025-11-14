import 'package:keto/models/recurring_expense_model.dart';
import 'package:keto/database/database_helper.dart';
import 'expense_service.dart';

class RecurringExpenseService {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final ExpenseService _expenseService = ExpenseService();

  // Create a new recurring expense
  Future<bool> addRecurringExpense({
    required String category,
    required String description,
    required int amount,
    required String frequency, // DAILY, WEEKLY, MONTHLY, YEARLY
    required DateTime startDate,
    DateTime? endDate,
    required String paymentMethod,
    String? note,
  }) async {
    try {
      final recurringExpense = RecurringExpense(
        id: 0,
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

      final id = await _dbHelper.insertRecurringExpense(recurringExpense);
      return id > 0;
    } catch (e) {
      print('Error adding recurring expense: $e');
      return false;
    }
  }

  // Get all active recurring expenses
  Future<List<RecurringExpense>> getActiveRecurringExpenses() async {
    try {
      return await _dbHelper.getActiveRecurringExpenses();
    } catch (e) {
      print('Error getting active recurring expenses: $e');
      return [];
    }
  }

  // Get all recurring expenses (including inactive)
  Future<List<RecurringExpense>> getAllRecurringExpenses() async {
    try {
      return await _dbHelper.getAllRecurringExpenses();
    } catch (e) {
      print('Error getting all recurring expenses: $e');
      return [];
    }
  }

  // Update a recurring expense
  Future<bool> updateRecurringExpense(RecurringExpense recurringExpense) async {
    try {
      final result = await _dbHelper.updateRecurringExpense(recurringExpense);
      return result > 0;
    } catch (e) {
      print('Error updating recurring expense: $e');
      return false;
    }
  }

  // Toggle active status
  Future<bool> toggleRecurringExpense(int id, bool isActive) async {
    try {
      final result = await _dbHelper.updateRecurringExpenseActiveStatus(id, isActive);
      return result > 0;
    } catch (e) {
      print('Error toggling recurring expense: $e');
      return false;
    }
  }

  // Delete a recurring expense
  Future<bool> deleteRecurringExpense(int id) async {
    try {
      final result = await _dbHelper.deleteRecurringExpense(id);
      return result > 0;
    } catch (e) {
      print('Error deleting recurring expense: $e');
      return false;
    }
  }

  // Auto-generate expenses for recurring items that are due today
  Future<void> generateDueRecurringExpenses() async {
    try {
      final activeRecurring = await getActiveRecurringExpenses();
      final now = DateTime.now();

      for (final recurring in activeRecurring) {
        // Check if this recurring expense should generate an entry today
        if (_isDueToday(recurring, now)) {
          // Check if we already generated for this period
          if (_shouldGenerate(recurring, now)) {
            // Create the expense entry
            await _expenseService.addExpense(
              category: recurring.category,
              description: recurring.description,
              amount: recurring.amount,
              paymentMethod: recurring.paymentMethod,
              note: recurring.note,
              expenseDate: now,
            );

            // Update lastGeneratedDate
            await updateRecurringExpense(
              recurring.copyWith(lastGeneratedDate: now),
            );
          }
        }
      }
    } catch (e) {
      print('Error generating due recurring expenses: $e');
    }
  }

  // Check if a recurring expense is due today
  bool _isDueToday(RecurringExpense recurring, DateTime now) {
    // Check if startDate has passed
    if (recurring.startDate.isAfter(now)) {
      return false;
    }

    // Check if endDate has passed
    if (recurring.endDate != null && recurring.endDate!.isBefore(now)) {
      return false;
    }

    return true;
  }

  // Check if we should generate an expense for this recurring item today
  bool _shouldGenerate(RecurringExpense recurring, DateTime now) {
    final lastGenerated = recurring.lastGeneratedDate;

    switch (recurring.frequency) {
      case 'DAILY':
        // Generate if never generated or last generated was yesterday or earlier
        if (lastGenerated == null) return true;
        return !_isSameDay(lastGenerated, now);

      case 'WEEKLY':
        // Generate if it's been 7 days or more
        if (lastGenerated == null) return true;
        final daysDifference = now.difference(lastGenerated).inDays;
        return daysDifference >= 7;

      case 'MONTHLY':
        // Generate if it's a new month
        if (lastGenerated == null) return true;
        return lastGenerated.month != now.month || lastGenerated.year != now.year;

      case 'YEARLY':
        // Generate if it's a new year
        if (lastGenerated == null) return true;
        return lastGenerated.year != now.year;

      default:
        return false;
    }
  }

  // Helper to check if two dates are the same day
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // Get next occurrence date for a recurring expense
  DateTime getNextOccurrenceDate(RecurringExpense recurring) {
    final lastGenerated = recurring.lastGeneratedDate ?? recurring.startDate;

    switch (recurring.frequency) {
      case 'DAILY':
        return lastGenerated.add(const Duration(days: 1));
      case 'WEEKLY':
        return lastGenerated.add(const Duration(days: 7));
      case 'MONTHLY':
        return DateTime(
          lastGenerated.year,
          lastGenerated.month + 1,
          lastGenerated.day,
        );
      case 'YEARLY':
        return DateTime(
          lastGenerated.year + 1,
          lastGenerated.month,
          lastGenerated.day,
        );
      default:
        return lastGenerated;
    }
  }
}
