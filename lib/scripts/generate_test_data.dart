import 'dart:math';
import '../database/database_helper.dart';
import '../models/product_model.dart';
import '../models/sold_item_model.dart';
import '../models/expense_model.dart';

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

  // Expense categories with expanded types
  static final List<String> _expenseCategories = [
    'Nguyên liệu',
    'Điện nước',
    'Vận chuyển',
    'Nhân công',
    'Quảng cáo',
    'Bảo trì',
    'Thuê mặt bằng',
    'Bao bì',
    'Đào tạo',
    'Internet & Điện thoại',
    'Kế toán & Thuế',
    'Bảo hiểm',
    'Văn phòng phẩm',
    'Sự kiện & Marketing',
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

      // Generate 1 month of expenses
      print('💰 Generating 1 month of expenses...');
      await _generateExpenseData(db);

      print('✅ Test data generation completed successfully!');
      print('📈 Summary:');
      print('   - ${productIds.length} products created');
      print('   - 30 days of sales data generated');
      print('   - 30 days of expense data generated');
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
          ? _random.nextInt(21) + 40 // 40-60 for weekend
          : _random.nextInt(21) + 30; // 30-50 for weekday

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
          // Vary quantities more - 1-5 items
          final quantity = _random.nextInt(5) + 1;
          final totalPrice = productPrice * quantity;
          // 25% chance of discount (increased from 20%)
          final discount = _random.nextDouble() > 0.75
              ? _random.nextInt(15000) + 5000 // 5k-20k discount
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

  /// Generate 1 month of expense data with more variety
  static Future<void> _generateExpenseData(DatabaseHelper db) async {
    final now = DateTime.now();
    final oneMonthAgo = now.subtract(const Duration(days: 30));

    int totalExpenses = 0;
    int totalExpenseAmount = 0;

    // Calculate target expense amount (40% of sales revenue)
    final targetExpenseAmount = (_totalSalesRevenue * 0.4).toInt();
    final expensePerDay = (targetExpenseAmount / 30).toInt();

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
      final isWeekend =
          date.weekday == 6 || date.weekday == 7; // Saturday or Sunday

      // Report progress to callback
      _reportProgress('Expenses', 30 - dayOffset, 31);

      // Generate 3-8 expenses per day for more variety
      // Adjust the count based on whether it's weekend for variance
      final expenseCount = isWeekend
          ? _random.nextInt(6) + 4 // 4-9 for weekend
          : _random.nextInt(6) + 3; // 3-8 for weekday

      final dailyExpenses = <Expense>[];

      for (int i = 0; i < expenseCount; i++) {
        final hour = _random.nextInt(12) + 7; // 7 AM - 7 PM
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
        
        // Get base amount for category
        int amount = _getExpenseAmountForCategory(category);
        
        // Adjust amount based on daily target to keep 40% ratio
        final dayAdjustmentFactor = (expensePerDay / 2000000); // Normalize around 2M average
        amount = (amount * dayAdjustmentFactor).toInt().clamp(50000, 20000000);

        // Get cached descriptions and notes
        final descriptions = descriptionsByCategory[category] ?? ['Chi phí'];
        final notes = notesByCategory[category] ?? ['Ghi chú'];

        final expense = Expense(
          id: 0, // Auto-generate ID
          category: category,
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
      'Nguyên liệu': ['Hàng tươi', 'Đã kiểm tra chất lượng', 'Nhập số lượng lớn'],
      'Điện nước': ['Hóa đơn tháng này', 'Đã thanh toán', 'Chốt sổ'],
      'Vận chuyển': ['Giao hàng đúng hạn', 'COD', 'Vận chuyển nhanh'],
      'Nhân công': ['Lương tháng', 'Thưởng', 'Tạm ứng'],
      'Quảng cáo': ['Chạy 7 ngày', 'Hiệu quả tốt', 'Cần tăng ngân sách'],
      'Bảo trì': ['Định kỳ', 'Khẩn cấp', 'Bảo dưỡng'],
      'Thuê mặt bằng': ['Thuê tháng', 'Đã thanh toán', 'Trả trước 3 tháng'],
      'Bao bì': ['Túi giấy', 'Hộp đựng', 'Logo mới'],
      'Đào tạo': ['Đào tạo nhân viên mới', 'Kỹ năng bán hàng', 'Học nấu ăn'],
      'Internet & Điện thoại': ['Hóa đơn tháng', 'Gói cước', 'Gia hạn'],
      'Kế toán & Thuế': ['Thuế VAT', 'Dịch vụ kế toán', 'Quyết toán thuế'],
      'Bảo hiểm': ['BHXH', 'Bảo hiểm cháy nổ', 'Bảo hiểm hàng hóa'],
      'Văn phòng phẩm': ['Mua sổ sách', 'In ấn', 'Dụng cụ văn phòng'],
      'Sự kiện & Marketing': ['Khai trương', 'Khuyến mãi', 'Event cuối tuần'],
      'Khác': ['Chi phí đột xuất', 'Không xác định', 'Tạm thời'],
    };
    
    return notes[category] ?? ['Ghi chú'];
  }

  /// Get realistic expense amount based on category
  static int _getExpenseAmountForCategory(String category) {
    switch (category) {
      case 'Nguyên liệu':
        return _random.nextInt(3000000) + 500000; // 0.5-3.5M
      case 'Điện nước':
        return _random.nextInt(1500000) + 300000; // 0.3-1.8M
      case 'Vận chuyển':
        return _random.nextInt(500000) + 50000; // 50k-550k
      case 'Nhân công':
        return _random.nextInt(8000000) + 3000000; // 3-11M
      case 'Quảng cáo':
        return _random.nextInt(3000000) + 200000; // 0.2-3.2M
      case 'Bảo trì':
        return _random.nextInt(800000) + 100000; // 100k-900k
      case 'Thuê mặt bằng':
        return _random.nextInt(10000000) + 5000000; // 5-15M
      case 'Bao bì':
        return _random.nextInt(1000000) + 100000; // 100k-1.1M
      case 'Đào tạo':
        return _random.nextInt(2000000) + 500000; // 0.5-2.5M
      case 'Internet & Điện thoại':
        return _random.nextInt(500000) + 200000; // 200k-700k
      case 'Kế toán & Thuế':
        return _random.nextInt(5000000) + 1000000; // 1-6M
      case 'Bảo hiểm':
        return _random.nextInt(3000000) + 500000; // 0.5-3.5M
      case 'Văn phòng phẩm':
        return _random.nextInt(500000) + 50000; // 50k-550k
      case 'Sự kiện & Marketing':
        return _random.nextInt(5000000) + 1000000; // 1-6M
      default: // Khác
        return _random.nextInt(2000000) + 100000; // 0.1-2.1M
    }
  }

  /// Get descriptions for expense category (returns list for caching)
  static List<String> _getExpenseDescriptionsForCategory(String category) {
    final descriptions = {
      'Nguyên liệu': [
        'Mua trà các loại',
        'Mua cà phê hạt',
        'Mua bột mì hạnh nhân',
        'Mua sữa tươi',
        'Mua trái cây tươi',
        'Mua đường không calo',
        'Mua kem phô mai',
        'Mua bơ đậu phộng',
        'Mua chocolate đen',
        'Mua rau xanh organic',
      ],
      'Điện nước': [
        'Hóa đơn điện tháng này',
        'Hóa đơn nước',
        'Phí quản lý chung cư',
        'Phí vệ sinh môi trường',
      ],
      'Vận chuyển': [
        'Giao hàng nguyên liệu',
        'Ship đơn hàng cho khách',
        'Xăng xe giao hàng',
        'Phí giao hàng nhanh',
        'Cước phí vận chuyển',
      ],
      'Nhân công': [
        'Lương nhân viên bán hàng',
        'Lương nhân viên pha chế',
        'Thưởng hiệu suất',
        'Phúc lợi nhân viên',
        'Tạm ứng lương',
        'Phụ cấp',
      ],
      'Quảng cáo': [
        'Quảng cáo Facebook Ads',
        'Quảng cáo Instagram',
        'Poster in ấn',
        'Banner quảng cáo',
        'Google Ads',
        'TikTok Ads',
        'Voucher khuyến mãi',
      ],
      'Bảo trì': [
        'Sửa máy pha cà phê',
        'Vệ sinh tổng thể',
        'Bảo dưỡng máy xay sinh tố',
        'Thay dao máy xay',
        'Sơn sửa quán',
      ],
      'Thuê mặt bằng': [
        'Tiền thuê mặt bằng tháng này',
        'Đặt cọc thuê nhà',
        'Gia hạn hợp đồng thuê',
      ],
      'Bao bì': [
        'Mua túi giấy kraft',
        'Hộp đựng đồ ăn',
        'Ly nhựa có nắp',
        'Ống hút giấy',
        'Logo dán ly',
        'Túi nilon đóng gói',
      ],
      'Đào tạo': [
        'Khóa học pha chế',
        'Đào tạo nhân viên mới',
        'Khóa học kỹ năng bán hàng',
        'Workshop marketing',
      ],
      'Internet & Điện thoại': [
        'Cước internet tháng',
        'Cước điện thoại',
        'Sim điện thoại',
        'Gia hạn gói cước',
      ],
      'Kế toán & Thuế': [
        'Dịch vụ kế toán thuế',
        'Thuế VAT',
        'Thuế môn bài',
        'Phí quyết toán thuế',
        'Lệ phí đăng ký kinh doanh',
      ],
      'Bảo hiểm': [
        'BHXH nhân viên',
        'Bảo hiểm cháy nổ',
        'Bảo hiểm trách nhiệm dân sự',
        'Bảo hiểm hàng hóa',
      ],
      'Văn phòng phẩm': [
        'Mua sổ sách ghi chép',
        'Bút viết',
        'In hóa đơn',
        'Giấy in A4',
        'Kệ trưng bày',
      ],
      'Sự kiện & Marketing': [
        'Chi phí khai trương',
        'Sự kiện khuyến mãi',
        'Event cuối tuần',
        'Livestream bán hàng',
        'Chụp ảnh sản phẩm',
      ],
      'Khác': [
        'Chi phí đột xuất',
        'Tiền phạt vi phạm',
        'Chi phí đặc biệt',
        'Sửa chữa khác',
        'Mua thiết bị nhỏ',
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
