class RecurringExpense {
  final int id;
  final String category;
  final String description;
  final int amount;
  final String frequency; // DAILY, WEEKLY, MONTHLY, YEARLY
  final DateTime startDate;
  final DateTime? endDate;
  final String paymentMethod;
  final String? note;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastGeneratedDate;

  RecurringExpense({
    required this.id,
    required this.category,
    required this.description,
    required this.amount,
    required this.frequency,
    required this.startDate,
    this.endDate,
    required this.paymentMethod,
    this.note,
    this.isActive = true,
    required this.createdAt,
    this.lastGeneratedDate,
  });

  // Convert to map for database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'description': description,
      'amount': amount,
      'frequency': frequency,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'paymentMethod': paymentMethod,
      'note': note,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'lastGeneratedDate': lastGeneratedDate?.toIso8601String(),
    };
  }

  // Convert to map for database insert (excludes id to allow auto-increment)
  Map<String, dynamic> toMapForInsert() {
    return {
      'category': category,
      'description': description,
      'amount': amount,
      'frequency': frequency,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'paymentMethod': paymentMethod,
      'note': note,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'lastGeneratedDate': lastGeneratedDate?.toIso8601String(),
    };
  }

  // Create from map
  factory RecurringExpense.fromMap(Map<String, dynamic> map) {
    return RecurringExpense(
      id: map['id'] ?? 0,
      category: map['category'] ?? '',
      description: map['description'] ?? '',
      amount: map['amount'] ?? 0,
      frequency: map['frequency'] ?? 'MONTHLY',
      startDate: DateTime.parse(map['startDate'] ?? DateTime.now().toIso8601String()),
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : null,
      paymentMethod: map['paymentMethod'] ?? 'Tiền mặt',
      note: map['note'],
      isActive: (map['isActive'] ?? 1) == 1,
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      lastGeneratedDate: map['lastGeneratedDate'] != null ? DateTime.parse(map['lastGeneratedDate']) : null,
    );
  }

  // Copy with modifications
  RecurringExpense copyWith({
    int? id,
    String? category,
    String? description,
    int? amount,
    String? frequency,
    DateTime? startDate,
    DateTime? endDate,
    String? paymentMethod,
    String? note,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastGeneratedDate,
  }) {
    return RecurringExpense(
      id: id ?? this.id,
      category: category ?? this.category,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      note: note ?? this.note,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastGeneratedDate: lastGeneratedDate ?? this.lastGeneratedDate,
    );
  }
}
