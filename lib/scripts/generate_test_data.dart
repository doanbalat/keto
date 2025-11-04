import 'dart:math';
import '../database/database_helper.dart';
import '../models/product_model.dart';
import '../models/sold_item_model.dart';
import '../models/expense_model.dart';

/// Test data generator for Keto app
/// This script generates 2 months of realistic test data
class TestDataGenerator {
  static final Random _random = Random();

  // Sample products for Keto business (Vietnamese names)
  static final List<Map<String, dynamic>> _sampleProducts = [
    {
      'name': 'Trà Dâu',
      'price': 45000,
      'costPrice': 15000,
      'category': 'Đồ uống',
    },
    {
      'name': 'Trà Sữa',
      'price': 50000,
      'costPrice': 18000,
      'category': 'Đồ uống',
    },
    {
      'name': 'Cà Phê',
      'price': 35000,
      'costPrice': 12000,
      'category': 'Đồ uống',
    },
    {
      'name': 'Nước Ép Cà Chua',
      'price': 40000,
      'costPrice': 14000,
      'category': 'Đồ uống',
    },
    {
      'name': 'Smoothie Xoài',
      'price': 55000,
      'costPrice': 20000,
      'category': 'Đồ uống',
    },
    {
      'name': 'Bánh Mì Keto',
      'price': 65000,
      'costPrice': 25000,
      'category': 'Thức ăn',
    },
    {
      'name': 'Salad Rau',
      'price': 60000,
      'costPrice': 22000,
      'category': 'Thức ăn',
    },
    {
      'name': 'Cơm Chiên Cauliflower',
      'price': 70000,
      'costPrice': 28000,
      'category': 'Thức ăn',
    },
    {
      'name': 'Muffin Chocolate',
      'price': 45000,
      'costPrice': 16000,
      'category': 'Bánh',
    },
    {
      'name': 'Cookie Bơ Đậu Phộng',
      'price': 50000,
      'costPrice': 18000,
      'category': 'Bánh',
    },
  ];

  // Expense categories
  static final List<String> _expenseCategories = [
    'Nguyên liệu',
    'Điện nước',
    'Vận chuyển',
    'Nhân công',
    'Quảng cáo',
    'Bảo trì',
    'Khác',
  ];

  // Customer names
  static final List<String> _customerNames = [
    'Anh Sơn',
    'Chị Linh',
    'Bạn Minh',
    'Thầy Hùng',
    'Cô Mai',
    'Anh Tuấn',
    'Chị Phương',
    'Bạn Lan',
  ];

  // Payment methods
  static final List<String> _paymentMethods = [
    'Tiền mặt',
    'Chuyển khoản',
    'Thẻ',
  ];

  /// Generate 2 months of test data
  static Future<void> generateTestData() async {
    print('🔄 Starting test data generation...');

    final db = DatabaseHelper();

    try {
      // Clear existing data
      print('🗑️  Clearing existing data...');
      await db.clearAllData();

      // Insert sample products
      print('📦 Inserting sample products...');
      final productIds = await _insertProducts(db);

      // Generate 2 months of sold items
      print('📊 Generating 2 months of sold items...');
      await _generateSalesData(db, productIds);

      // Generate 2 months of expenses
      print('💰 Generating 2 months of expenses...');
      await _generateExpenseData(db);

      print('✅ Test data generation completed successfully!');
      print('📈 Summary:');
      print('   - ${productIds.length} products created');
      print('   - 60 days of sales data generated');
      print('   - 60 days of expense data generated');
    } catch (e) {
      print('❌ Error generating test data: $e');
      rethrow;
    }
  }

  /// Insert sample products and return their IDs
  static Future<List<int>> _insertProducts(DatabaseHelper db) async {
    final List<int> productIds = [];

    for (var productData in _sampleProducts) {
      final product = Product(
        id: 0, // Auto-generate ID
        name: productData['name'] as String,
        price: productData['price'] as int,
        costPrice: productData['costPrice'] as int,
        category: productData['category'] as String? ?? 'Khác',
        stock: _random.nextInt(100) + 10,
      );

      final id = await db.insertProduct(product);
      productIds.add(id);
      print('   ✓ Created: ${product.name} (ID: $id)');
    }

    return productIds;
  }

  /// Generate 2 months of sales data
  static Future<void> _generateSalesData(
    DatabaseHelper db,
    List<int> productIds,
  ) async {
    final now = DateTime.now();
    final twoMonthsAgo = now.subtract(const Duration(days: 60));

    int totalItems = 0;

    // Generate data for each day in the last 2 months
    for (int dayOffset = 60; dayOffset >= 0; dayOffset--) {
      final date = twoMonthsAgo.add(Duration(days: 60 - dayOffset));
      final isWeekend =
          date.weekday == 6 || date.weekday == 7; // Saturday or Sunday

      // Generate 2-6 transactions per day (more on weekends)
      final transactionCount = isWeekend
          ? _random.nextInt(5) +
                3 // 3-7 for weekend
          : _random.nextInt(4) + 2; // 2-5 for weekday

      for (int i = 0; i < transactionCount; i++) {
        // Random time during business hours (8 AM - 8 PM)
        final hour = _random.nextInt(12) + 8;
        final minute = _random.nextInt(60);
        final second = _random.nextInt(60);

        final transactionTime = DateTime(
          date.year,
          date.month,
          date.day,
          hour,
          minute,
          second,
        );

        // Random product and quantity
        final productId = productIds[_random.nextInt(productIds.length)];
        final product = await db.getProductById(productId);

        if (product != null) {
          final quantity = _random.nextInt(3) + 1; // 1-3 items
          final totalPrice = product.price * quantity;
          final discount = _random.nextDouble() > 0.8
              ? _random.nextInt(10000) // 20% chance of discount
              : 0;

          final soldItem = SoldItem(
            id: 0, // Auto-generate ID
            productId: productId,
            quantity: quantity,
            timestamp: transactionTime,
            totalPrice: totalPrice,
            discount: discount,
            paymentMethod:
                _paymentMethods[_random.nextInt(_paymentMethods.length)],
            customerName: _random.nextDouble() > 0.5
                ? _customerNames[_random.nextInt(_customerNames.length)]
                : null,
            note: _random.nextDouble() > 0.7 ? 'Ghi chú: không đường' : null,
          );

          await db.insertSoldItem(soldItem);
          totalItems++;
        }
      }
    }

    print('   ✓ Generated $totalItems sales transactions');
  }

  /// Generate 2 months of expense data
  static Future<void> _generateExpenseData(DatabaseHelper db) async {
    final now = DateTime.now();
    final twoMonthsAgo = now.subtract(const Duration(days: 60));

    int totalExpenses = 0;

    // Generate expenses for each day
    for (int dayOffset = 60; dayOffset >= 0; dayOffset--) {
      final date = twoMonthsAgo.add(Duration(days: 60 - dayOffset));

      // Generate 0-2 expenses per day
      final expenseCount = _random.nextInt(2);

      for (int i = 0; i < expenseCount; i++) {
        final hour = _random.nextInt(8) + 9; // 9 AM - 5 PM
        final minute = _random.nextInt(60);

        final expenseTime = DateTime(
          date.year,
          date.month,
          date.day,
          hour,
          minute,
        );

        final category =
            _expenseCategories[_random.nextInt(_expenseCategories.length)];
        final amount = _getExpenseAmountForCategory(category);

        final expense = Expense(
          id: 0, // Auto-generate ID
          category: category,
          description: _getExpenseDescription(category),
          amount: amount,
          timestamp: expenseTime,
          paymentMethod:
              _paymentMethods[_random.nextInt(_paymentMethods.length)],
          note: _random.nextDouble() > 0.7 ? 'Ghi chú chi phí' : null,
        );

        await db.insertExpense(expense);
        totalExpenses++;
      }
    }

    print('   ✓ Generated $totalExpenses expenses');
  }

  /// Get realistic expense amount based on category
  static int _getExpenseAmountForCategory(String category) {
    switch (category) {
      case 'Nguyên liệu':
        return _random.nextInt(5000000) + 2000000; // 2-7M
      case 'Điện nước':
        return _random.nextInt(2000000) + 500000; // 0.5-2.5M
      case 'Vận chuyển':
        return _random.nextInt(1000000) + 200000; // 0.2-1.2M
      case 'Nhân công':
        return _random.nextInt(5000000) + 5000000; // 5-10M
      case 'Quảng cáo':
        return _random.nextInt(2000000) + 500000; // 0.5-2.5M
      case 'Bảo trì':
        return _random.nextInt(1000000) + 100000; // 0.1-1.1M
      default: // Khác
        return _random.nextInt(2000000) + 100000; // 0.1-2.1M
    }
  }

  /// Get description for expense category
  static String _getExpenseDescription(String category) {
    final descriptions = {
      'Nguyên liệu': [
        'Mua trà',
        'Mua cà phê',
        'Mua bột mì',
        'Mua sữa',
        'Mua trái cây',
      ],
      'Điện nước': ['Hóa đơn điện', 'Hóa đơn nước', 'Thanh toán chứng chỉ'],
      'Vận chuyển': ['Giao hàng nguyên liệu', 'Ship đơn hàng', 'Xăng xe'],
      'Nhân công': ['Lương nhân viên', 'Thưởng hiệu suất', 'Phúc lợi'],
      'Quảng cáo': [
        'Quảng cáo Facebook',
        'Quảng cáo Instagram',
        'Poster in ấn',
      ],
      'Bảo trì': [
        'Sửa máy pha cà phê',
        'Vệ sinh quán',
        'Bảo dưỡng trang thiết bị',
      ],
      'Khác': ['Chi phí khác', 'Tiền phạt', 'Chi phí đặc biệt'],
    };

    final categoryDescriptions = descriptions[category] ?? ['Chi phí'];
    return categoryDescriptions[_random.nextInt(categoryDescriptions.length)];
  }
}

void main() async {
  await TestDataGenerator.generateTestData();
}
