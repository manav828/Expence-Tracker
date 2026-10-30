// Models for the Split (Splitwise) feature

// ─── Group ────────────────────────────────────────────────────────────────────
class SplitGroup {
  final String id;
  final String? userId;
  final String name;
  final String? description;
  final String? imageUrl;
  final String createdBy;
  final String inviteCode;
  final DateTime createdAt;

  SplitGroup({
    required this.id,
    this.userId,
    required this.name,
    this.description,
    this.imageUrl,
    required this.createdBy,
    required this.inviteCode,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'user_id': userId,
        'name': name,
        'description': description,
        'image_url': imageUrl,
        'created_by': createdBy,
        'invite_code': inviteCode,
        'created_at': createdAt.toIso8601String(),
      };

  factory SplitGroup.fromMap(Map<String, dynamic> m) => SplitGroup(
        id: m['id'] as String,
        userId: m['user_id'] as String?,
        name: m['name'] as String,
        description: m['description'] as String?,
        imageUrl: m['image_url'] as String?,
        createdBy: m['created_by'] as String,
        inviteCode: m['invite_code'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  SplitGroup copyWith({
    String? name,
    String? description,
    String? imageUrl,
    String? userId,
  }) => SplitGroup(
        id: id,
        userId: userId ?? this.userId,
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
  final String? userId;
  final String name;
  final String? phone;
  final DateTime joinedAt;

  SplitMember({
    required this.id,
    required this.groupId,
    this.userId,
    required this.name,
    this.phone,
    required this.joinedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'group_id': groupId,
        'user_id': userId,
        'name': name,
        'phone': phone,
        'joined_at': joinedAt.toIso8601String(),
      };

  factory SplitMember.fromMap(Map<String, dynamic> m) => SplitMember(
        id: m['id'] as String,
        groupId: m['group_id'] as String,
        userId: m['user_id'] as String?,
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
  final String? receiptUrl;
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
    this.receiptUrl,
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
        'receipt_url': receiptUrl,
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
        receiptUrl: m['receipt_url'] as String?,
        addedByMemberId: m['added_by_member_id'] as String,
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  SplitExpense copyWith({
    String? title,
    double? totalAmount,
    String? paidByMemberId,
    SplitType? splitType,
    String? category,
    String? note,
    String? receiptUrl,
    String? addedByMemberId,
  }) =>
      SplitExpense(
        id: id,
        groupId: groupId,
        title: title ?? this.title,
        totalAmount: totalAmount ?? this.totalAmount,
        paidByMemberId: paidByMemberId ?? this.paidByMemberId,
        splitType: splitType ?? this.splitType,
        category: category ?? this.category,
        note: note ?? this.note,
        receiptUrl: receiptUrl ?? this.receiptUrl,
        addedByMemberId: addedByMemberId ?? this.addedByMemberId,
        createdAt: createdAt,
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
  final String? fromSettlementGroupId;
  final String? toSettlementGroupId;

  Settlement({
    required this.id,
    required this.groupId,
    required this.fromMemberId,
    required this.toMemberId,
    required this.amount,
    required this.settledAt,
    this.note,
    this.fromSettlementGroupId,
    this.toSettlementGroupId,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'group_id': groupId,
        'from_member_id': fromMemberId,
        'to_member_id': toMemberId,
        'amount': amount,
        'settled_at': settledAt.toIso8601String(),
        'note': note,
        'from_settlement_group_id': fromSettlementGroupId,
        'to_settlement_group_id': toSettlementGroupId,
      };

  factory Settlement.fromMap(Map<String, dynamic> m) => Settlement(
        id: m['id'] as String,
        groupId: m['group_id'] as String,
        fromMemberId: m['from_member_id'] as String,
        toMemberId: m['to_member_id'] as String,
        amount: (m['amount'] as num).toDouble(),
        settledAt: DateTime.parse(m['settled_at'] as String),
        note: m['note'] as String?,
        fromSettlementGroupId: m['from_settlement_group_id'] as String?,
        toSettlementGroupId: m['to_settlement_group_id'] as String?,
      );
}

// ─── Module A: Expense Member Group ───────────────────────────────────────────
class SplitExpenseGroup {
  final String id;
  final String groupId;
  final String name;
  final String? description;
  final String? icon;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> memberIds;

  SplitExpenseGroup({
    required this.id,
    required this.groupId,
    required this.name,
    this.description,
    this.icon,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.memberIds = const [],
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'group_id': groupId,
        'name': name,
        'description': description,
        'icon': icon,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory SplitExpenseGroup.fromMap(Map<String, dynamic> m, {List<String>? memberIds}) =>
      SplitExpenseGroup(
        id: m['id'] as String,
        groupId: m['group_id'] as String,
        name: m['name'] as String,
        description: m['description'] as String?,
        icon: m['icon'] as String?,
        createdBy: m['created_by'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse((m['updated_at'] ?? m['created_at']) as String),
        memberIds: memberIds ??
            (m['member_ids'] is List
                ? (m['member_ids'] as List).map((e) => e.toString()).toList()
                : const []),
      );

  SplitExpenseGroup copyWith({
    String? name,
    String? description,
    String? icon,
    List<String>? memberIds,
    DateTime? updatedAt,
  }) =>
      SplitExpenseGroup(
        id: id,
        groupId: groupId,
        name: name ?? this.name,
        description: description ?? this.description,
        icon: icon ?? this.icon,
        createdBy: createdBy,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        memberIds: memberIds ?? this.memberIds,
      );
}

// ─── Module B: Combined Settlement Group ──────────────────────────────────────
class SplitSettlementGroup {
  final String id;
  final String groupId;
  final String name;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> memberIds;

  SplitSettlementGroup({
    required this.id,
    required this.groupId,
    required this.name,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.memberIds = const [],
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'group_id': groupId,
        'name': name,
        'created_by': createdBy,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory SplitSettlementGroup.fromMap(Map<String, dynamic> m, {List<String>? memberIds}) =>
      SplitSettlementGroup(
        id: m['id'] as String,
        groupId: m['group_id'] as String,
        name: m['name'] as String,
        createdBy: m['created_by'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
        updatedAt: DateTime.parse((m['updated_at'] ?? m['created_at']) as String),
        memberIds: memberIds ??
            (m['member_ids'] is List
                ? (m['member_ids'] as List).map((e) => e.toString()).toList()
                : const []),
      );

  SplitSettlementGroup copyWith({
    String? name,
    List<String>? memberIds,
    DateTime? updatedAt,
  }) =>
      SplitSettlementGroup(
        id: id,
        groupId: groupId,
        name: name ?? this.name,
        createdBy: createdBy,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        memberIds: memberIds ?? this.memberIds,
      );
}

// ─── Debt (result of simplification or pairwise) ─────────────────────────────
class Debt {
  final String fromMemberId;
  final String toMemberId;
  final double amount;
  final String? fromSettlementGroupId;
  final String? toSettlementGroupId;
  final String? fromGroupName;
  final String? toGroupName;
  final List<String>? fromGroupMemberIds;
  final List<String>? toGroupMemberIds;

  Debt({
    required this.fromMemberId,
    required this.toMemberId,
    required this.amount,
    this.fromSettlementGroupId,
    this.toSettlementGroupId,
    this.fromGroupName,
    this.toGroupName,
    this.fromGroupMemberIds,
    this.toGroupMemberIds,
  });

  bool get isFromGroup => fromSettlementGroupId != null;
  bool get isToGroup => toSettlementGroupId != null;
}

// ─── Combined Balances Aggregation Result ────────────────────────────────────
class CombinedBalancesResult {
  final Map<String, double> entityBalances;
  final Map<String, double> individualBalances;
  final Map<String, SplitSettlementGroup> settlementGroupMap;
  final Map<String, SplitSettlementGroup> memberToGroupMap;

  CombinedBalancesResult({
    required this.entityBalances,
    required this.individualBalances,
    required this.settlementGroupMap,
    required this.memberToGroupMap,
  });

  /// Returns the combined balance of a specific settlement group
  double getGroupBalance(String settlementGroupId) {
    return entityBalances['sg_$settlementGroupId'] ?? 0.0;
  }
}

/// Aggregates individual balances into combined settlement group balances.
/// An individual member can belong to at most one active settlement group.
CombinedBalancesResult aggregateCombinedBalances({
  required Map<String, double> individualBalances,
  required List<SplitSettlementGroup> settlementGroups,
}) {
  final memberToGroupMap = <String, SplitSettlementGroup>{};
  final settlementGroupMap = <String, SplitSettlementGroup>{};

  for (final sg in settlementGroups) {
    settlementGroupMap['sg_${sg.id}'] = sg;
    for (final mid in sg.memberIds) {
      memberToGroupMap[mid] = sg;
    }
  }

  final entityBalances = <String, double>{};

  // 1. Grouped members: calculate sum of individual balances for each settlement group
  for (final sg in settlementGroups) {
    double sum = 0.0;
    for (final mid in sg.memberIds) {
      sum += (individualBalances[mid] ?? 0.0);
    }
    entityBalances['sg_${sg.id}'] = double.parse(sum.toStringAsFixed(2));
  }

  // 2. Ungrouped members: keep their individual balances
  individualBalances.forEach((mid, bal) {
    if (!memberToGroupMap.containsKey(mid)) {
      entityBalances[mid] = double.parse(bal.toStringAsFixed(2));
    }
  });

  return CombinedBalancesResult(
    entityBalances: entityBalances,
    individualBalances: Map.unmodifiable(individualBalances),
    settlementGroupMap: settlementGroupMap,
    memberToGroupMap: memberToGroupMap,
  );
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

/// Direct (unsimplified) pairwise debts:
/// Calculates direct who-owes-whom balances based purely on pairwise expenses and settlements,
/// without rerouting payments through intermediaries.
List<Debt> calculateDirectDebts({
  required List<SplitExpense> expenses,
  required List<SplitShare> shares,
  required List<Settlement> settlements,
}) {
  if (expenses.isEmpty && settlements.isEmpty) return [];

  // Map of expenseId -> SplitExpense for quick lookup
  final expMap = {for (final e in expenses) e.id: e};

  // pairwiseOwed[debtorId][creditorId] = amount debtor owes creditor
  final pairwiseOwed = <String, Map<String, double>>{};

  void addDebt(String debtor, String creditor, double amount) {
    if (debtor == creditor || amount == 0) return;
    pairwiseOwed.putIfAbsent(debtor, () => {});
    pairwiseOwed[debtor]![creditor] = (pairwiseOwed[debtor]![creditor] ?? 0.0) + amount;
  }

  // 1. Accumulate pairwise debts from expense shares
  for (final share in shares) {
    final exp = expMap[share.expenseId];
    if (exp == null) continue;
    final payerId = exp.paidByMemberId;
    final consumerId = share.memberId;
    if (consumerId != payerId && share.shareAmount > 0) {
      addDebt(consumerId, payerId, share.shareAmount);
    }
  }

  // 2. Reduce pairwise debts when settlements occur between members
  for (final s in settlements) {
    // fromMemberId paid toMemberId, reducing fromMemberId's debt to toMemberId
    addDebt(s.fromMemberId, s.toMemberId, -s.amount);
  }

  // 3. Net between every unique pair of members
  final debts = <Debt>[];
  final allMembers = <String>{};
  for (final d in pairwiseOwed.keys) {
    allMembers.add(d);
    allMembers.addAll(pairwiseOwed[d]!.keys);
  }

  final memberList = allMembers.toList()..sort();
  for (int i = 0; i < memberList.length; i++) {
    for (int j = i + 1; j < memberList.length; j++) {
      final a = memberList[i];
      final b = memberList[j];
      final aOwesB = pairwiseOwed[a]?[b] ?? 0.0;
      final bOwesA = pairwiseOwed[b]?[a] ?? 0.0;
      final net = double.parse((aOwesB - bOwesA).toStringAsFixed(2));

      if (net > 0.009) {
        debts.add(Debt(fromMemberId: a, toMemberId: b, amount: net));
      } else if (net < -0.009) {
        debts.add(Debt(fromMemberId: b, toMemberId: a, amount: net.abs()));
      }
    }
  }

  // Sort descending by amount for clean presentation
  debts.sort((x, y) => y.amount.compareTo(x.amount));
  return debts;
}

/// Debt simplification with Combined Settlement Groups:
/// Virtual participants representing settlement groups take the place of individual members,
/// minimizing total transactions for the whole group.
List<Debt> simplifyDebtsWithGroups({
  required Map<String, double> individualBalances,
  required List<SplitSettlementGroup> settlementGroups,
}) {
  if (settlementGroups.isEmpty) {
    return simplifyDebts(individualBalances);
  }

  final aggregated = aggregateCombinedBalances(
    individualBalances: individualBalances,
    settlementGroups: settlementGroups,
  );

  final debts = <Debt>[];
  final creditors = <MapEntry<String, double>>[];
  final debtors = <MapEntry<String, double>>[];

  aggregated.entityBalances.forEach((id, bal) {
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

    final debtorKey = debtors[d].key;
    final creditorKey = creditors[c].key;

    final fromGroup = aggregated.settlementGroupMap[debtorKey];
    final toGroup = aggregated.settlementGroupMap[creditorKey];

    debts.add(Debt(
      fromMemberId: fromGroup != null && fromGroup.memberIds.isNotEmpty
          ? fromGroup.memberIds.first
          : debtorKey,
      toMemberId: toGroup != null && toGroup.memberIds.isNotEmpty
          ? toGroup.memberIds.first
          : creditorKey,
      amount: double.parse(minAmt.toStringAsFixed(2)),
      fromSettlementGroupId: fromGroup?.id,
      toSettlementGroupId: toGroup?.id,
      fromGroupName: fromGroup?.name,
      toGroupName: toGroup?.name,
      fromGroupMemberIds: fromGroup?.memberIds,
      toGroupMemberIds: toGroup?.memberIds,
    ));

    creditors[c] = MapEntry(creditors[c].key, credAmt - minAmt);
    debtors[d] = MapEntry(debtors[d].key, debtAmt - minAmt);

    if (creditors[c].value < 0.009) c++;
    if (debtors[d].value < 0.009) d++;
  }

  return debts;
}

/// Direct debts with Combined Settlement Groups:
/// Merges pairwise debts across settlement group boundaries while canceling internal group debts.
List<Debt> calculateDirectDebtsWithGroups({
  required List<SplitExpense> expenses,
  required List<SplitShare> shares,
  required List<Settlement> settlements,
  required List<SplitSettlementGroup> settlementGroups,
}) {
  final directDebts = calculateDirectDebts(
    expenses: expenses,
    shares: shares,
    settlements: settlements,
  );

  if (settlementGroups.isEmpty) {
    return directDebts;
  }

  final memberToGroup = <String, SplitSettlementGroup>{};
  final settlementGroupMap = <String, SplitSettlementGroup>{};
  for (final sg in settlementGroups) {
    settlementGroupMap['sg_${sg.id}'] = sg;
    for (final mid in sg.memberIds) {
      memberToGroup[mid] = sg;
    }
  }

  final entityPairwise = <String, Map<String, double>>{};

  for (final d in directDebts) {
    final fromGroup = memberToGroup[d.fromMemberId];
    final toGroup = memberToGroup[d.toMemberId];

    final fromEntityId = fromGroup != null ? 'sg_${fromGroup.id}' : d.fromMemberId;
    final toEntityId = toGroup != null ? 'sg_${toGroup.id}' : d.toMemberId;

    if (fromEntityId == toEntityId) {
      // Internal to the same settlement group
      continue;
    }

    entityPairwise.putIfAbsent(fromEntityId, () => {});
    entityPairwise[fromEntityId]![toEntityId] =
        (entityPairwise[fromEntityId]![toEntityId] ?? 0.0) + d.amount;
  }

  final allEntities = <String>{};
  for (final k in entityPairwise.keys) {
    allEntities.add(k);
    allEntities.addAll(entityPairwise[k]!.keys);
  }

  final entityList = allEntities.toList()..sort();
  final debts = <Debt>[];

  for (int i = 0; i < entityList.length; i++) {
    for (int j = i + 1; j < entityList.length; j++) {
      final a = entityList[i];
      final b = entityList[j];
      final aOwesB = entityPairwise[a]?[b] ?? 0.0;
      final bOwesA = entityPairwise[b]?[a] ?? 0.0;
      final net = double.parse((aOwesB - bOwesA).toStringAsFixed(2));

      if (net.abs() <= 0.009) continue;

      final debtorKey = net > 0 ? a : b;
      final creditorKey = net > 0 ? b : a;
      final amount = net.abs();

      final fromGroup = settlementGroupMap[debtorKey];
      final toGroup = settlementGroupMap[creditorKey];

      debts.add(Debt(
        fromMemberId: fromGroup != null && fromGroup.memberIds.isNotEmpty
            ? fromGroup.memberIds.first
            : debtorKey,
        toMemberId: toGroup != null && toGroup.memberIds.isNotEmpty
            ? toGroup.memberIds.first
            : creditorKey,
        amount: amount,
        fromSettlementGroupId: fromGroup?.id,
        toSettlementGroupId: toGroup?.id,
        fromGroupName: fromGroup?.name,
        toGroupName: toGroup?.name,
        fromGroupMemberIds: fromGroup?.memberIds,
        toGroupMemberIds: toGroup?.memberIds,
      ));
    }
  }

  debts.sort((x, y) => y.amount.compareTo(x.amount));
  return debts;
}

