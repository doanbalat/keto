import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/product_model.dart';
import '../models/sold_item_model.dart';
import '../models/expense_model.dart';
import '../models/recurring_expense_model.dart';

class DatabaseHelper {
  static const String _databaseName = 'keto.db';
  static const int _databaseVersion = 4;

  static const String productTable = 'products';
  static const String soldItemTable = 'sold_items';
  static const String expenseTable = 'expenses';
  static const String recurringExpenseTable = 'recurring_expenses';

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

    // Create recurring_expenses table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $recurringExpenseTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category TEXT NOT NULL,
        description TEXT NOT NULL,
        amount INTEGER NOT NULL,
        frequency TEXT NOT NULL,
        startDate TEXT NOT NULL,
        endDate TEXT,
        paymentMethod TEXT DEFAULT 'Tiền mặt',
        note TEXT,
        isActive INTEGER DEFAULT 1,
        createdAt TEXT NOT NULL,
        lastGeneratedDate TEXT
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

    if (oldVersion < 4) {
      // Add recurring_expenses table for version 4
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $recurringExpenseTable (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          category TEXT NOT NULL,
          description TEXT NOT NULL,
          amount INTEGER NOT NULL,
          frequency TEXT NOT NULL,
          startDate TEXT NOT NULL,
          endDate TEXT,
          paymentMethod TEXT DEFAULT 'Tiền mặt',
          note TEXT,
          isActive INTEGER DEFAULT 1,
          createdAt TEXT NOT NULL,
          lastGeneratedDate TEXT
        )
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

  // ============ RECURRING EXPENSE OPERATIONS ============

  /// Insert a new recurring expense
  Future<int> insertRecurringExpense(RecurringExpense recurringExpense) async {
    final db = await database;
    return await db.insert(recurringExpenseTable, recurringExpense.toMapForInsert());
  }

  /// Get all active recurring expenses
  Future<List<RecurringExpense>> getActiveRecurringExpenses() async {
    final db = await database;
    final maps = await db.query(
      recurringExpenseTable,
      where: 'isActive = ?',
      whereArgs: [1],
    );
    return List.generate(maps.length, (i) => RecurringExpense.fromMap(maps[i]));
  }

  /// Get all recurring expenses (including inactive)
  Future<List<RecurringExpense>> getAllRecurringExpenses() async {
    final db = await database;
    final maps = await db.query(recurringExpenseTable);
    return List.generate(maps.length, (i) => RecurringExpense.fromMap(maps[i]));
  }

  /// Get a single recurring expense by ID
  Future<RecurringExpense?> getRecurringExpenseById(int id) async {
    final db = await database;
    final maps = await db.query(
      recurringExpenseTable,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return RecurringExpense.fromMap(maps.first);
    }
    return null;
  }

  /// Update a recurring expense
  Future<int> updateRecurringExpense(RecurringExpense recurringExpense) async {
    final db = await database;
    return await db.update(
      recurringExpenseTable,
      recurringExpense.toMap(),
      where: 'id = ?',
      whereArgs: [recurringExpense.id],
    );
  }

  /// Update the active status of a recurring expense
  Future<int> updateRecurringExpenseActiveStatus(int id, bool isActive) async {
    final db = await database;
    return await db.update(
      recurringExpenseTable,
      {'isActive': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete a recurring expense
  Future<int> deleteRecurringExpense(int id) async {
    final db = await database;
    return await db.delete(
      recurringExpenseTable,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============ UTILITY OPERATIONS ============

  /// Clear all data (for testing/reset)
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete(expenseTable);
    await db.delete(soldItemTable);
    await db.delete(productTable);
    await db.delete(recurringExpenseTable);
  }

  /// Import products from import data
  /// Returns the number of products imported
  Future<int> importProducts(List<Product> products) async {
    final db = await database;
    int count = 0;
    
    for (var product in products) {
      try {
        // Use INSERT OR REPLACE to handle duplicates
        await db.rawInsert(
          '''
          INSERT OR REPLACE INTO $productTable (
            id, name, price, costPrice, imagePath, stock, category, 
            description, createdAt, isActive, unit
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            product.id,
            product.name,
            product.price,
            product.costPrice,
            product.imagePath,
            product.stock,
            product.category,
            product.description,
            product.createdAt.toIso8601String(),
            product.isActive ? 1 : 0,
            product.unit,
          ],
        );
        count++;
      } catch (e) {
        print('⚠️ Error importing product ${product.name}: $e');
      }
    }
    
    return count;
  }

  /// Import sold items from import data
  /// Returns the number of items imported
  Future<int> importSoldItems(List<SoldItem> items) async {
    final db = await database;
    int count = 0;
    
    for (var item in items) {
      try {
        await db.rawInsert(
          '''
          INSERT OR REPLACE INTO $soldItemTable (
            id, productId, quantity, timestamp, totalPrice, 
            paymentMethod, discount, note, customerName
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            item.id,
            item.productId,
            item.quantity,
            item.timestamp.toIso8601String(),
            item.totalPrice,
            item.paymentMethod,
            item.discount,
            item.note,
            item.customerName,
          ],
        );
        count++;
      } catch (e) {
        print('⚠️ Error importing sold item ${item.id}: $e');
      }
    }
    
    return count;
  }

  /// Import expenses from import data
  /// Returns the number of expenses imported
  Future<int> importExpenses(List<Expense> expenses) async {
    final db = await database;
    int count = 0;
    
    for (var expense in expenses) {
      try {
        await db.rawInsert(
          '''
          INSERT OR REPLACE INTO $expenseTable (
            id, category, description, amount, timestamp, 
            receiptImagePath, note, paymentMethod
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
          ''',
          [
            expense.id,
            expense.category,
            expense.description,
            expense.amount,
            expense.timestamp.toIso8601String(),
            expense.receiptImagePath,
            expense.note,
            expense.paymentMethod,
          ],
        );
        count++;
      } catch (e) {
        print('⚠️ Error importing expense ${expense.id}: $e');
      }
    }
    
    return count;
  }

  /// Close database
  Future<void> closeDatabase() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
