import '../database/database_helper.dart';
import '../models/product_model.dart';
import '../models/sold_item_model.dart';

class ProductService {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  // ============ PRODUCT SERVICE METHODS ============

  /// Get all products from database
  Future<List<Product>> getAllProducts() async {
    try {
      return await _dbHelper.getAllProducts();
    } catch (e) {
      print('Error getting all products: $e');
      return [];
    }
  }

  /// Search products by name
  Future<List<Product>> searchProducts(String query) async {
    try {
      if (query.isEmpty) {
        return await getAllProducts();
      }
      return await _dbHelper.searchProducts(query);
    } catch (e) {
      print('Error searching products: $e');
      return [];
    }
  }

  /// Add new product
  Future<bool> addProduct(
    String name,
    int price,
    int costPrice, {
    String category = 'Khác',
    String? description,
    String unit = 'cái',
  }) async {
    try {
      // Check if product already exists
      if (await _dbHelper.productExists(name, price)) {
        print('Product already exists');
        return false;
      }

      final product = Product(
        id: 0, // Will be auto-generated
        name: name,
        price: price,
        costPrice: costPrice,
        category: category,
        description: description,
        unit: unit,
      );

      await _dbHelper.insertProduct(product);
      return true;
    } catch (e) {
      print('Error adding product: $e');
      return false;
    }
  }

  /// Update product
  Future<bool> updateProduct(Product product) async {
    try {
      await _dbHelper.updateProduct(product);
      return true;
    } catch (e) {
      print('Error updating product: $e');
      return false;
    }
  }

  /// Delete product (soft delete - marks as inactive)
  Future<bool> deleteProduct(int productId) async {
    try {
      await _dbHelper.deleteProduct(productId);
      return true;
    } catch (e) {
      print('Error deleting product: $e');
      return false;
    }
  }

  /// Permanently delete product and all its sold items
  Future<bool> hardDeleteProduct(int productId) async {
    try {
      await _dbHelper.hardDeleteProduct(productId);
      return true;
    } catch (e) {
      print('Error hard deleting product: $e');
      return false;
    }
  }

  /// Get product by ID
  Future<Product?> getProductById(int id) async {
    try {
      return await _dbHelper.getProductById(id);
    } catch (e) {
      print('Error getting product: $e');
      return null;
    }
  }

  // ============ SOLD ITEM SERVICE METHODS ============

  /// Add sold item to database
  Future<bool> addSoldItem({
    required int productId,
    required int quantity,
    required int totalPrice,
    String paymentMethod = 'Tiền mặt',
    int discount = 0,
    String? note,
    String? customerName,
  }) async {
    try {
      final soldItem = SoldItem(
        id: 0, // Will be auto-generated
        productId: productId,
        quantity: quantity,
        timestamp: DateTime.now(),
        totalPrice: totalPrice,
        paymentMethod: paymentMethod,
        discount: discount,
        note: note,
        customerName: customerName,
      );

      await _dbHelper.insertSoldItem(soldItem);
      return true;
    } catch (e) {
      print('Error adding sold item: $e');
      return false;
    }
  }

  /// Get all sold items
  Future<List<SoldItem>> getAllSoldItems() async {
    try {
      return await _dbHelper.getAllSoldItems();
    } catch (e) {
      print('Error getting sold items: $e');
      return [];
    }
  }

  /// Get today's sold items
  Future<List<SoldItem>> getTodaySoldItems() async {
    try {
      return await _dbHelper.getSoldItemsForToday();
    } catch (e) {
      print('Error getting today\'s sold items: $e');
      return [];
    }
  }

  /// Get sold items for date range
  Future<List<SoldItem>> getSoldItemsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    try {
      return await _dbHelper.getSoldItemsByDateRange(start, end);
    } catch (e) {
      print('Error getting sold items by date range: $e');
      return [];
    }
  }

  /// Delete sold item
  Future<bool> deleteSoldItem(int soldItemId) async {
    try {
      await _dbHelper.deleteSoldItem(soldItemId);
      return true;
    } catch (e) {
      print('Error deleting sold item: $e');
      return false;
    }
  }

  // ============ STATISTICS SERVICE METHODS ============

  /// Get today's total sales revenue
  Future<int> getTodayTotalSales() async {
    try {
      return await _dbHelper.getTotalSalesToday();
    } catch (e) {
      print('Error getting today\'s total sales: $e');
      return 0;
    }
  }

  /// Get today's total profit
  Future<int> getTodayTotalProfit() async {
    try {
      return await _dbHelper.getTotalProfitToday();
    } catch (e) {
      print('Error getting today\'s total profit: $e');
      return 0;
    }
  }

  /// Get total items sold today
  Future<int> getTodayTotalItemsSold() async {
    try {
      return await _dbHelper.getTotalItemsSoldToday();
    } catch (e) {
      print('Error getting today\'s total items sold: $e');
      return 0;
    }
  }

  // ============ UTILITY METHODS ============

  /// Clear all database (for testing/reset)
  Future<void> clearAllData() async {
    try {
      await _dbHelper.clearAllData();
      print('All data cleared');
    } catch (e) {
      print('Error clearing data: $e');
    }
  }

  /// Initialize sample data (for first-time setup)
  Future<void> initializeSampleData() async {
    try {
      final existingProducts = await getAllProducts();
      if (existingProducts.isEmpty) {
        await addProduct('Trà Dâu', 25000, 10000, category: 'Đồ uống');
        await addProduct('Cà Phê', 30000, 12000, category: 'Đồ uống');
        await addProduct('Nước Ngọt', 15000, 5000, category: 'Đồ uống');
        print('Sample data initialized');
      }
    } catch (e) {
      print('Error initializing sample data: $e');
    }
  }
}
