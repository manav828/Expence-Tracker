class Budget {
  final int? id;
  final String category;
  final double monthlyLimit;
  final int createdAt;
  final int updatedAt;

  Budget({
    this.id,
    required this.category,
    required this.monthlyLimit,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'monthly_limit': monthlyLimit,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory Budget.fromMap(Map<String, dynamic> map) {
    return Budget(
      id: map['id'],
      category: map['category'],
      monthlyLimit: (map['monthly_limit'] as num).toDouble(),
      createdAt: map['created_at'],
      updatedAt: map['updated_at'],
    );
  }

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
