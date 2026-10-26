// Models for the Split (Splitwise) feature

// ─── Group ────────────────────────────────────────────────────────────────────
class SplitGroup {
  final String id;
  final String name;
  final String? description;
  final String? imageUrl;
  final String createdBy;
  final String inviteCode;
  final DateTime createdAt;

  SplitGroup({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
    required this.createdBy,
    required this.inviteCode,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'description': description,
        'image_url': imageUrl,
        'created_by': createdBy,
        'invite_code': inviteCode,
        'created_at': createdAt.toIso8601String(),
      };

  factory SplitGroup.fromMap(Map<String, dynamic> m) => SplitGroup(
        id: m['id'] as String,
        name: m['name'] as String,
        description: m['description'] as String?,
        imageUrl: m['image_url'] as String?,
        createdBy: m['created_by'] as String,
        inviteCode: m['invite_code'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  SplitGroup copyWith({String? name, String? description, String? imageUrl}) => SplitGroup(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        imageUrl: imageUrl ?? this.imageUrl,
        createdBy: createdBy,
        inviteCode: inviteCode,
        createdAt: createdAt,
      );
}

// ─── Member ───────────────────────────────────────────────────────────────────
class SplitMember {
  final String id;
  final String groupId;
  final String name;
  final String? phone;
  final DateTime joinedAt;

  SplitMember({
    required this.id,
    required this.groupId,
    required this.name,
    this.phone,
    required this.joinedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'group_id': groupId,
        'name': name,
        'phone': phone,
        'joined_at': joinedAt.toIso8601String(),
      };

  factory SplitMember.fromMap(Map<String, dynamic> m) => SplitMember(
        id: m['id'] as String,
        groupId: m['group_id'] as String,
        name: m['name'] as String,
        phone: m['phone'] as String?,
        joinedAt: DateTime.parse(m['joined_at'] as String),
      );
}

// ─── Split Type ───────────────────────────────────────────────────────────────
enum SplitType { equal, unequal, percentage }

extension SplitTypeExt on SplitType {
  String get label {
    switch (this) {
      case SplitType.equal:
        return 'Equal';
      case SplitType.unequal:
        return 'Unequal';
      case SplitType.percentage:
        return 'Percentage';
    }
  }

  static SplitType fromString(String s) {
    switch (s) {
      case 'unequal':
        return SplitType.unequal;
      case 'percentage':
        return SplitType.percentage;
      default:
        return SplitType.equal;
    }
  }
}

// ─── Split Expense ────────────────────────────────────────────────────────────
class SplitExpense {
  final String id;
  final String groupId;
  final String title;
  final double totalAmount;
  final String paidByMemberId;
  final SplitType splitType;
  final String? category;
  final String? note;
  final String addedByMemberId;
  final DateTime createdAt;

  SplitExpense({
    required this.id,
    required this.groupId,
    required this.title,
    required this.totalAmount,
    required this.paidByMemberId,
    required this.splitType,
    this.category,
    this.note,
    required this.addedByMemberId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'group_id': groupId,
        'title': title,
        'total_amount': totalAmount,
        'paid_by_member_id': paidByMemberId,
        'split_type': splitType.name,
        'category': category,
        'note': note,
        'added_by_member_id': addedByMemberId,
        'created_at': createdAt.toIso8601String(),
      };

  factory SplitExpense.fromMap(Map<String, dynamic> m) => SplitExpense(
        id: m['id'] as String,
        groupId: m['group_id'] as String,
        title: m['title'] as String,
        totalAmount: (m['total_amount'] as num).toDouble(),
        paidByMemberId: m['paid_by_member_id'] as String,
        splitType: SplitTypeExt.fromString(m['split_type'] as String),
        category: m['category'] as String?,
        note: m['note'] as String?,
        addedByMemberId: m['added_by_member_id'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

// ─── Split Share ──────────────────────────────────────────────────────────────
class SplitShare {
  final String id;
  final String expenseId;
  final String memberId;
  final double shareAmount;
  bool isSettled;

  SplitShare({
    required this.id,
    required this.expenseId,
    required this.memberId,
    required this.shareAmount,
    this.isSettled = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'expense_id': expenseId,
        'member_id': memberId,
        'share_amount': shareAmount,
        'is_settled': isSettled,
      };

  Map<String, dynamic> toSqliteMap() => {
        'id': id,
        'expense_id': expenseId,
        'member_id': memberId,
        'share_amount': shareAmount,
        'is_settled': isSettled ? 1 : 0,
      };

  factory SplitShare.fromMap(Map<String, dynamic> m) => SplitShare(
        id: m['id'] as String,
        expenseId: m['expense_id'] as String,
        memberId: m['member_id'] as String,
        shareAmount: (m['share_amount'] as num).toDouble(),
        isSettled: m['is_settled'] is bool
            ? (m['is_settled'] as bool)
            : (m['is_settled'] == 1 || m['is_settled'] == 'true'),
      );
}

// ─── Settlement ───────────────────────────────────────────────────────────────
class Settlement {
  final String id;
  final String groupId;
  final String fromMemberId;
  final String toMemberId;
  final double amount;
  final DateTime settledAt;
  final String? note;

  Settlement({
    required this.id,
    required this.groupId,
    required this.fromMemberId,
    required this.toMemberId,
    required this.amount,
    required this.settledAt,
    this.note,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'group_id': groupId,
        'from_member_id': fromMemberId,
        'to_member_id': toMemberId,
        'amount': amount,
        'settled_at': settledAt.toIso8601String(),
        'note': note,
      };

  factory Settlement.fromMap(Map<String, dynamic> m) => Settlement(
        id: m['id'] as String,
        groupId: m['group_id'] as String,
        fromMemberId: m['from_member_id'] as String,
        toMemberId: m['to_member_id'] as String,
        amount: (m['amount'] as num).toDouble(),
        settledAt: DateTime.parse(m['settled_at'] as String),
        note: m['note'] as String?,
      );
}

// ─── Debt (result of simplification) ─────────────────────────────────────────
class Debt {
  final String fromMemberId;
  final String toMemberId;
  final double amount;

  Debt({
    required this.fromMemberId,
    required this.toMemberId,
    required this.amount,
  });
}

/// Debt simplification: given net balances (+ve = owed, -ve = owes),
/// returns the minimal list of transactions to settle everyone.
List<Debt> simplifyDebts(Map<String, double> balances) {
  final debts = <Debt>[];
  final creditors = <MapEntry<String, double>>[];
  final debtors = <MapEntry<String, double>>[];

  balances.forEach((id, bal) {
    final rounded = double.parse(bal.toStringAsFixed(2));
    if (rounded > 0.009) creditors.add(MapEntry(id, rounded));
    if (rounded < -0.009) debtors.add(MapEntry(id, rounded.abs()));
  });

  creditors.sort((a, b) => b.value.compareTo(a.value));
  debtors.sort((a, b) => b.value.compareTo(a.value));

  int c = 0, d = 0;
  while (c < creditors.length && d < debtors.length) {
    final credAmt = creditors[c].value;
    final debtAmt = debtors[d].value;
    final minAmt = credAmt < debtAmt ? credAmt : debtAmt;

    debts.add(Debt(
      fromMemberId: debtors[d].key,
      toMemberId: creditors[c].key,
      amount: double.parse(minAmt.toStringAsFixed(2)),
    ));

    creditors[c] = MapEntry(creditors[c].key, credAmt - minAmt);
    debtors[d] = MapEntry(debtors[d].key, debtAmt - minAmt);

    if (creditors[c].value < 0.009) c++;
    if (debtors[d].value < 0.009) d++;
  }

  return debts;
}
