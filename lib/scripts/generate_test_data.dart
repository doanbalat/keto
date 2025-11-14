import 'dart:math';
import '../database/database_helper.dart';
import '../models/product_model.dart';
import '../models/sold_item_model.dart';
import '../models/expense_model.dart';
import '../models/recurring_expense_model.dart';

/// Test data generator for Keto app
/// This script generates 1 month of realistic test data
class TestDataGenerator {
  static final Random _random = Random();
  static int _totalSalesRevenue = 0; // Track total revenue for expense calculation
  
  // Progress callback function
  static Function(String stage, int current, int total)? _progressCallback;

  // Sample products for Keto business (Vietnamese names)
  static final List<Map<String, dynamic>> _sampleProducts = [
    {
      'name': 'Trà Dâu',
      'price': 30000,
      'costPrice': 15000,
      'category': 'Đồ uống',
    },
    {
      'name': 'Trà Sữa',
      'price': 25000,
      'costPrice': 10000,
      'category': 'Đồ uống',
    },
    {
      'name': 'Cà Phê',
      'price': 15000,
      'costPrice': 6000,
      'category': 'Đồ uống',
    },
    {
      'name': 'Nước Ép Cà Chua',
      'price': 20000,
      'costPrice': 10000,
      'category': 'Đồ uống',
    },
    {
      'name': 'Smoothie Xoài',
      'price': 35000,
      'costPrice': 15000,
      'category': 'Đồ uống',
    },
    {
      'name': 'Trà Đào Cam Sả',
      'price': 25000,
      'costPrice': 10000,
      'category': 'Đồ uống',
    },
    {
      'name': 'Trà Vải',
      'price': 30000,
      'costPrice': 15500,
      'category': 'Đồ uống',
    },
    {
      'name': 'Matcha Latte',
      'price': 30000,
      'costPrice': 14000,
      'category': 'Đồ uống',
    },
    {
      'name': 'Cacao Nóng',
      'price': 25000,
      'costPrice': 9000,
      'category': 'Đồ uống',
    },
    {
      'name': 'Sữa Tươi Trân Châu Đường Đen',
      'price': 30000,
      'costPrice': 10000,
      'category': 'Đồ uống',
    },
    {
      'name': 'Nước Ép Cam',
      'price': 20000,
      'costPrice': 4500,
      'category': 'Đồ uống',
    },
    {
      'name': 'Sinh Tố Bơ',
      'price': 30000,
      'costPrice': 15000,
      'category': 'Đồ uống',
    },
    {
      'name': 'Trà Xanh Macchiato',
      'price': 30000,
      'costPrice': 19500,
      'category': 'Đồ uống',
    },
    {
      'name': 'Soda Việt Quất',
      'price': 20000,
      'costPrice': 10000,
      'category': 'Đồ uống',
    },
    {
      'name': 'Nước Ép Dưa Hấu',
      'price': 20000,
      'costPrice': 8000,
      'category': 'Đồ uống',
    },
  ];

  // Expense categories with expanded types
  static final List<String> _expenseCategories = [
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

  /// Set progress callback function
  static void setProgressCallback(
    Function(String stage, int current, int total) callback,
  ) {
    _progressCallback = callback;
  }

  /// Report progress to callback
  static void _reportProgress(String stage, int current, int total) {
    _progressCallback?.call(stage, current, total);
  }

  /// Generate 1 month of test data
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

      // Generate 1 month of sold items
      print('📊 Generating 1 month of sold items...');
      await _generateSalesData(db, productIds);

      // Generate recurring expenses
      print('⏱️  Generating recurring expenses...');
      await _generateRecurringExpenses(db);

      // Generate 1 month of one-time expenses
      print('💰 Generating 1 month of one-time expenses...');
      await _generateExpenseData(db);

      print('✅ Test data generation completed successfully!');
      print('📈 Summary:');
      print('   - ${productIds.length} products created');
      print('   - 30 days of sales data generated');
      print('   - Recurring expenses created');
      print('   - 30 days of one-time expense data generated');
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
    }

    print('   ✓ Created ${productIds.length} products');
    return productIds;
  }

  /// Generate 1 month of sales data with 30-50 sales per day
  static Future<void> _generateSalesData(
    DatabaseHelper db,
    List<int> productIds,
  ) async {
    final now = DateTime.now();
    final oneMonthAgo = now.subtract(const Duration(days: 30));

    int totalItems = 0;
    _totalSalesRevenue = 0; // Track total revenue for expense calculation

    // Pre-cache product data to avoid repeated database queries
    final productPrices = <int, int>{};
    for (var pid in productIds) {
      final product = await db.getProductById(pid);
      if (product != null) {
        productPrices[pid] = product.price;
      }
    }

    // Generate data for each day in the last 1 month
    for (int dayOffset = 30; dayOffset >= 0; dayOffset--) {
      final date = oneMonthAgo.add(Duration(days: 30 - dayOffset));
      final isWeekend =
          date.weekday == 6 || date.weekday == 7; // Saturday or Sunday

      // Report progress to callback
      _reportProgress('Sales', 30 - dayOffset, 31);

      // Generate 30-50 transactions per day (more on weekends)
      final transactionCount = isWeekend
          ? _random.nextInt(21) + 30 //  weekend
          : _random.nextInt(21) + 10; //  weekday

      // Batch insert for better performance
      final dailySalesItems = <SoldItem>[];

      for (int i = 0; i < transactionCount; i++) {
        // Random time during business hours (7 AM - 10 PM)
        final hour = _random.nextInt(15) + 7;
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
        final productPrice = productPrices[productId];

        if (productPrice != null) {
          final quantity = _random.nextInt(3) + 1;
          final totalPrice = productPrice * quantity;
          final discount = 0;

          final soldItem = SoldItem(
            id: 0, // Auto-generate ID
            productId: productId,
            quantity: quantity,
            timestamp: transactionTime,
            totalPrice: totalPrice,
            discount: discount,
            paymentMethod:
                _paymentMethods[_random.nextInt(_paymentMethods.length)],
            customerName: _random.nextDouble() > 0.4
                ? _customerNames[_random.nextInt(_customerNames.length)]
                : null,
            note: _random.nextDouble() > 0.8
                ? _getRandomNote()
                : null,
          );

          dailySalesItems.add(soldItem);
          _totalSalesRevenue += (totalPrice - discount);
          totalItems++;
        }
      }

      // Batch insert all sales for the day
      for (var item in dailySalesItems) {
        await db.insertSoldItem(item);
      }
    }

    print('\n   ✓ Generated $totalItems sales transactions');
    print('   ✓ Total sales revenue: ${_formatCurrency(_totalSalesRevenue)}');
  }

  /// Generate recurring expenses (monthly, weekly, and annual)
  static Future<void> _generateRecurringExpenses(DatabaseHelper db) async {
    final now = DateTime.now();
    final recurringExpenses = <RecurringExpense>[];
    int totalRecurringAmount = 0;

    // Monthly recurring expenses
    final monthlyExpenses = [
      {
        'category': 'Tiền thuê',
        'description': 'Tiền thuê mặt bằng cửa hàng',
        'amount': 3000000,
        'frequency': 'MONTHLY',
      },
      {
        'category': 'Lương nhân viên',
        'description': 'Lương nhân viên hàng tháng',
        'amount': 2000000,
        'frequency': 'MONTHLY',
      },
      {
        'category': 'Điện nước',
        'description': 'Hóa đơn điện nước hàng tháng',
        'amount': 800000,
        'frequency': 'MONTHLY',
      },
    ];

    // Weekly recurring expenses
    final weeklyExpenses = <Map<String, dynamic>>[];

    // Yearly recurring expenses
    final yearlyExpenses = <Map<String, dynamic>>[];

    // Create monthly recurring expenses starting from 2 weeks ago
    for (var expense in monthlyExpenses) {
      final startDate = now.subtract(const Duration(days: 14));
      final recurring = RecurringExpense(
        id: 0,
        category: expense['category'] as String,
        description: expense['description'] as String,
        amount: expense['amount'] as int,
        frequency: expense['frequency'] as String,
        startDate: startDate,
        endDate: null,
        paymentMethod: _paymentMethods[_random.nextInt(_paymentMethods.length)],
        note: 'Chi phí cố định tự động tạo',
        isActive: true,
        createdAt: startDate,
        lastGeneratedDate: null,
      );
      recurringExpenses.add(recurring);
      totalRecurringAmount += recurring.amount;
    }

    // Create weekly recurring expenses starting from 4 weeks ago
    for (var expense in weeklyExpenses) {
      final startDate = now.subtract(const Duration(days: 28));
      final recurring = RecurringExpense(
        id: 0,
        category: expense['category'] as String,
        description: expense['description'] as String,
        amount: expense['amount'] as int,
        frequency: expense['frequency'] as String,
        startDate: startDate,
        endDate: null,
        paymentMethod: _paymentMethods[_random.nextInt(_paymentMethods.length)],
        note: 'Chi phí cố định tự động tạo',
        isActive: true,
        createdAt: startDate,
        lastGeneratedDate: null,
      );
      recurringExpenses.add(recurring);
      totalRecurringAmount += (recurring.amount * 4); // 4 weeks in the period
    }

    // Create yearly recurring expenses
    for (var expense in yearlyExpenses) {
      final startDate = now.subtract(const Duration(days: 180));
      final recurring = RecurringExpense(
        id: 0,
        category: expense['category'] as String,
        description: expense['description'] as String,
        amount: expense['amount'] as int,
        frequency: expense['frequency'] as String,
        startDate: startDate,
        endDate: null,
        paymentMethod: _paymentMethods[_random.nextInt(_paymentMethods.length)],
        note: 'Chi phí cố định tự động tạo',
        isActive: true,
        createdAt: startDate,
        lastGeneratedDate: null,
      );
      recurringExpenses.add(recurring);
    }

    // Insert all recurring expenses
    for (var recurring in recurringExpenses) {
      await db.insertRecurringExpense(recurring);
    }

    print('\n   ✓ Created ${recurringExpenses.length} recurring expense templates');
    print('   ✓ Total monthly recurring amount: ${_formatCurrency(totalRecurringAmount)}');
  }

  /// Get random customer notes
  static String _getRandomNote() {
    final notes = [
      'Không đường',
      'Ít đá',
      'Nhiều đá',
      'Không sữa',
      'Thêm topping',
      'Giao nhanh',
      'Khách quen',
      'Đóng gói riêng',
      'Khách VIP',
    ];
    return notes[_random.nextInt(notes.length)];
  }

  /// Generate 1 month of one-time expense data with more variety
  static Future<void> _generateExpenseData(DatabaseHelper db) async {
    final now = DateTime.now();
    final oneMonthAgo = now.subtract(const Duration(days: 30));

    int totalExpenses = 0;
    int totalExpenseAmount = 0;

    // Pre-cache descriptions and notes for all categories
    final descriptionsByCategory = <String, List<String>>{};
    final notesByCategory = <String, List<String>>{};
    
    for (final category in _expenseCategories) {
      descriptionsByCategory[category] = _getExpenseDescriptionsForCategory(category);
      notesByCategory[category] = _getExpenseNotesForCategory(category);
    }

    // Generate expenses for each day
    for (int dayOffset = 30; dayOffset >= 0; dayOffset--) {
      final date = oneMonthAgo.add(Duration(days: 30 - dayOffset));

      // Report progress to callback
      _reportProgress('Expenses', 30 - dayOffset, 31);

      final dailyExpenses = <Expense>[];

      // High frequency: Raw materials - 70% chance per day
      if (_random.nextDouble() < 0.7) {
        final selectedCategory = 'Nhập hàng';
        final hour = _random.nextInt(12) + 7;
        final minute = _random.nextInt(60);

        final expenseTime = DateTime(
          date.year,
          date.month,
          date.day,
          hour,
          minute,
        );

        int amount = _getExpenseAmountForCategory(selectedCategory);
        amount = ((amount / 10000).round() * 10000).clamp(20000, 5000000);

        final descriptions = descriptionsByCategory[selectedCategory] ?? ['Chi phí'];
        final notes = notesByCategory[selectedCategory] ?? ['Ghi chú'];

        final expense = Expense(
          id: 0,
          category: selectedCategory,
          description: descriptions[_random.nextInt(descriptions.length)],
          amount: amount,
          timestamp: expenseTime,
          paymentMethod:
              _paymentMethods[_random.nextInt(_paymentMethods.length)],
          note: _random.nextDouble() > 0.6
              ? notes[_random.nextInt(notes.length)]
              : null,
        );

        dailyExpenses.add(expense);
      }

      // Low frequency: Other expenses (Khác category only) - 15% chance per day
      if (_random.nextDouble() < 0.15) {
        final selectedCategory = 'Khác';
        final hour = _random.nextInt(12) + 7;
        final minute = _random.nextInt(60);

        final expenseTime = DateTime(
          date.year,
          date.month,
          date.day,
          hour,
          minute,
        );

        int amount = _getExpenseAmountForCategory(selectedCategory);
        amount = ((amount / 10000).round() * 10000).clamp(20000, 5000000);

        final descriptions = descriptionsByCategory[selectedCategory] ?? ['Chi phí'];
        final notes = notesByCategory[selectedCategory] ?? ['Ghi chú'];

        final expense = Expense(
          id: 0,
          category: selectedCategory,
          description: descriptions[_random.nextInt(descriptions.length)],
          amount: amount,
          timestamp: expenseTime,
          paymentMethod:
              _paymentMethods[_random.nextInt(_paymentMethods.length)],
          note: _random.nextDouble() > 0.6
              ? notes[_random.nextInt(notes.length)]
              : null,
        );

        dailyExpenses.add(expense);
      }

      // Batch insert all expenses for the day
      for (var expense in dailyExpenses) {
        await db.insertExpense(expense);
        totalExpenseAmount += expense.amount;
        totalExpenses++;
      }
    }

    print('\n   ✓ Generated $totalExpenses expenses');
    print('   ✓ Total expense amount: ${_formatCurrency(totalExpenseAmount)}');
    print('   ✓ Expense ratio: ${((_totalSalesRevenue > 0) ? ((totalExpenseAmount / _totalSalesRevenue) * 100).toStringAsFixed(1) : "0.0")}% of sales revenue');
  }

  /// Get relevant notes for expense category (returns list for caching)
  static List<String> _getExpenseNotesForCategory(String category) {
    final notes = {
      'Tiền thuê': ['Thuê tháng này', 'Đã thanh toán', 'Chốt sổ'],
      'Điện nước': ['Hóa đơn tháng', 'Đã thanh toán', 'Chốt sổ'],
      'Nhập hàng': ['Hàng tươi', 'Đã kiểm tra chất lượng', 'Nhập thêm'],
      'Lương nhân viên': ['Lương tháng', 'Thưởng', 'Tạm ứng'],
      'Vận chuyển': ['Giao hàng đúng hạn', 'COD', 'Vận chuyển nhanh'],
      'Marketing': ['Chạy 7 ngày', 'Hiệu quả tốt', 'Cần tăng ngân sách'],
      'Bảo trì': ['Định kỳ', 'Khẩn cấp', 'Bảo dưỡng'],
      'Văn phòng phẩm': ['Mua sổ sách', 'In ấn', 'Dụng cụ văn phòng'],
      'Ăn uống': ['Ăn trưa', 'Ăn nhẹ', 'Nước uống'],
      'Khác': ['Chi phí đột xuất', 'Không xác định', 'Tạm thời', 'Cần theo dõi'],
    };
    
    return notes[category] ?? ['Ghi chú'];
  }

  /// Get realistic expense amount based on category (whole numbers like 10K, 50K, 100K, etc.)
  static int _getExpenseAmountForCategory(String category) {
    final List<int> multipliers = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 15, 20, 30, 50, 100];
    
    int multiplier;
    switch (category) {
      case 'Tiền thuê':
        multiplier = multipliers[_random.nextInt(5) + 10]; // 11-15 = 110K-150K
        break;
      case 'Điện nước':
        multiplier = multipliers[_random.nextInt(5) + 2]; // 3-7 = 30K-70K
        break;
      case 'Nhập hàng':
        multiplier = multipliers[_random.nextInt(5) + 5]; // 6-10 = 60K-100K
        break;
      case 'Lương nhân viên':
        multiplier = multipliers[_random.nextInt(5) + 8]; // 9-13 = 90K-130K
        break;
      case 'Vận chuyển':
        multiplier = multipliers[_random.nextInt(5)]; // 1-5 = 10K-50K
        break;
      case 'Marketing':
        multiplier = multipliers[_random.nextInt(5) + 5]; // 6-10 = 60K-100K
        break;
      case 'Bảo trì':
        multiplier = multipliers[_random.nextInt(4) + 2]; // 3-5 = 30K-50K
        break;
      case 'Văn phòng phẩm':
        multiplier = multipliers[_random.nextInt(3) + 1]; // 2-4 = 20K-40K
        break;
      case 'Ăn uống':
        multiplier = multipliers[_random.nextInt(4) + 1]; // 2-5 = 20K-50K
        break;
      default: // Khác
        multiplier = multipliers[_random.nextInt(6) + 2]; // 3-8 = 30K-80K
        break;
    }
    
    return multiplier * 10000; // Always returns multiple of 10K
  }

  /// Get descriptions for expense category (returns list for caching)
  static List<String> _getExpenseDescriptionsForCategory(String category) {
    final descriptions = {
      'Tiền thuê': [
        'Tiền thuê mặt bằng',
        'Tiền thuê kho',
        'Tiền thuê phòng',
      ],
      'Điện nước': [
        'Hóa đơn điện',
        'Hóa đơn nước',
        'Phí quản lý',
      ],
      'Nhập hàng': [
        'Mua nguyên liệu bổ sung',
        'Mua cà phê hạt premium',
        'Mua trà cao cấp',
        'Mua kem phô mai nhập khẩu',
        'Mua chocolate đen',
        'Mua sữa tươi thêm',
      ],
      'Lương nhân viên': [
        'Lương tháng',
        'Thưởng hiệu suất',
        'Tạm ứng lương',
        'Phụ cấp',
      ],
      'Vận chuyển': [
        'Giao hàng nguyên liệu',
        'Ship đơn hàng',
        'Xăng xe giao hàng',
        'Phí giao hàng nhanh',
      ],
      'Marketing': [
        'Quảng cáo Facebook Ads',
        'Quảng cáo Instagram',
        'Poster in ấn',
        'Banner quảng cáo',
        'Google Ads',
        'Voucher khuyến mãi',
      ],
      'Bảo trì': [
        'Sửa máy pha cà phê',
        'Bảo dưỡng tủ lạnh',
        'Sửa máy xay sinh tố',
        'Thay lò xo cửa',
        'Vệ sinh bếp chuyên sâu',
        'Sơn sửa tường',
        'Thay bóng đèn LED',
      ],
      'Văn phòng phẩm': [
        'Mua sổ sách ghi chép',
        'Bút viết',
        'In hóa đơn',
        'Giấy in A4',
      ],
      'Ăn uống': [
        'Ăn trưa nhân viên',
        'Mua nước uống',
        'Ăn nhẹ buổi sáng',
        'Cà phê khách',
      ],
      'Khác': [
        'Mua khẩu trang bảo vệ',
        'Mua bình rửa tay sạch khuẩn',
        'Mua túi đựng rác',
        'Tiền phạt giao thông',
        'Mua sơn sửa nhanh',
        'Mua dụng cụ nhỏ',
      ],
    };

    return descriptions[category] ?? ['Chi phí'];
  }
  /// Format currency for display
  static String _formatCurrency(int amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)} Triệu';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)} Nghìn';
    }
    return amount.toString();
  }
}

void main() async {
  await TestDataGenerator.generateTestData();
}
