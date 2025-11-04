import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/product_model.dart';
import '../models/sold_item_model.dart';
import '../models/expense_model.dart';

class DatabaseHelper {
  static const String _databaseName = 'keto.db';
  static const int _databaseVersion = 3;

  static const String productTable = 'products';
  static const String soldItemTable = 'sold_items';
  static const String expenseTable = 'expenses';

  // Singleton pattern
  static final DatabaseHelper _instance = DatabaseHelper._internal();

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initializeDatabase();
    return _database!;
  }

  Future<Database> _initializeDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    // Create products table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $productTable (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        price INTEGER NOT NULL,
        costPrice INTEGER NOT NULL,
        imagePath TEXT,
        stock INTEGER DEFAULT 0,
        category TEXT DEFAULT 'Khác',
        description TEXT,
        createdAt TEXT NOT NULL,
        isActive INTEGER DEFAULT 1,
        unit TEXT DEFAULT 'cái'
      )
    ''');

    // Create sold_items table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $soldItemTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        productId INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        totalPrice INTEGER NOT NULL,
        paymentMethod TEXT DEFAULT 'Tiền mặt',
        discount INTEGER DEFAULT 0,
        note TEXT,
        customerName TEXT,
        FOREIGN KEY(productId) REFERENCES $productTable(id)
      )
    ''');

    // Create expenses table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $expenseTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        description TEXT NOT NULL,
        amount INTEGER NOT NULL,
        timestamp TEXT NOT NULL,
        receiptImagePath TEXT,
        note TEXT,
        paymentMethod TEXT DEFAULT 'Tiền mặt'
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add expenses table for version 2
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $expenseTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          category TEXT NOT NULL,
          description TEXT NOT NULL,
          amount INTEGER NOT NULL,
          timestamp TEXT NOT NULL,
          receiptImagePath TEXT,
          note TEXT,
          paymentMethod TEXT DEFAULT 'Tiền mặt'
        )
      ''');
    }

    if (oldVersion < 3) {
      // Add unit column for version 3
      await db.execute('''
        ALTER TABLE $productTable ADD COLUMN unit TEXT DEFAULT 'cái'
      ''');
    }
  }

  // ============ PRODUCT OPERATIONS ============

  /// Insert a new product
  Future<int> insertProduct(Product product) async {
    final db = await database;
    return await db.insert(
      productTable,
      product.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all active products
  Future<List<Product>> getAllProducts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      productTable,
      where: 'isActive = ?',
      whereArgs: [1],
      orderBy: 'id DESC',
    );
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  /// Get product by ID
  Future<Product?> getProductById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      productTable,
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
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      productTable,
      where: 'name LIKE ? AND isActive = ?',
      whereArgs: ['%$query%', 1],
      orderBy: 'name ASC',
    );
    return List.generate(maps.length, (i) => Product.fromMap(maps[i]));
  }

  /// Update product
  Future<int> updateProduct(Product product) async {
    final db = await database;
    return await db.update(
      productTable,
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  /// Soft delete product (mark as inactive)
  Future<int> deleteProduct(int id) async {
    final db = await database;
    return await db.update(
      productTable,
      {'isActive': 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Hard delete product (completely remove from database)
  Future<int> hardDeleteProduct(int id) async {
    final db = await database;
    // First delete all sold items for this product
    await db.delete(soldItemTable, where: 'productId = ?', whereArgs: [id]);
    // Then delete the product
    return await db.delete(productTable, where: 'id = ?', whereArgs: [id]);
  }

  // ============ SOLD ITEM OPERATIONS ============

  /// Insert a new sold item
  Future<int> insertSoldItem(SoldItem soldItem) async {
    final db = await database;
    return await db.insert(soldItemTable, soldItem.toMap());
  }

  /// Get all sold items (ordered by timestamp, newest first)
  Future<List<SoldItem>> getAllSoldItems() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      soldItemTable,
      orderBy: 'timestamp DESC',
    );

    List<SoldItem> soldItems = [];
    for (var map in maps) {
      final product = await getProductById(map['productId'] as int);
      soldItems.add(SoldItem.fromMap(map, product: product));
    }
    return soldItems;
  }

  /// Get sold items for today
  Future<List<SoldItem>> getSoldItemsForToday() async {
    final db = await database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final List<Map<String, dynamic>> maps = await db.query(
      soldItemTable,
      where: 'timestamp >= ? AND timestamp < ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'timestamp DESC',
    );

    List<SoldItem> soldItems = [];
    for (var map in maps) {
      final product = await getProductById(map['productId'] as int);
      soldItems.add(SoldItem.fromMap(map, product: product));
    }
    return soldItems;
  }

  /// Get sold items for a specific date range
  Future<List<SoldItem>> getSoldItemsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    final startOfDay = DateTime(start.year, start.month, start.day);
    final endOfDay = DateTime(
      end.year,
      end.month,
      end.day,
    ).add(const Duration(days: 1));

    final List<Map<String, dynamic>> maps = await db.query(
      soldItemTable,
      where: 'timestamp >= ? AND timestamp < ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'timestamp DESC',
    );

    List<SoldItem> soldItems = [];
    for (var map in maps) {
      final product = await getProductById(map['productId'] as int);
      soldItems.add(SoldItem.fromMap(map, product: product));
    }
    return soldItems;
  }

  /// Delete sold item
  Future<int> deleteSoldItem(int id) async {
    final db = await database;
    return await db.delete(soldItemTable, where: 'id = ?', whereArgs: [id]);
  }

  /// Get total sales for today
  Future<int> getTotalSalesToday() async {
    final db = await database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final result = await db.rawQuery(
      '''
      SELECT SUM(totalPrice) as total FROM $soldItemTable
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
  Future<int> getTotalProfitToday() async {
    final db = await database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final result = await db.rawQuery(
      '''
      SELECT SUM(si.totalPrice - si.discount - (p.costPrice * si.quantity)) as profit
      FROM $soldItemTable si
      JOIN $productTable p ON si.productId = p.id
      WHERE si.timestamp >= ? AND si.timestamp < ?
      ''',
      [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
    );

    if (result.isNotEmpty && result.first['profit'] != null) {
      return result.first['profit'] as int;
    }
    return 0;
  }

  /// Get total items sold today
  Future<int> getTotalItemsSoldToday() async {
    final db = await database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final result = await db.rawQuery(
      '''
      SELECT SUM(quantity) as total FROM $soldItemTable
      WHERE timestamp >= ? AND timestamp < ?
      ''',
      [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
    );

    if (result.isNotEmpty && result.first['total'] != null) {
      return result.first['total'] as int;
    }
    return 0;
  }

  // ============ EXPENSE OPERATIONS ============

  /// Insert a new expense
  Future<int> insertExpense(Expense expense) async {
    final db = await database;
    return await db.insert(expenseTable, expense.toMap());
  }

  /// Get all expenses (ordered by timestamp, newest first)
  Future<List<Expense>> getAllExpenses() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      expenseTable,
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => Expense.fromMap(maps[i]));
  }

  /// Get expenses for today
  Future<List<Expense>> getExpensesForToday() async {
    final db = await database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final List<Map<String, dynamic>> maps = await db.query(
      expenseTable,
      where: 'timestamp >= ? AND timestamp < ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => Expense.fromMap(maps[i]));
  }

  /// Get expenses for a specific date range
  Future<List<Expense>> getExpensesByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    final startOfDay = DateTime(start.year, start.month, start.day);
    final endOfDay = DateTime(
      end.year,
      end.month,
      end.day,
    ).add(const Duration(days: 1));

    final List<Map<String, dynamic>> maps = await db.query(
      expenseTable,
      where: 'timestamp >= ? AND timestamp < ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => Expense.fromMap(maps[i]));
  }

  /// Get expenses by category
  Future<List<Expense>> getExpensesByCategory(String category) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      expenseTable,
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => Expense.fromMap(maps[i]));
  }

  /// Delete expense
  Future<int> deleteExpense(int id) async {
    final db = await database;
    return await db.delete(expenseTable, where: 'id = ?', whereArgs: [id]);
  }

  /// Get total expenses for today
  Future<int> getTotalExpensesToday() async {
    final db = await database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final result = await db.rawQuery(
      '''
      SELECT SUM(amount) as total FROM $expenseTable
      WHERE timestamp >= ? AND timestamp < ?
      ''',
      [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
    );

    if (result.isNotEmpty && result.first['total'] != null) {
      return result.first['total'] as int;
    }
    return 0;
  }

  /// Get total expenses for date range
  Future<int> getTotalExpensesByDateRange(DateTime start, DateTime end) async {
    final db = await database;
    final startOfDay = DateTime(start.year, start.month, start.day);
    final endOfDay = DateTime(
      end.year,
      end.month,
      end.day,
    ).add(const Duration(days: 1));

    final result = await db.rawQuery(
      '''
      SELECT SUM(amount) as total FROM $expenseTable
      WHERE timestamp >= ? AND timestamp < ?
      ''',
      [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
    );

    if (result.isNotEmpty && result.first['total'] != null) {
      return result.first['total'] as int;
    }
    return 0;
  }

  // ============ UTILITY OPERATIONS ============

  /// Clear all data (for testing/reset)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete(expenseTable);
    await db.delete(soldItemTable);
    await db.delete(productTable);
  }

  /// Close database
  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
