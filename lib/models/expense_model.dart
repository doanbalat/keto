class Expense {
  final int id;
  final String category;
  final String description;
  final int amount;
  final DateTime timestamp;
  final String? receiptImagePath;
  final String? note;
  final String paymentMethod;

  Expense({
    required this.id,
    required this.category,
    required this.description,
    required this.amount,
    required this.timestamp,
    this.receiptImagePath,
    this.note,
    this.paymentMethod = 'Tiền mặt',
  });

  // Convert Expense to Map for database storage
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'category': category,
      'description': description,
      'amount': amount,
      'timestamp': timestamp.toIso8601String(),
      'receiptImagePath': receiptImagePath,
      'note': note,
      'paymentMethod': paymentMethod,
    };

    // Only include id if it's not 0 (0 means auto-generate)
    if (id != 0) {
      map['id'] = id;
    }

    return map;
  }

  // Create Expense from Map retrieved from database
  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int,
      category: map['category'] as String,
      description: map['description'] as String,
      amount: map['amount'] as int,
      timestamp: DateTime.parse(map['timestamp'] as String),
      receiptImagePath: map['receiptImagePath'] as String?,
      note: map['note'] as String?,
      paymentMethod: map['paymentMethod'] as String? ?? 'Tiền mặt',
    );
  }

  // Create a copy of Expense with modified fields
  Expense copyWith({
    int? id,
    String? category,
    String? description,
    int? amount,
    DateTime? timestamp,
    String? receiptImagePath,
    String? note,
    String? paymentMethod,
  }) {
    return Expense(
      id: id ?? this.id,
      category: category ?? this.category,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      timestamp: timestamp ?? this.timestamp,
      receiptImagePath: receiptImagePath ?? this.receiptImagePath,
      note: note ?? this.note,
      paymentMethod: paymentMethod ?? this.paymentMethod,
    );
  }

  @override
  String toString() =>
      'Expense(id: $id, category: $category, description: $description, amount: $amount)';
}
