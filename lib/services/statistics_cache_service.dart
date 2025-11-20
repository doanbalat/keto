import 'package:flutter/foundation.dart';
import '../models/sold_item_model.dart';
import '../models/expense_model.dart';

class StatisticsCacheEntry {
  final List<SoldItem> soldItems;
  final List<Expense> expenses;
  final int totalRevenue;
  final int totalExpenses;
  final int netProfit;
  final int itemsSold;
  final DateTime cachedAt;

  StatisticsCacheEntry({
    required this.soldItems,
    required this.expenses,
    required this.totalRevenue,
    required this.totalExpenses,
    required this.netProfit,
    required this.itemsSold,
    required this.cachedAt,
  });
}

class StatisticsCacheService extends ChangeNotifier {
  static final StatisticsCacheService _instance =
      StatisticsCacheService._internal();

  factory StatisticsCacheService() {
    return _instance;
  }

  StatisticsCacheService._internal();

  // Cache storage: key is "startDate_endDate"
  final Map<String, StatisticsCacheEntry> _cache = {};

  /// Get cached statistics for a date range
  /// Returns null if not cached or cache is invalid
  StatisticsCacheEntry? getCache(DateTime startDate, DateTime endDate) {
    final key = _generateKey(startDate, endDate);
    return _cache[key];
  }

  /// Store statistics in cache
  void setCache(
    DateTime startDate,
    DateTime endDate,
    List<SoldItem> soldItems,
    List<Expense> expenses,
    int totalRevenue,
    int totalExpenses,
    int netProfit,
    int itemsSold,
  ) {
    final key = _generateKey(startDate, endDate);
    _cache[key] = StatisticsCacheEntry(
      soldItems: soldItems,
      expenses: expenses,
      totalRevenue: totalRevenue,
      totalExpenses: totalExpenses,
      netProfit: netProfit,
      itemsSold: itemsSold,
      cachedAt: DateTime.now(),
    );
  }

  /// Clear all cache (called when data is modified)
  void clearCache() {
    _cache.clear();
    notifyListeners();
  }

  /// Clear specific date range cache
  void clearCacheForDateRange(DateTime startDate, DateTime endDate) {
    final key = _generateKey(startDate, endDate);
    _cache.remove(key);
    notifyListeners();
  }

  /// Generate cache key from date range
  String _generateKey(DateTime startDate, DateTime endDate) {
    return '${startDate.year}-${startDate.month}-${startDate.day}_'
        '${endDate.year}-${endDate.month}-${endDate.day}';
  }

  /// Get cache size (for debugging)
  int getCacheSize() => _cache.length;

  /// Check if cache exists for date range
  bool hasCacheForDateRange(DateTime startDate, DateTime endDate) {
    final key = _generateKey(startDate, endDate);
    return _cache.containsKey(key);
  }

  /// Static method to invalidate cache from anywhere in the app
  /// Call this when a sale or expense is added/edited/deleted
  static void invalidateCache() {
    StatisticsCacheService().clearCache();
  }
}
