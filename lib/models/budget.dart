/// Represents a category-specific monthly spending limit in ExpenCircle.
class Budget {
  /// Unique database identifier for the budget limit.
  final int? id;

  /// The spending category this budget safeguards (e.g. 'Food', 'Groceries').
  final String category;

  /// Monthly financial threshold in INR (e.g. 5000.0).
  final double monthlyLimit;

  /// Creation timestamp in milliseconds since Unix epoch.
  final int createdAt;

  /// Last modification timestamp in milliseconds since Unix epoch.
  final int updatedAt;

  Budget({
    this.id,
    required this.category,
    required this.monthlyLimit,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Serializes budget to database map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'monthly_limit': monthlyLimit,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  /// Deserializes database record map into a [Budget] instance.
  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'],
      category: map['category'],
      monthlyLimit: (map['monthly_limit'] as num).toDouble(),
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }

  /// Creates a copy of this budget with updated fields.
  Budget copyWith({
    int? id,
    String? category,
    double? monthlyLimit,
    int? createdAt,
    int? updatedAt,
  }) {
    return Budget(
      id: id ?? this.id,
      category: category ?? this.category,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
