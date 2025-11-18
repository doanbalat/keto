import 'package:keto/models/sold_item_model.dart';
import 'package:keto/models/expense_model.dart';
import 'package:keto/models/product_model.dart';

/// Interface for database operations
abstract class IDatabaseHelper {
  Future<List<SoldItem>> getSoldItemsByDateRange(
    DateTime startDate,
    DateTime endDate,
  );

  Future<List<Expense>> getExpensesByDateRange(
    DateTime startDate,
    DateTime endDate,
  );

  Future<List<Product>> getAllProducts();
  Future<List<SoldItem>> getAllSoldItems();
  Future<List<Expense>> getAllExpenses();

  Future<List<Map<String, dynamic>>> getDailyStats(
    DateTime startDate,
    DateTime endDate,
  );
}
