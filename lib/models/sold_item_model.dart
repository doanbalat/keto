import 'product_model.dart';

class SoldItem {
  final int id;
  final int productId; // Foreign key to Product
  final int quantity;
  final DateTime timestamp;
  final int totalPrice; // Pre-calculated total (quantity × price)
  final String paymentMethod; // "Tiền mặt", "Chuyển khoản", "Thẻ"
  final int discount; // Discount amount in VND
  final String? note; // Additional notes about the sale
  final String? customerName; // Optional customer name
  final Product? product; // Optional Product object (for UI display)

  SoldItem({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.timestamp,
    required this.totalPrice,
    this.paymentMethod = 'Tiền mặt',
    this.discount = 0,
    this.note,
    this.customerName,
    this.product,
  });

  // Convert SoldItem to Map for database storage
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'productId': productId,
      'quantity': quantity,
      'timestamp': timestamp.toIso8601String(),
      'totalPrice': totalPrice,
      'paymentMethod': paymentMethod,
      'discount': discount,
      'note': note,
      'customerName': customerName,
    };

    // Only include id if it's not 0 (0 means auto-generate)
    if (id != 0) {
      map['id'] = id;
    }

    return map;
  }

  // Create SoldItem from Map retrieved from database
  factory SoldItem.fromMap(Map<String, dynamic> map, {Product? product}) {
    return SoldItem(
      id: map['id'] as int,
      productId: map['productId'] as int,
      quantity: map['quantity'] as int,
      timestamp: DateTime.parse(map['timestamp'] as String),
      totalPrice: map['totalPrice'] as int,
      paymentMethod: map['paymentMethod'] as String? ?? 'Tiền mặt',
      discount: map['discount'] as int? ?? 0,
      note: map['note'] as String?,
      customerName: map['customerName'] as String?,
      product: product,
    );
  }

  // Create a copy of SoldItem with modified fields
  SoldItem copyWith({
    int? id,
    int? productId,
    int? quantity,
    DateTime? timestamp,
    int? totalPrice,
    String? paymentMethod,
    int? discount,
    String? note,
    String? customerName,
    Product? product,
  }) {
    return SoldItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      timestamp: timestamp ?? this.timestamp,
      totalPrice: totalPrice ?? this.totalPrice,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      discount: discount ?? this.discount,
      note: note ?? this.note,
      customerName: customerName ?? this.customerName,
      product: product ?? this.product,
    );
  }

  // Calculate actual price paid after discount
  int get priceAfterDiscount => totalPrice - discount;

  @override
  String toString() =>
      'SoldItem(id: $id, productId: $productId, quantity: $quantity, totalPrice: $totalPrice)';
}
