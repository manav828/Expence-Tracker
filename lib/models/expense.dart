class Expense {
  final int? id;
  final double amount;
  final String category;
  final String paymentMethod;
  final String? comment;
  final int expenseDate; // Unix timestamp in milliseconds
  final int createdAt;
  final int updatedAt;

  Expense({
    this.id,
    required this.amount,
    required this.category,
    required this.paymentMethod,
    this.comment,
    required this.expenseDate,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'category': category,
      'payment_method': paymentMethod,
      'comment': comment,
      'expense_date': expenseDate,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      amount: map['amount'],
      category: map['category'],
      paymentMethod: map['payment_method'],
      comment: map['comment'],
      expenseDate: map['expense_date'],
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(expenseDate);

  Expense copyWith({
    int? id,
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
