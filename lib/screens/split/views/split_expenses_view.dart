import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/split_models.dart';
import '../../../providers/split_provider.dart';
import '../../../utils/category_icons.dart';
import '../../../widgets/receipt_attachment_sheet.dart';
import '../add_split_expense_sheet.dart';
import '../widgets/dashed_border_painter.dart';
import '../../../core/theme/app_colors.dart';


/// Screen 1: CheQ-style Trip Expenses View.
class SplitExpensesView extends StatelessWidget {
  final SplitGroup group;
  final VoidCallback onAddExpenseTap;
  final VoidCallback onSettleUpTap;
  final VoidCallback onEditGroupTap;
  final VoidCallback onShareInviteTap;
  final VoidCallback onTripModeTap;

  const SplitExpensesView({
    super.key,
    required this.group,
    required this.onAddExpenseTap,
    required this.onSettleUpTap,
    required this.onEditGroupTap,
    required this.onShareInviteTap,
    required this.onTripModeTap,
  });

  static const _charcoal = Color(0xFF1A1D1F);
  static const _muted = Color(0xFF6F767E);
  static const _cheqGreen = AppColors.primary;
  static const _cheqGreenDark = Color(0xFF008A4B);

  @override
  Widget build(BuildContext context) {
    return Consumer<SplitProvider>(
      builder: (context, sp, _) {
        final expenses = sp.getExpensesForGroup(group.id);
        final members = sp.getMembersForGroup(group.id);
        final memberMap = {for (final m in members) m.id: m.name};
        final currentMember = sp.getCurrentMemberForGroup(group.id) ?? members.firstOrNull ??
            SplitMember(id: '', groupId: group.id, name: 'You', joinedAt: DateTime.now());

        final combinedResult = sp.getCombinedBalancesResult(group.id);
        final isHousehold = combinedResult.memberToGroupMap.containsKey(currentMember.id);
        final netBalance = combinedResult.getSettlementBalanceForMember(currentMember.id);
        final statusAmount = '₹${netBalance.abs().toStringAsFixed(2)}';
        final netStatus = switch (netBalance) {
          > 0 => isHousehold ? 'Household is owed $statusAmount' : 'You are owed $statusAmount',
          < 0 => isHousehold ? 'Household owes $statusAmount' : 'You owe $statusAmount',
          _ => isHousehold ? 'Household net balance: ₹0.00' : 'All settled up!',
        };
        final totalSpend = expenses.fold(0.0, (sum, exp) => sum + exp.totalAmount);
        final fmt = NumberFormat('#,##,##0.00');

        final isTripActive = sp.isTripModeActive && sp.activeTripGroupId == group.id;

        // Group expenses by formatted date
        final Map<String, List<SplitExpense>> groupedExpenses = {};
        for (final exp in expenses) {
          final dateKey = _formatExpenseDateHeader(exp.createdAt);
          groupedExpenses.putIfAbsent(dateKey, () => []).add(exp);
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF6F7F9),
          body: RefreshIndicator(
            color: _cheqGreen,
            onRefresh: () => sp.loadGroupDetail(group.id),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // 1. Top Forest Teal Hero Header & Stitched CheQ Card
                SliverToBoxAdapter(
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0D3830), Color(0xFF114B40)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      16,
                      MediaQuery.of(context).padding.top + 8,
                      16,
                      22,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Nav: Back | Title & Tag | Actions
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 20),
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              constraints: const BoxConstraints(),
                              tooltip: 'Edit Group',
                              onPressed: onEditGroupTap,
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.share_outlined, color: Colors.white70, size: 20),
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              constraints: const BoxConstraints(),
                              tooltip: 'Share Invite',
                              onPressed: onShareInviteTap,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Group Title & TRIP GROUP Badge
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                group.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: onTripModeTap,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: isTripActive
                                      ? AppColors.primary.withValues(alpha: 0.25)
                                      : const Color(0xFF09423B).withValues(alpha: 0.7),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isTripActive ? const Color(0xFF4ADE80) : const Color(0xFF00E07A).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isTripActive) ...[
                                      const Icon(Icons.flight_takeoff_rounded, size: 11, color: Color(0xFF4ADE80)),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      isTripActive ? 'TRIP MODE ON' : 'TRIP GROUP',
                                      style: TextStyle(
                                        color: isTripActive ? const Color(0xFF4ADE80) : const Color(0xFF4CE088),
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // CheQ Stitched Card
                        Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            // Peeking back card layer
                            Positioned(
                              top: -6,
                              left: 12,
                              right: 12,
                              child: Container(
                                height: 30,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF105951), Color(0xFF166E63)],
                                  ),
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.25),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Main Stitched Card
                            Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF1D887A), Color(0xFF177569), Color(0xFF126359)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: const Color(0xFF2FA899).withValues(alpha: 0.4), width: 1.2),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF042824).withValues(alpha: 0.4),
                                    blurRadius: 28,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: CustomPaint(
                                painter: const DashedBorderPainter(
                                  color: Color(0x73FFFFFF),
                                  radius: 18,
                                  strokeWidth: 1.5,
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                                  child: Stack(
                                    children: [
                                      // Right Edge SIM Notch
                                      Positioned(
                                        right: -16,
                                        top: 18,
                                        child: Container(
                                          width: 24,
                                          height: 42,
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFF22998A), Color(0xFF167A6D)],
                                            ),
                                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
                                            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.18),
                                                blurRadius: 8,
                                                offset: const Offset(-2, 0),
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Container(
                                              width: 12,
                                              height: 12,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF0C4C44),
                                                shape: BoxShape.circle,
                                                border: Border.all(color: const Color(0xFF52D2BF).withValues(alpha: 0.6)),
                                              ),
                                              child: Center(
                                                child: Container(
                                                  width: 4,
                                                  height: 4,
                                                  decoration: const BoxDecoration(
                                                    color: Color(0xFF82ECD9),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),

                                      // Main Card Content
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Top Row: Available Balance + Members count
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                'Available Balance',
                                                style: TextStyle(
                                                  color: Color(0xFFE6F8F0),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                              Container(
                                                margin: const EdgeInsets.only(right: 16),
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF09423B).withValues(alpha: 0.6),
                                                  borderRadius: BorderRadius.circular(20),
                                                  border: Border.all(color: const Color(0xFF6EE7B7).withValues(alpha: 0.3)),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Container(
                                                      width: 6,
                                                      height: 6,
                                                      decoration: const BoxDecoration(
                                                        color: Color(0xFF00E07A),
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 5),
                                                    Text(
                                                      '${members.length} Members Split',
                                                      style: const TextStyle(
                                                        color: Color(0xFFD1FAE5),
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),

                                          // Big Hero Total Spend
                                          Text(
                                            '₹${fmt.format(totalSpend)}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 30,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: -0.6,
                                            ),
                                          ),
                                          const SizedBox(height: 8),

                                          // Net status pill
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0A3E37).withValues(alpha: 0.75),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(color: const Color(0xFF6EE7B7).withValues(alpha: 0.25)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 7,
                                                  height: 7,
                                                  decoration: BoxDecoration(
                                                    color: netBalance > 0
                                                        ? const Color(0xFF00E07A)
                                                        : (netBalance < 0 ? const Color(0xFFEF4444) : const Color(0xFF94A3B8)),
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Net status: $netStatus',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 14),

                                          // Quick action buttons inside card
                                          Row(
                                            children: [
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF00C96C),
                                                    foregroundColor: Colors.white,
                                                    elevation: 0,
                                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(20),
                                                    ),
                                                  ),
                                                  onPressed: onAddExpenseTap,
                                                  icon: const Icon(Icons.add_rounded, size: 16),
                                                  label: const Text(
                                                    'Add Expense',
                                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: ElevatedButton.icon(
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF00C96C),
                                                    foregroundColor: Colors.white,
                                                    elevation: 0,
                                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(20),
                                                    ),
                                                  ),
                                                  onPressed: onSettleUpTap,
                                                  icon: const Icon(Icons.call_made_rounded, size: 15),
                                                  label: const Text(
                                                    'Settle Up',
                                                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // 2. Body Content Sheet
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Promo Auto-Synced Banner
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE8FBF3), Color(0xFFE2F7ED)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFA7F3D0).withValues(alpha: 0.8)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Text(
                                          'Group Trip Balances ',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: _charcoal,
                                          ),
                                        ),
                                        Text(
                                          'Auto-Synced',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: _cheqGreenDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Text(
                                          '100% Free split calculator',
                                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                                        ),
                                        const SizedBox(width: 4),
                                        Container(
                                          width: 14,
                                          height: 14,
                                          decoration: const BoxDecoration(
                                            color: _cheqGreen,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.check, size: 10, color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF10B981), Color(0xFF34D399)],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '0%',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, height: 1.0),
                                    ),
                                    Text(
                                      'FEES',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 8, height: 1.2),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Quick Settle via UPI Row
                        InkWell(
                          onTap: onSettleUpTap,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFF1F5F9)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8FBF3),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFA7F3D0)),
                                  ),
                                  child: const Icon(Icons.qr_code_2_rounded, color: _cheqGreenDark, size: 22),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Pay & Settle Direct via UPI',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: _charcoal,
                                        ),
                                      ),
                                      SizedBox(height: 1),
                                      Text(
                                        'Instant settlement between group friends',
                                        style: TextStyle(fontSize: 11, color: _muted, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 22),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Trip Expenses Section Header
                        const Text(
                          'Trip Expenses',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _charcoal,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 3. Expenses List Feed (grouped by date)
                if (expenses.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
                      child: Center(
                        child: Column(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: const BoxDecoration(
                                color: Color(0xFFE8FBF3),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.receipt_long_outlined, size: 30, color: _cheqGreen),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No expenses yet',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: _charcoal),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Tap "+ Add Expense" to record your group spend',
                              style: TextStyle(fontSize: 12, color: _muted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, groupIndex) {
                          final dateKey = groupedExpenses.keys.elementAt(groupIndex);
                          final items = groupedExpenses[dateKey] ?? [];

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Date Header Divider
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Text(
                                      dateKey,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF94A3B8),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Divider(color: Color(0xFFE2E8F0), thickness: 1),
                                    ),
                                  ],
                                ),
                              ),

                              // Date Expenses
                              ...items.map((exp) => _buildCheqExpenseCard(
                                    context,
                                    exp,
                                    memberMap,
                                    members,
                                    currentMember.id,
                                    sp,
                                  )),
                            ],
                          );
                        },
                        childCount: groupedExpenses.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCheqExpenseCard(
    BuildContext context,
    SplitExpense expense,
    Map<String, String> memberMap,
    List<SplitMember> members,
    String currentUserId,
    SplitProvider sp,
  ) {
    final paidByName = memberMap[expense.paidByMemberId] ?? 'Member';
    final isPaidByMe = expense.paidByMemberId == currentUserId;
    final canEdit = sp.canManageExpense(expense);
    final fmt = NumberFormat('#,##0.00');

    // Calculate share info for the user
    final memberCount = members.isNotEmpty ? members.length : 1;
    final myShareAmount = expense.totalAmount / memberCount;

    Color themeColor;
    final categoryIcon = CategoryIcons.get(expense.title);
    final lowerTitle = expense.title.toLowerCase();

    if (lowerTitle.contains('hotel') || lowerTitle.contains('stay') || lowerTitle.contains('resort') || lowerTitle.contains('room')) {
      themeColor = const Color(0xFF4F46E5);
    } else if (lowerTitle.contains('cab') || lowerTitle.contains('uber') || lowerTitle.contains('ola') || lowerTitle.contains('taxi') || lowerTitle.contains('petrol')) {
      themeColor = const Color(0xFF059669);
    } else if (lowerTitle.contains('food') || lowerTitle.contains('dinner') || lowerTitle.contains('lunch') || lowerTitle.contains('cafe') || lowerTitle.contains('restaurant')) {
      themeColor = const Color(0xFFD97706);
    } else if (lowerTitle.contains('shopping') || lowerTitle.contains('mall') || lowerTitle.contains('market')) {
      themeColor = const Color(0xFFEA580C);
    } else {
      themeColor = _cheqGreenDark;
    }

    return Dismissible(
      key: Key(expense.id),
      direction: canEdit ? DismissDirection.endToStart : DismissDirection.none,
      confirmDismiss: (_) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Delete Expense?'),
            content: Text('Are you sure you want to delete "${expense.title}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFBA1A1A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        if (confirmed == true && context.mounted) {
          try {
            await sp.deleteExpense(group.id, expense.id);
          } catch (_) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Could not delete this expense.')),
              );
            }
          }
        }
        return false;
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFF1F5F9)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.025),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: !canEdit ? null : () async {
              await showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => AddSplitExpenseSheet(
                  groupId: group.id,
                  members: members,
                  expenseToEdit: expense,
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Category Icon
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: themeColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: themeColor.withValues(alpha: 0.2)),
                    ),
                    child: Center(
                      child: Icon(categoryIcon, color: themeColor, size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Title & Paid By
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expense.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: _charcoal,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            const Text(
                              'Paid by ',
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                            ),
                            if (isPaidByMe)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8FBF3),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'You',
                                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _cheqGreenDark),
                                ),
                              )
                            else
                              Text(
                                paidByName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                          ],
                        ),
                        if (expense.receiptUrl != null && expense.receiptUrl!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          GestureDetector(
                            onTap: () => FullScreenReceiptViewer.show(
                              context,
                              imageUrl: expense.receiptUrl!,
                              title: expense.title,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.receipt_long, size: 11, color: AppColors.primary),
                                  SizedBox(width: 3),
                                  Text(
                                    'Bill Attached',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Amount & Share Pill
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${fmt.format(expense.totalAmount)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: _charcoal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (isPaidByMe)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8FBF3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'You are owed: ₹${(expense.totalAmount - myShareAmount).toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _cheqGreenDark),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDF2F2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'You owe: ₹${myShareAmount.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFDC2626)),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatExpenseDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final itemDate = DateTime(date.year, date.month, date.day);

    if (itemDate == today) {
      return 'Today, ${DateFormat('d MMM').format(date)}';
    } else if (itemDate == yesterday) {
      return 'Yesterday, ${DateFormat('d MMM').format(date)}';
    } else {
      return DateFormat('d MMM yyyy').format(date);
    }
  }
}
