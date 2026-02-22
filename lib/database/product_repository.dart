import 'package:sqflite/sqflite.dart';
import '../models/product_model.dart';
import 'database_helper.dart';

class ProductRepository {
  final DatabaseHelper _dbHelper;

  ProductRepository({DatabaseHelper? dbHelper}) 
      : _dbHelper = dbHelper ?? DatabaseHelper();

  /// Insert a new product
  Future<int> insertProduct(Product product) async {
    final db = await _dbHelper.database;
    return await db.insert(
      DatabaseHelper.productTable,
      product.toMap(),
    );
  }

  /// Get all active products
  Future<List<Product>> getAllProducts() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.productTable,
      where: 'isActive = ?',
      whereArgs: [1],
      orderBy: 'id DESC',
    );
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  /// Get product by ID
  Future<Product?> getProductById(int id) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.productTable,
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Product.fromMap(maps.first);
    }
    return null;
  }

  /// Search products by name
  Future<List<Product>> searchProducts(String query) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.productTable,
      where: 'name LIKE ? AND isActive = ?',
      whereArgs: ['%$query%', 1],
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  /// Update product
  Future<int> updateProduct(Product product) async {
    final db = await _dbHelper.database;
    return await db.update(
      DatabaseHelper.productTable,
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  /// Soft delete product (mark as inactive)
  Future<int> deleteProduct(int id) async {
    final db = await _dbHelper.database;
    return await db.update(
      DatabaseHelper.productTable,
      {'isActive': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Hard delete product (completely remove from database)
  Future<int> hardDeleteProduct(int id) async {
    final db = await _dbHelper.database;
    // Transaction to ensure consistency
    return await db.transaction((txn) async {
       // First delete all sold items for this product
      await txn.delete(DatabaseHelper.soldItemTable, where: 'productId = ?', whereArgs: [id]);
      // Then delete the product
      return await txn.delete(DatabaseHelper.productTable, where: 'id = ?', whereArgs: [id]);
    });
  }

  /// Import/Bulk insert products
  Future<int> importProducts(List<Product> products) async {
    final db = await _dbHelper.database;
    int count = 0;
    await db.transaction((txn) async {
      for (var product in products) {
        await txn.insert(
          DatabaseHelper.productTable,
          product.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        count++;
      }
    });
    return count;
  }
}
