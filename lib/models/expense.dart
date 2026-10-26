class Expense {
  final int? id;
  final String? userId;
  final double amount;
  final String category;
  final String paymentMethod;
  final String? comment;
  final int expenseDate; // Unix timestamp in milliseconds
  final int createdAt;
  final int updatedAt;

  Expense({
    this.id,
    this.userId,
    required this.amount,
    required this.category,
    required this.paymentMethod,
    this.comment,
    required this.expenseDate,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'amount': amount,
      'category': category,
      'payment_method': paymentMethod,
      'comment': comment,
      'expense_date': expenseDate,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
    if (userId != null) {
      map['user_id'] = userId;
    }
    return map;
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    final expDate = (map['expense_date'] as num).toInt();
    final created = map['created_at'] != null ? (map['created_at'] as num).toInt() : expDate;
    final updated = map['updated_at'] != null ? (map['updated_at'] as num).toInt() : created;

    return Expense(
      id: map['id'] is num ? (map['id'] as num).toInt() : (int.tryParse(map['id']?.toString() ?? '')),
      userId: map['user_id'] as String?,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String? ?? 'General',
      paymentMethod: map['payment_method'] as String? ?? 'UPI',
      comment: map['comment'] as String?,
      expenseDate: expDate,
      createdAt: created,
      updatedAt: updated,
    );
  }

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(expenseDate);

  Expense copyWith({
    int? id,
    String? userId,
    double? amount,
    String? category,
    String? paymentMethod,
    String? comment,
    int? expenseDate,
    int? createdAt,
    int? updatedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      comment: comment ?? this.comment,
      expenseDate: expenseDate ?? this.expenseDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
