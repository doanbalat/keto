import 'package:keto/models/product_model.dart';
import 'package:keto/models/sold_item_model.dart';
import 'package:keto/services/product_service.dart';

/// Mock ProductService for testing
class MockProductService extends ProductService {
  List<Product> _products = [];
  List<SoldItem> _soldItems = [];
  bool throwError = false;
  String? errorMessage;

  /// Default constructor with mock data
  MockProductService() {
    _initializeMockData();
  }

  /// Named constructor for empty product list
  MockProductService.empty() {
    _products = [];
  }

  /// Initialize with mock data for testing
  void _initializeMockData() {
    _products = [
      Product(
        id: 1,
        name: 'Product 1',
        price: 50000,
        costPrice: 30000,
        stock: 100,
        unit: 'cái',
        category: 'Electronics',
        description: 'Test product 1',
      ),
      Product(
        id: 2,
        name: 'Product 2',
        price: 75000,
        costPrice: 45000,
        stock: 50,
        unit: 'cái',
        category: 'Accessories',
        description: 'Test product 2',
      ),
      Product(
        id: 3,
        name: 'Product 3',
        price: 25000,
        costPrice: 15000,
        stock: 200,
        unit: 'cái',
        category: 'Electronics',
        description: 'Test product 3',
      ),
    ];
  }

  /// Set mock products
  void setProducts(List<Product> products) {
    _products = List.from(products);
  }

  /// Add a mock product
  void addMockProduct(Product product) {
    _products.add(product);
  }

  /// Set mock sold items
  void setSoldItems(List<SoldItem> items) {
    _soldItems = List.from(items);
  }

  /// Clear all data
  void clear() {
    _products.clear();
    _soldItems.clear();
  }

  @override
  Future<List<Product>> getAllProducts() async {
    if (throwError) {
      throw Exception(errorMessage ?? 'Mock error');
    }
    return Future.value(List.from(_products));
  }

  @override
  Future<Product?> getProductById(int id) async {
    if (throwError) {
      throw Exception(errorMessage ?? 'Mock error');
    }
    return Future.value(
      _products.cast<Product?>().firstWhere((p) => p?.id == id, orElse: () => null),
    );
  }

  @override
  Future<List<SoldItem>> getTodaySoldItems() async {
    if (throwError) {
      throw Exception(errorMessage ?? 'Mock error');
    }
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);

    return Future.value(
      _soldItems
          .where((item) =>
              item.timestamp.isAfter(todayStart) && item.timestamp.isBefore(todayEnd))
          .toList(),
    );
  }

  @override
  Future<List<SoldItem>> getAllSoldItems() async {
    if (throwError) {
      throw Exception(errorMessage ?? 'Mock error');
    }
    return Future.value(List.from(_soldItems));
  }

  @override
  Future<int?> addProduct(
    String name,
    int price,
    int costPrice, {
    String category = 'Khác',
    String? description,
    String unit = 'cái',
    int stock = 0,
    String? imagePath,
  }) async {
    if (throwError) {
      throw Exception(errorMessage ?? 'Mock error');
    }
    final product = Product(
      id: _products.isEmpty ? 1 : _products.fold<int>(0, (max, p) => p.id > max ? p.id : max) + 1,
      name: name,
      price: price,
      costPrice: costPrice,
      stock: stock,
      unit: unit,
      imagePath: imagePath,
      description: description,
      category: category,
    );
    _products.add(product);
    return product.id;
  }

  @override
  Future<bool> updateProduct(Product product) async {
    if (throwError) {
      throw Exception(errorMessage ?? 'Mock error');
    }
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index != -1) {
      _products[index] = product;
      return true;
    }
    return false;
  }

  @override
  Future<bool> deleteProduct(int productId) async {
    if (throwError) {
      throw Exception(errorMessage ?? 'Mock error');
    }
    final initialLength = _products.length;
    _products.removeWhere((p) => p.id == productId);
    return _products.length < initialLength;
  }

  @override
  Future<bool> addSoldItem({
    required int productId,
    required int quantity,
    required int totalPrice,
    String paymentMethod = 'Tiền mặt',
    int discount = 0,
    String? note,
    String? customerName,
  }) async {
    if (throwError) {
      throw Exception(errorMessage ?? 'Mock error');
    }
    final soldItem = SoldItem(
      id: _soldItems.isEmpty ? 1 : _soldItems.fold<int>(0, (max, item) => item.id > max ? item.id : max) + 1,
      productId: productId,
      quantity: quantity,
      timestamp: DateTime.now(),
      totalPrice: totalPrice,
      paymentMethod: paymentMethod,
      discount: discount,
      note: note,
      customerName: customerName,
    );
    _soldItems.add(soldItem);
    return true;
  }

  @override
  Future<bool> deleteSoldItem(int soldItemId) async {
    if (throwError) {
      throw Exception(errorMessage ?? 'Mock error');
    }
    final initialLength = _soldItems.length;
    _soldItems.removeWhere((item) => item.id == soldItemId);
    return _soldItems.length < initialLength;
  }

  @override
  Future<int> getTodayTotalSales() async {
    if (throwError) {
      throw Exception(errorMessage ?? 'Mock error');
    }
    final items = await getTodaySoldItems();
    return items.fold<int>(0, (sum, item) => sum + item.totalPrice);
  }

  @override
  Future<List<Product>> searchProducts(String query) async {
    if (throwError) {
      throw Exception(errorMessage ?? 'Mock error');
    }
    if (query.isEmpty) {
      return Future.value(List.from(_products));
    }
    return Future.value(
      _products
          .where((p) => p.name.toLowerCase().contains(query.toLowerCase()))
          .toList(),
    );
  }
}
