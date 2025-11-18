import 'package:shared_preferences/shared_preferences.dart';

class ProductCategoryService {
  static const String _defaultCategoryKey = 'defaultProductCategory';
  static const String _defaultCategory = 'Khác';

  // Predefined categories
  static const List<String> categories = [
    'Đồ uống',
    'Thực phẩm',
    'Bánh/Kẹo',
    'Chăm sóc cá nhân',
    'Vệ sinh/Gia dụng',
    'Điện tử/Phụ kiện',
    'Khác',
  ];

  // Display names with English translations
  static const List<String> categoryDisplayNames = [
    'Đồ uống (Beverages)',
    'Thực phẩm (Food)',
    'Bánh/Kẹo (Baked goods/Candy)',
    'Chăm sóc cá nhân (Personal care)',
    'Vệ sinh/Gia dụng (Household supplies)',
    'Điện tử/Phụ kiện (Electronics/Accessories)',
    'Khác (Other)',
  ];

  /// Get the default product category
  static Future<String> getDefaultCategory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_defaultCategoryKey) ?? _defaultCategory;
  }

  /// Set the default product category
  static Future<void> setDefaultCategory(String category) async {
    if (!categories.contains(category)) {
      throw ArgumentError('Invalid category: $category');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_defaultCategoryKey, category);
  }

  /// Get display name for a category
  static String getCategoryDisplayName(String category) {
    final index = categories.indexOf(category);
    return index >= 0 ? categoryDisplayNames[index] : category;
  }

  /// Get all available categories
  static List<String> getAvailableCategories() {
    return List.unmodifiable(categories);
  }

  /// Get all display names
  static List<String> getAvailableCategoryDisplayNames() {
    return List.unmodifiable(categoryDisplayNames);
  }
}
