import 'package:keto/models/sold_item_model.dart';
import 'package:keto/models/expense_model.dart';
import 'package:keto/models/product_model.dart';

/// Mock DatabaseHelper for testing
/// Note: We create a wrapper class instead of extending DatabaseHelper
/// because DatabaseHelper uses a factory constructor which prevents direct extension
class MockDatabaseHelper {
  List<Product> _products = [];
  List<SoldItem> _soldItems = [];
  List<Expense> _expenses = [];

  /// Default constructor with mock data
  MockDatabaseHelper() {
    _initializeMockData();
  }

  /// Named constructor for empty database
  MockDatabaseHelper.empty() {
    _products = [];
    _soldItems = [];
    _expenses = [];
  }

  /// Initialize with mock data for testing
  void _initializeMockData() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Mock products
    _products = [
      Product(
        id: 1,
        name: 'Product 1',
        price: 50000,
        costPrice: 30000,
        stock: 100,
        unit: 'cái',
        category: 'Electronics',
        description: 'Test product 1',
      ),
      Product(
        id: 2,
        name: 'Product 2',
        price: 75000,
        costPrice: 45000,
        stock: 50,
        unit: 'cái',
        category: 'Accessories',
        description: 'Test product 2',
      ),
    ];

    // Mock sold items
    _soldItems = [
      SoldItem(
        id: 1,
        productId: 1,
        quantity: 5,
        timestamp: today,
        totalPrice: 250000,
        paymentMethod: 'Tiền mặt',
        discount: 0,
        note: 'Test sale 1',
        customerName: 'Customer 1',
      ),
      SoldItem(
        id: 2,
        productId: 2,
        quantity: 3,
        timestamp: today,
        totalPrice: 225000,
        paymentMethod: 'Tiền mặt',
        discount: 0,
        note: 'Test sale 2',
        customerName: 'Customer 2',
      ),
    ];

    // Mock expenses
    _expenses = [
      Expense(
        id: 1,
        category: 'Rent',
        description: 'Monthly rent',
        amount: 5000000,
        timestamp: today,
        paymentMethod: 'Tiền mặt',
      ),
      Expense(
        id: 2,
        category: 'Utilities',
        description: 'Electric and water',
        amount: 1000000,
        timestamp: today,
        paymentMethod: 'Tiền mặt',
      ),
    ];
  }

  Future<List<SoldItem>> getSoldItemsByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return Future.value(
      _soldItems
          .where((item) =>
              item.timestamp.isAfter(startDate) &&
              item.timestamp.isBefore(endDate.add(const Duration(days: 1))))
          .toList(),
    );
  }

  Future<List<Expense>> getExpensesByDateRange(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return Future.value(
      _expenses
          .where((expense) =>
              expense.timestamp.isAfter(startDate) &&
              expense.timestamp.isBefore(endDate.add(const Duration(days: 1))))
          .toList(),
    );
  }

  Future<List<Product>> getAllProducts() async {
    return Future.value(List.from(_products));
  }

  Future<List<SoldItem>> getAllSoldItems() async {
    return Future.value(List.from(_soldItems));
  }

  Future<List<Expense>> getAllExpenses() async {
    return Future.value(List.from(_expenses));
  }

  Future<List<Map<String, dynamic>>> getDailyStats(
    DateTime startDate,
    DateTime endDate,
  ) async {
    // Return simple mock daily stats
    final dailyStats = <Map<String, dynamic>>[];
    for (int i = 0; i < 7; i++) {
      final date = startDate.add(Duration(days: i));
      if (date.isBefore(endDate) || date.isAtSameMomentAs(endDate)) {
        dailyStats.add({
          'date': date.toString().split(' ')[0],
          'revenue': 100000 + (i * 10000),
          'expense': 20000 + (i * 5000),
        });
      }
    }
    return Future.value(dailyStats);
  }

  /// Set mock sold items
  void setSoldItems(List<SoldItem> items) {
    _soldItems = List.from(items);
  }

  /// Set mock expenses
  void setExpenses(List<Expense> items) {
    _expenses = List.from(items);
  }

  /// Set mock products
  void setProducts(List<Product> products) {
    _products = List.from(products);
  }

  /// Clear all data
  void clear() {
    _products.clear();
    _soldItems.clear();
    _expenses.clear();
  }
}
