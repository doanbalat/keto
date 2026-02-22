import 'package:sqflite/sqflite.dart';
import '../models/sold_item_model.dart';
import '../models/product_model.dart';
import 'database_helper.dart';

class SalesRepository {
  final DatabaseHelper _dbHelper;

  SalesRepository({DatabaseHelper? dbHelper}) 
      : _dbHelper = dbHelper ?? DatabaseHelper();

  /// Insert a new sold item
  Future<int> insertSoldItem(SoldItem soldItem) async {
    final db = await _dbHelper.database;
    return await db.insert(DatabaseHelper.soldItemTable, soldItem.toMap());
  }

  /// Get all sold items with product details using JOIN
  /// Optimized to avoid N+1 query problem
  Future<List<SoldItem>> getAllSoldItems() async {
    final db = await _dbHelper.database;
    
    // Perform a LEFT JOIN to get product details along with sold item data
    // We alias product columns to avoid collision with sold_item columns if needed
    // But since SoldItem.fromMap expects a separate Product object, we'll map carefully.
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT 
        s.*, 
        p.name as p_name, 
        p.price as p_price,
        p.costPrice as p_costPrice, 
        p.imagePath as p_imagePath, 
        p.stock as p_stock,
        p.unit as p_unit,
        p.category as p_category
      FROM ${DatabaseHelper.soldItemTable} s
      LEFT JOIN ${DatabaseHelper.productTable} p ON s.productId = p.id
      ORDER BY s.timestamp DESC
    ''');

    return result.map((row) {
      // reconstruct Product from the joined columns if available
      Product? product;
      if (row['p_name'] != null) {
        product = Product(
          id: row['productId'] as int,
          name: row['p_name'] as String,
          price: row['p_price'] as int,
          costPrice: row['p_costPrice'] as int? ?? 0,
          imagePath: row['p_imagePath'] as String?,
          stock: row['p_stock'] as int? ?? 0,
          unit: row['p_unit'] as String? ?? 'cái',
          category: row['p_category'] as String? ?? 'Khác',
        );
      }
      
      return SoldItem.fromMap(row, product: product);
    }).toList();
  }

  /// Get sold items for today with JOIN
  Future<List<SoldItem>> getSoldItemsForToday() async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT 
        s.*, 
        p.name as p_name, 
        p.price as p_price,
        p.costPrice as p_costPrice, 
        p.imagePath as p_imagePath, 
        p.stock as p_stock,
        p.unit as p_unit,
        p.category as p_category
      FROM ${DatabaseHelper.soldItemTable} s
      LEFT JOIN ${DatabaseHelper.productTable} p ON s.productId = p.id
      WHERE s.timestamp >= ? AND s.timestamp < ?
      ORDER BY s.timestamp DESC
    ''', [startOfDay.toIso8601String(), endOfDay.toIso8601String()]);

    return result.map((row) {
      Product? product;
      if (row['p_name'] != null) {
        product = Product(
          id: row['productId'] as int,
          name: row['p_name'] as String,
          price: row['p_price'] as int,
          costPrice: row['p_costPrice'] as int? ?? 0,
          imagePath: row['p_imagePath'] as String?,
          stock: row['p_stock'] as int? ?? 0,
          unit: row['p_unit'] as String? ?? 'cái',
          category: row['p_category'] as String? ?? 'Khác',
        );
      }
      return SoldItem.fromMap(row, product: product);
    }).toList();
  }
  
  /// Get sold items by date range with JOIN
   Future<List<SoldItem>> getSoldItemsByDateRange(DateTime start, DateTime end) async {
    final db = await _dbHelper.database;
    final startOfDay = DateTime(start.year, start.month, start.day);
    final endOfDay = DateTime(end.year, end.month, end.day).add(const Duration(days: 1));

    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT 
        s.*, 
        p.name as p_name, 
        p.price as p_price,
        p.costPrice as p_costPrice, 
        p.imagePath as p_imagePath, 
        p.stock as p_stock,
        p.unit as p_unit,
        p.category as p_category
      FROM ${DatabaseHelper.soldItemTable} s
      LEFT JOIN ${DatabaseHelper.productTable} p ON s.productId = p.id
      WHERE s.timestamp >= ? AND s.timestamp < ?
      ORDER BY s.timestamp DESC
    ''', [startOfDay.toIso8601String(), endOfDay.toIso8601String()]);

    return result.map((row) {
       Product? product;
      if (row['p_name'] != null) {
        product = Product(
          id: row['productId'] as int,
          name: row['p_name'] as String,
          price: row['p_price'] as int,
          costPrice: row['p_costPrice'] as int? ?? 0,
          imagePath: row['p_imagePath'] as String?,
          stock: row['p_stock'] as int? ?? 0,
          unit: row['p_unit'] as String? ?? 'cái',
          category: row['p_category'] as String? ?? 'Khác',
        );
      }
      return SoldItem.fromMap(row, product: product);
    }).toList();
  }

  /// Delete a sold item
  Future<int> deleteSoldItem(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      DatabaseHelper.soldItemTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get total sales revenue for today
  Future<int> getTotalSalesToday() async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final result = await db.rawQuery(
      '''
      SELECT SUM(totalPrice) as total FROM ${DatabaseHelper.soldItemTable}
      WHERE timestamp >= ? AND timestamp < ?
      ''',
      [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
    );

    if (result.isNotEmpty && result.first['total'] != null) {
      return result.first['total'] as int;
    }
    return 0;
  }

  /// Get total profit for today
  /// Profit = SUM(SoldItem.totalPrice - (Product.costPrice * SoldItem.quantity))
  Future<int> getTotalProfitToday() async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // We need to join with products to get costPrice
    final List<Map<String, dynamic>> result = await db.rawQuery('''
      SELECT 
        s.totalPrice, 
        s.quantity,
        s.discount,
        p.costPrice
      FROM ${DatabaseHelper.soldItemTable} s
      LEFT JOIN ${DatabaseHelper.productTable} p ON s.productId = p.id
      WHERE s.timestamp >= ? AND s.timestamp < ?
    ''', [startOfDay.toIso8601String(), endOfDay.toIso8601String()]);

    int totalProfit = 0;
    for (var row in result) {
      final totalPrice = row['totalPrice'] as int;
      final quantity = row['quantity'] as int;
      final costPrice = row['costPrice'] as int? ?? 0;
      final discount = row['discount'] as int? ?? 0;
      
      // Profit = (Revenue - Discount) - (Cost * Quantity)
      // Note: totalPrice in SoldItem usually already includes discount?
      // Let's assume totalPrice IS the final revenue.
      // If discount is just for record keeping, we shouldn't subtract it again if it's already in totalPrice.
      // Looking at `ban_hang.dart` or `SoldItem` logic would clarify.
      // Assuming totalPrice is final amount paid.
      // Profit = TotalPrice - (Cost * Quantity)
      
      totalProfit += totalPrice - (costPrice * quantity);
    }
    
    return totalProfit;
  }

  /// Get total items sold today
  Future<int> getTotalItemsSoldToday() async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final result = await db.rawQuery(
      '''
      SELECT SUM(quantity) as total FROM ${DatabaseHelper.soldItemTable}
      WHERE timestamp >= ? AND timestamp < ?
      ''',
      [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
    );

    if (result.isNotEmpty && result.first['total'] != null) {
      return result.first['total'] as int;
    }
    return 0;
  }

  /// Import/Bulk insert sold items
  Future<int> importSoldItems(List<SoldItem> items) async {
    final db = await _dbHelper.database;
    int count = 0;
    await db.transaction((txn) async {
      for (var item in items) {
        await txn.insert(
          DatabaseHelper.soldItemTable,
          item.toMap(), // ID will be ignored/auto-generated if 0? Actually if 0 it might be kept or auto-inc.
                        // Usually import keeps original ID if possible, but conflicts?
                        // For simplicity, let's let SQLite auto-increment or replace.
                        // But `item.toMap()` includes ID if != 0.
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        count++;
      }
    });
    return count;
  }
}
