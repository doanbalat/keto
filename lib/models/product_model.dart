class Product {
  final int id;
  final String name;
  final int price;
  final int costPrice; // Cost to purchase, for profit calculation
  final String? imagePath; // NOT YET IMPLEMENTED: Product image storage
  final int stock; // NOT YET IMPLEMENTED: Inventory tracking
  final String category; // NOT YET IMPLEMENTED: Product category/type
  final String? description; // NOT YET IMPLEMENTED: Product details
  final DateTime createdAt; // NOT YET IMPLEMENTED: Track creation date
  final bool isActive; // NOT YET IMPLEMENTED: Soft delete/archive flag
  final String unit; // Unit of measurement (cái, kg, liter, box, etc.)

  Product({
    required this.id,
    required this.name,
    required this.price,
    this.costPrice = 0,
    this.imagePath,
    this.stock = 0,
    this.category = 'Khác',
    this.description,
    DateTime? createdAt,
    this.isActive = true,
    this.unit = 'cái',
  }) : createdAt = createdAt ?? DateTime.now();

  // Convert Product to Map for database storage
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'name': name,
      'price': price,
      'costPrice': costPrice,
      'imagePath': imagePath,
      'stock': stock,
      'category': category,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive ? 1 : 0,
      'unit': unit,
    };

    // Only include id if it's not 0 (0 means auto-generate)
    if (id != 0) {
      map['id'] = id;
    }

    return map;
  }

  // Create Product from Map retrieved from database
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] as int,
      name: map['name'] as String,
      price: map['price'] as int,
      costPrice: map['costPrice'] as int,
      imagePath: map['imagePath'] as String?,
      stock: map['stock'] as int? ?? 0,
      category: map['category'] as String? ?? 'Khác',
      description: map['description'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      isActive: (map['isActive'] as int?) == 1,
      unit: map['unit'] as String? ?? 'cái',
    );
  }

  // Create a copy of Product with modified fields
  Product copyWith({
    int? id,
    String? name,
    int? price,
    int? costPrice,
    String? imagePath,
    int? stock,
    String? category,
    String? description,
    DateTime? createdAt,
    bool? isActive,
    String? unit,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      imagePath: imagePath ?? this.imagePath,
      stock: stock ?? this.stock,
      category: category ?? this.category,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      isActive: isActive ?? this.isActive,
      unit: unit ?? this.unit,
    );
  }

  // Calculate profit per unit
  int get profitPerUnit => price - costPrice;

  // Calculate total profit for given quantity
  int profitForQuantity(int quantity) => profitPerUnit * quantity;

  @override
  String toString() =>
      'Product(id: $id, name: $name, price: $price, costPrice: $costPrice)';
}
