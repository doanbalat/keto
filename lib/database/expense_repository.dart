import 'package:sqflite/sqflite.dart';
import '../models/expense_model.dart';
import 'database_helper.dart';

class ExpenseRepository {
  final DatabaseHelper _dbHelper;

  ExpenseRepository({DatabaseHelper? dbHelper}) 
      : _dbHelper = dbHelper ?? DatabaseHelper();

  Future<int> insertExpense(Expense expense) async {
    final db = await _dbHelper.database;
    return await db.insert(DatabaseHelper.expenseTable, expense.toMap());
  }

  Future<List<Expense>> getAllExpenses() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.expenseTable,
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => Expense.fromMap(maps[i]));
  }

  Future<List<Expense>> getExpensesForToday() async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.expenseTable,
      where: 'timestamp >= ? AND timestamp < ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => Expense.fromMap(maps[i]));
  }

  Future<List<Expense>> getExpensesByDateRange(DateTime start, DateTime end) async {
    final db = await _dbHelper.database;
    final startOfDay = DateTime(start.year, start.month, start.day);
    final endOfDay = DateTime(end.year, end.month, end.day).add(const Duration(days: 1));

    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.expenseTable,
      where: 'timestamp >= ? AND timestamp < ?',
      whereArgs: [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => Expense.fromMap(maps[i]));
  }

  Future<List<Expense>> getExpensesByCategory(String category) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseHelper.expenseTable,
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) => Expense.fromMap(maps[i]));
  }

  Future<int> deleteExpense(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(DatabaseHelper.expenseTable, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> getTotalExpensesToday() async {
    final db = await _dbHelper.database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final result = await db.rawQuery(
      '''
      SELECT SUM(amount) as total FROM ${DatabaseHelper.expenseTable}
      WHERE timestamp >= ? AND timestamp < ?
      ''',
      [startOfDay.toIso8601String(), endOfDay.toIso8601String()],
    );

    if (result.isNotEmpty && result.first['total'] != null) {
      return result.first['total'] as int;
    }
    return 0;
  }

  Future<int> importExpenses(List<Expense> expenses) async {
    final db = await _dbHelper.database;
    int count = 0;
    await db.transaction((txn) async {
      for (var expense in expenses) {
        await txn.insert(
          DatabaseHelper.expenseTable,
          expense.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        count++;
      }
    });
    return count;
  }
}
