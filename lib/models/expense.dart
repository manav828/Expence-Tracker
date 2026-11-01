/// Represents the financial flow direction of a personal transaction.
enum TransactionType {
  /// Debit or spending outflow
  expense,

  /// Credit or incoming earnings/refunds
  income;

  String toDbValue() => name;

  static TransactionType fromDbValue(String? value) {
    if (value == null) return TransactionType.expense;
    final normalized = value.toLowerCase().trim();
    if (normalized == 'income' || normalized == 'credit') {
      return TransactionType.income;
    }
    return TransactionType.expense;
  }
}

/// Represents an individual user transaction (expense/debit or income/credit) in ExpenCircle.
class Expense {
  /// Unique database identifier (auto-incremented integer for SQLite and BigInt for cloud DB).
  final int? id;

  /// Supabase auth user UID owning this personal transaction.
  final String? userId;

  /// Financial monetary value in INR (e.g. 250.00).
  final double amount;

  /// User-defined or preset category (e.g. 'Food', 'Salary', 'Shopping').
  final String category;

  /// Transaction instrument (e.g. 'UPI', 'Credit Card', 'Cash', 'NetBanking').
  final String paymentMethod;

  /// Optional remark, note, or merchant/payee name.
  final String? comment;

  /// Optional receipt or invoice image URL hosted on CDN.
  final String? receiptUrl;

  /// Transaction timestamp in milliseconds since Unix epoch.
  final int expenseDate;

  /// Record creation timestamp in milliseconds since Unix epoch.
  final int createdAt;

  /// Record last update timestamp in milliseconds since Unix epoch.
  final int updatedAt;

  /// Transaction flow type (expense/debit or income/credit). Defaults to expense.
  final TransactionType type;

  Expense({
    this.id,
    this.userId,
    required this.amount,
    required this.category,
    required this.paymentMethod,
    this.comment,
    this.receiptUrl,
    required this.expenseDate,
    required this.createdAt,
    required this.updatedAt,
    this.type = TransactionType.expense,
  });

  /// True if this transaction is an outflow/debit.
  bool get isExpense => type == TransactionType.expense;

  /// True if this transaction is an inflow/credit.
  bool get isIncome => type == TransactionType.income;

  /// Serializes the transaction to a key-value Map for SQLite or Supabase database operations.
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'amount': amount,
      'category': category,
      'payment_method': paymentMethod,
      'comment': comment,
      'receipt_url': receiptUrl,
      'expense_date': expenseDate,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'type': type.toDbValue(),
    };
    if (userId != null) {
      map['user_id'] = userId;
    }
    return map;
  }

  /// Deserializes a key-value Map safely into an [Expense] instance.
  factory Expense.fromMap(Map<String, dynamic> map) {
    final expDate = (map['expense_date'] as num).toInt();
    final created = map['created_at'] != null ? (map['created_at'] as num).toInt() : expDate;
    final updated = map['updated_at'] != null ? (map['updated_at'] as num).toInt() : created;
    final txType = TransactionType.fromDbValue(map['type'] as String?);

    return Expense(
      id: map['id'] is num ? (map['id'] as num).toInt() : (int.tryParse(map['id']?.toString() ?? '')),
      userId: map['user_id'] as String?,
      amount: (map['amount'] as num).toDouble(),
      category: map['category'] as String? ?? 'General',
      paymentMethod: map['payment_method'] as String? ?? 'UPI',
      comment: map['comment'] as String?,
      receiptUrl: map['receipt_url'] as String?,
      expenseDate: expDate,
      createdAt: created,
      updatedAt: updated,
      type: txType,
    );
  }

  /// Converts the Unix millisecond timestamp into a [DateTime] object.
  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(expenseDate);

  /// Creates a copy of this expense with replaced field values.
  Expense copyWith({
    int? id,
    String? userId,
    double? amount,
    String? category,
    String? paymentMethod,
    String? comment,
    String? receiptUrl,
    int? expenseDate,
    int? createdAt,
    int? updatedAt,
    TransactionType? type,
  }) {
    return Expense(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      comment: comment ?? this.comment,
      receiptUrl: receiptUrl ?? this.receiptUrl,
      expenseDate: expenseDate ?? this.expenseDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      type: type ?? this.type,
    );
  }
}
