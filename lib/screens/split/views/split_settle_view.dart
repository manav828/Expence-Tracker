import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../models/split_models.dart';
import '../../../providers/split_provider.dart';
import '../settle_up_screen.dart';
import '../widgets/dashed_border_painter.dart';
import '../widgets/settlement_celebration_modal.dart';
import '../widgets/slide_to_pay_track.dart';

/// Screen 2: CheQ Wallet & Balances / Settle Screen
/// Pixel-accurate implementation matching `screen\split\settlement_screen\settilement_screen.html`.
class SplitSettleView extends StatefulWidget {
  final SplitGroup group;
  final VoidCallback onAddExpenseTap;
  final VoidCallback onBackTap;
  final VoidCallback onSettingsTap;

  const SplitSettleView({
    super.key,
    required this.group,
    required this.onAddExpenseTap,
    required this.onBackTap,
    required this.onSettingsTap,
  });

  @override
  State<SplitSettleView> createState() => _SplitSettleViewState();
}

class _SplitSettleViewState extends State<SplitSettleView> {
  final Set<String> _expandedGroupIds = {};

  static const _brandDark = Color(0xFF13353B);
  static const _walletTeal = Color(0xFF1C6961);
  static const _walletBack = Color(0xFF165750);
  static const _primaryGreen = Color(0xFF00B865);
  static const _mintBadge = Color(0xFF4ADE80);
  static const _mintBg = Color(0xFFE6F8F0);

  final List<Color> _avatarColors = const [
    Color(0xFF13353B),
    Color(0xFF1C6961),
    Color(0xFF0F766E),
    Color(0xFF475569),
    Color(0xFF334155),
    Color(0xFF1E293B),
  ];

  Color _getAvatarColor(int index) {
    return _avatarColors[index % _avatarColors.length];
  }

  void _showSimplifyInfoModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _mintBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.sync_alt_rounded, color: Color(0xFF008A4B), size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Debt Simplification',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        'How it works in ExpenCircle',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Debt simplification automatically re-routes payments between group members to minimize total transactions without changing anyone\'s net balance.',
              style: TextStyle(fontSize: 13.5, color: Color(0xFF334155), height: 1.5),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Example:',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF0F172A)),
                  ),
                  SizedBox(height: 6),
                  Text(
                    '• A owes B ₹500\n• B owes C ₹500\n→ Simplified: A pays C ₹500 directly (1 payment instead of 2).',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Got It', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sendReminder(BuildContext context, String fromName, String toName, double amount) {
    final text = 'Hi $fromName, a quick reminder from our "${widget.group.name}" split group: pending payment of ₹${amount.toStringAsFixed(2)} to $toName. You can settle it anytime on ExpenCircle!';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment reminder for $fromName copied to clipboard!'),
        backgroundColor: _brandDark,
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'OK',
          textColor: _mintBadge,
          onPressed: () {},
        ),
      ),
    );
  }

  void _requestViaUpi(BuildContext context, String fromName, double amount) {
    final upiUrl = 'upi://pay?pn=ExpenCircle&am=${amount.toStringAsFixed(2)}&tn=${Uri.encodeComponent("Split payment for ${widget.group.name}")}';
    final shareMsg = 'Hi $fromName, please settle ₹${amount.toStringAsFixed(2)} for our "${widget.group.name}" group via UPI: $upiUrl';
    Clipboard.setData(ClipboardData(text: shareMsg));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('UPI payment request for ₹${amount.toStringAsFixed(2)} copied to clipboard!'),
        backgroundColor: _primaryGreen,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SplitProvider>(
      builder: (context, sp, _) {
        final members = sp.getMembersForGroup(widget.group.id);
        final balances = sp.getBalancesForGroup(widget.group.id);
        final isSimplified = sp.isSimplifyDebtsEnabled(widget.group.id);
        final directDebts = sp.getDebtsForGroup(widget.group.id, forceSimplify: false);
        final simplifiedDebts = sp.getDebtsForGroup(widget.group.id, forceSimplify: true);
        final debts = isSimplified ? simplifiedDebts : directDebts;
        final savingsCount = directDebts.length - simplifiedDebts.length;
        final memberMap = {for (final m in members) m.id: m.name};
        final expenses = sp.getExpensesForGroup(widget.group.id);
        final settlements = sp.getSettlementsForGroup(widget.group.id);
        final hasUnsettled = debts.isNotEmpty || balances.values.any((b) => b.abs() >= 0.01);
        final settlementGroups = sp.getSettlementGroupsForGroup(widget.group.id);
        final combinedResult = sp.getCombinedBalancesResult(widget.group.id);
        final activeSettlementGroups = settlementGroups.where((sg) {
          return combinedResult.getGroupBalance(sg.id).abs() >= 0.01;
        }).toList();

        final currentMemberName = sp.currentMemberName ?? '';
        final currentMember = members.firstWhere(
          (m) => m.name.toLowerCase().trim() == currentMemberName.toLowerCase().trim(),
          orElse: () => members.isNotEmpty ? members.first : SplitMember(id: '', groupId: widget.group.id, name: 'You', joinedAt: DateTime.now()),
        );

        final userNet = currentMember.id.isNotEmpty ? (balances[currentMember.id] ?? 0.0) : 0.0;
        final fmt = NumberFormat('#,##,##0.00');

        // Calculate total amount user is owed and user owes others
        double userOwed = 0.0;
        double userOwes = 0.0;
        for (final d in debts) {
          if (d.toMemberId == currentMember.id) {
            userOwed += d.amount;
          } else if (d.fromMemberId == currentMember.id) {
            userOwes += d.amount;
          }
        }

        // Categorize debts:
        final incomingDebts = debts.where((d) => d.toMemberId == currentMember.id).toList();
        final outgoingDebts = debts.where((d) => d.fromMemberId == currentMember.id).toList();
        final otherDebts = debts.where((d) => d.toMemberId != currentMember.id && d.fromMemberId != currentMember.id).toList();

        return Scaffold(
          backgroundColor: const Color(0xFFF5F8F7),
          body: RefreshIndicator(
            onRefresh: () async {
              await sp.loadGroupDetail(widget.group.id);
            },
            color: _primaryGreen,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // Top Dark Forest Teal Hero Section with CheQ Wallet Hero Card
                SliverToBoxAdapter(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: _brandDark,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top App Bar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: widget.onBackTap,
                              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: widget.onSettingsTap,
                                  icon: const Icon(Icons.settings_outlined, color: Colors.white70, size: 22),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 14),
                                IconButton(
                                  onPressed: () => _showSimplifyInfoModal(context),
                                  icon: const Icon(Icons.help_outline_rounded, color: Colors.white70, size: 22),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Title & Group Issuer Pill
                        Row(
                          children: [
                            const Text(
                              'ExpenCircle',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'GROUP',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white.withValues(alpha: 0.6),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.group.name.toLowerCase(),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: _mintBadge,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // CHEQ WALLET HERO CARD
                        _buildWalletHeroCard(
                          context,
                          userNet: userNet,
                          userOwed: userOwed,
                          userOwes: userOwes,
                          isSimplified: isSimplified,
                          fmt: fmt,
                        ),
                      ],
                    ),
                  ),
                ),

                // Main Scrollable Content Area
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // 1. Debt Simplification Toggle Section
                      if (hasUnsettled && members.length > 1 && directDebts.isNotEmpty) ...[
                        _buildDebtSimplificationCard(
                          isSimplified: isSimplified,
                          directCount: directDebts.length,
                          simplifiedCount: simplifiedDebts.length,
                          savingsCount: savingsCount > 0 ? savingsCount : 0,
                          onToggle: (val) => sp.setSimplifyDebts(widget.group.id, val),
                          onInfoTap: () => _showSimplifyInfoModal(context),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // 2. Unsettled Empty State vs Active Settlements
                      if (!hasUnsettled) ...[
                        _buildAllSettledUpState(expenses.isEmpty),
                      ] else ...[
                        // SECTION A: "Your Action Required" (Incoming Debts)
                        if (incomingDebts.isNotEmpty) ...[
                          _buildSectionHeader(
                            title: 'Your Action Required',
                            badge: '${incomingDebts.length} Pending',
                            badgeColor: const Color(0xFFDCFCE7),
                            badgeTextColor: const Color(0xFF166534),
                          ),
                          const SizedBox(height: 8),
                          ...incomingDebts.map((debt) {
                            final fromName = memberMap[debt.fromMemberId] ?? 'Member';
                            return _buildIncomingDebtCard(
                              context,
                              debt: debt,
                              fromName: fromName,
                              memberMap: memberMap,
                              sp: sp,
                              fmt: fmt,
                            );
                          }),
                          const SizedBox(height: 16),
                        ],

                        // SECTION B: "Pending Dues to Pay" (Outgoing Debts with Slide to Pay)
                        if (outgoingDebts.isNotEmpty) ...[
                          _buildSectionHeader(
                            title: 'Pending Dues to Pay',
                            badge: '${outgoingDebts.length} Due',
                            badgeColor: const Color(0xFFFEF3C7),
                            badgeTextColor: const Color(0xFF92400E),
                          ),
                          const SizedBox(height: 8),
                          ...outgoingDebts.map((debt) {
                            final toName = memberMap[debt.toMemberId] ?? 'Member';
                            return _buildOutgoingDebtCard(
                              context,
                              debt: debt,
                              toName: toName,
                              memberMap: memberMap,
                              sp: sp,
                              fmt: fmt,
                            );
                          }),
                          const SizedBox(height: 16),
                        ],

                        // SECTION C: "Group Settlements" (Only debts between OTHER members, never duplicate "You")
                        if (otherDebts.isNotEmpty) ...[
                          _buildGroupSettlementsSection(
                            context,
                            debts: otherDebts,
                            memberMap: memberMap,
                            isSimplified: isSimplified,
                            sp: sp,
                            fmt: fmt,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // SECTION D: "NET BALANCES" (Unified List: Family/Group Units & Individual Members)
                        _buildNetBalancesSection(
                          context,
                          members: members,
                          balances: balances,
                          currentMember: currentMember,
                          activeSettlementGroups: activeSettlementGroups,
                          combinedResult: combinedResult,
                          fmt: fmt,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 3. Settlement History Section
                      if (settlements.isNotEmpty) ...[
                        _buildSettlementHistorySection(
                          context,
                          settlements: settlements,
                          memberMap: memberMap,
                          currentMember: currentMember,
                          sp: sp,
                          fmt: fmt,
                        ),
                      ],
                    ]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WALLET HERO CARD
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildWalletHeroCard(
    BuildContext context, {
    required double userNet,
    required double userOwed,
    required double userOwes,
    required bool isSimplified,
    required NumberFormat fmt,
  }) {
    final isPositive = userNet >= 0.01;
    final isNegative = userNet <= -0.01;
    final sign = isPositive ? '+' : (isNegative ? '-' : '');
    final absNet = userNet.abs();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Peeking back wallet card layer
        Positioned(
          top: -4,
          left: 12,
          right: 12,
          height: 52,
          child: Container(
            decoration: BoxDecoration(
              color: _walletBack.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(22),
            ),
          ),
        ),

        // Main Wallet Card
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: _walletTeal,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0E292E).withValues(alpha: 0.45),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: CustomPaint(
              painter: DashedBorderPainter(
                color: Colors.white.withValues(alpha: 0.38),
                dashWidth: 4,
                dashSpace: 3,
                strokeWidth: 1.5,
                radius: 16,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: Header title + Optimized badge + Glowing Status Dot
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'YOUR NET BALANCE',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFD1FAE5),
                                letterSpacing: 1.1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isSimplified)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                ),
                                child: const Text(
                                  'Optimized',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),

                        // Glowing notch dot
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                          ),
                          alignment: Alignment.center,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CE088),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF4CE088).withValues(alpha: 0.8),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Main Hero Balance Number
                    Text(
                      '$sign₹${fmt.format(absNet)}',
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Status Subtitle
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: const Color(0xFF4CE088),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4CE088).withValues(alpha: 0.8),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isPositive
                              ? 'You receive overall'
                              : (isNegative ? 'You owe overall' : 'You are all settled up'),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFD1FAE5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Split Sub-cards: You are owed vs You owe others
                    Row(
                      children: [
                        // Left Card: You are owed
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10433D).withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'You are owed',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFA7F3D0),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '₹${fmt.format(userOwed)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Right Card: You owe others
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10433D).withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'You owe others',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFA7F3D0),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '₹${fmt.format(userOwes)}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
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
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DEBT SIMPLIFICATION TOGGLE CARD
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDebtSimplificationCard({
    required bool isSimplified,
    required int directCount,
    required int simplifiedCount,
    required int savingsCount,
    required ValueChanged<bool> onToggle,
    required VoidCallback onInfoTap,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF13353B).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _mintBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD1FAE5)),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.sync_alt_rounded, color: Color(0xFF059669), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Debt Simplification',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isSimplified ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: isSimplified ? const Color(0xFFA7F3D0) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Text(
                        isSimplified ? 'On' : 'Off',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: isSimplified ? const Color(0xFF047857) : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isSimplified && savingsCount > 0
                      ? '$simplifiedCount direct transfers instead of $directCount'
                      : (isSimplified
                          ? 'Optimized to minimum direct payments'
                          : 'Showing all $directCount direct payments'),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: isSimplified,
            onChanged: onToggle,
            activeColor: _primaryGreen,
            activeTrackColor: const Color(0xFFA7F3D0),
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: const Color(0xFFCBD5E1),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ALL SETTLED UP EMPTY STATE
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildAllSettledUpState(bool hasNoExpenses) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(
              color: _mintBg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              hasNoExpenses ? Icons.receipt_long_outlined : Icons.check_circle_rounded,
              color: _primaryGreen,
              size: 32,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            hasNoExpenses ? 'No expenses yet' : 'All settled up! 🎉',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasNoExpenses
                ? 'Add expenses to start splitting with the group.'
                : 'No outstanding balances. Everyone is square!',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SECTION HEADER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSectionHeader({
    required String title,
    required String badge,
    required Color badgeColor,
    required Color badgeTextColor,
    Widget? trailing,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text(
              title.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF334155),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: badgeTextColor,
                ),
              ),
            ),
          ],
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // INCOMING DEBT CARD (Your Action Required)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildIncomingDebtCard(
    BuildContext context, {
    required Debt debt,
    required String fromName,
    required Map<String, String> memberMap,
    required SplitProvider sp,
    required NumberFormat fmt,
  }) {
    final initial = fromName.trim().isNotEmpty ? fromName.trim()[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF00B865).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF13353B).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: _brandDark,
                    child: Text(
                      initial,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Row(
                    children: [
                      Text(
                        fromName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.arrow_forward_rounded, size: 14, color: _primaryGreen),
                      ),
                      const Text(
                        'You',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: _walletTeal,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Text(
                '₹${fmt.format(debt.amount)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF047857),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Actions row
          Row(
            children: [
              // Request via UPI button
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _requestViaUpi(context, fromName, debt.amount),
                  icon: const Icon(Icons.bolt_rounded, size: 15),
                  label: const Text(
                    'Request via UPI',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Mark Received button
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: const Color(0xFF334155),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    await showModalBottomSheet<double>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => SettleUpScreen(
                        debt: debt,
                        memberMap: memberMap,
                        groupId: widget.group.id,
                      ),
                    );
                  },
                  child: const Text(
                    'Mark Received',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // OUTGOING DEBT CARD (Pending Dues to Pay with Slide to Pay)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildOutgoingDebtCard(
    BuildContext context, {
    required Debt debt,
    required String toName,
    required Map<String, String> memberMap,
    required SplitProvider sp,
    required NumberFormat fmt,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF13353B).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: _walletTeal,
                    child: const Text(
                      'Y',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'You',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(Icons.arrow_forward_rounded, size: 14, color: _walletTeal),
                          ),
                          Text(
                            toName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Direct settlement due',
                        style: TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${fmt.format(debt.amount)}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Pending Pay',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFD97706),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Draggable Slide to Pay Track
          SlideToPayTrack(
            amount: debt.amount,
            onPayCompleted: () async {
              await sp.recordSettlement(
                groupId: widget.group.id,
                fromMemberId: debt.fromMemberId,
                toMemberId: debt.toMemberId,
                amount: debt.amount,
                note: 'Settled via CheQ Slide to Pay',
              );
              if (context.mounted) {
                SettlementCelebrationModal.show(
                  context,
                  payerName: 'You',
                  receiverName: toName,
                  amount: debt.amount,
                );
              }
            },
          ),
          const SizedBox(height: 8),

          // Or Pay via UPI direct option
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  final upiText = 'upi://pay?pn=${Uri.encodeComponent(toName)}&am=${debt.amount.toStringAsFixed(2)}&tn=${Uri.encodeComponent("Settlement for ${widget.group.name}")}';
                  Clipboard.setData(ClipboardData(text: upiText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('UPI payment string copied to clipboard! Open your UPI app to pay.'),
                      backgroundColor: _brandDark,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(Icons.account_balance_wallet_outlined, size: 14, color: _primaryGreen),
                label: const Text(
                  'Copy UPI pay link',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _primaryGreen),
                ),
              ),
              TextButton(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () async {
                  await showModalBottomSheet<double>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => SettleUpScreen(
                      debt: debt,
                      memberMap: memberMap,
                      groupId: widget.group.id,
                    ),
                  );
                },
                child: const Text(
                  'Custom Amount',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GROUP SETTLEMENTS SECTION (Other Members)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildGroupSettlementsSection(
    BuildContext context, {
    required List<Debt> debts,
    required Map<String, String> memberMap,
    required bool isSimplified,
    required SplitProvider sp,
    required NumberFormat fmt,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'GROUP SETTLEMENTS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF334155),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${debts.length} ${debts.length == 1 ? "Direct" : "Direct"}',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
            Text(
              isSimplified ? 'Who Owes Whom (Simplified)' : 'Who Owes Whom (Direct)',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...debts.map((debt) {
          final fromName = memberMap[debt.fromMemberId] ?? 'Member';
          final toName = memberMap[debt.toMemberId] ?? 'Member';
          final fromInitial = fromName.trim().isNotEmpty ? fromName.trim()[0].toUpperCase() : '?';
          final toInitial = toName.trim().isNotEmpty ? toName.trim()[0].toUpperCase() : '?';

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF13353B).withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Member A owes Member B visual row
                    Expanded(
                      child: Row(
                        children: [
                          // Member A
                          Column(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: const Color(0xFF475569),
                                child: Text(
                                  fromInitial,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                                ),
                              ),
                              const SizedBox(height: 3),
                              SizedBox(
                                width: 56,
                                child: Text(
                                  fromName,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Direct transfer connector
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.03),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'owes',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF64748B),
                                          ),
                                        ),
                                        SizedBox(width: 3),
                                        Icon(Icons.arrow_forward_rounded, size: 12, color: _primaryGreen),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Direct transfer',
                                    style: TextStyle(fontSize: 8.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Member B
                          Column(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor: _brandDark,
                                child: Text(
                                  toInitial,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                                ),
                              ),
                              const SizedBox(height: 3),
                              SizedBox(
                                width: 56,
                                child: Text(
                                  toName,
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Amount block
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '₹${fmt.format(debt.amount)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E293B),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Pending',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
                const SizedBox(height: 10),

                // Remind & Settle Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _mintBg,
                          foregroundColor: const Color(0xFF047857),
                          side: const BorderSide(color: Color(0xFFA7F3D0)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => _sendReminder(context, fromName, toName, debt.amount),
                        icon: const Icon(Icons.notifications_none_rounded, size: 14),
                        label: const Text(
                          'Remind',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryGreen,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () async {
                          await showModalBottomSheet<double>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => SettleUpScreen(
                              debt: debt,
                              memberMap: memberMap,
                              groupId: widget.group.id,
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_rounded, size: 14),
                        label: const Text(
                          'Settle',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NET BALANCES SECTION (Unified: Combined Settlement Groups & Members)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildNetBalancesSection(
    BuildContext context, {
    required List<SplitMember> members,
    required Map<String, double> balances,
    required SplitMember currentMember,
    required List<SplitSettlementGroup> activeSettlementGroups,
    required CombinedBalancesResult combinedResult,
    required NumberFormat fmt,
  }) {
    // Determine members claimed by any active combined settlement group
    final claimedMemberIds = <String>{};
    for (final sg in activeSettlementGroups) {
      claimedMemberIds.addAll(sg.memberIds);
    }

    final isUserInGroup = claimedMemberIds.contains(currentMember.id);
    final userBal = balances[currentMember.id] ?? 0.0;
    final isUserPositive = userBal >= 0.01;
    final isUserNegative = userBal <= -0.01;
    final userSign = isUserPositive ? '+' : (isUserNegative ? '-' : '');

    // Other ungrouped members
    final ungroupedMembers = members
        .where((m) => m.id != currentMember.id && !claimedMemberIds.contains(m.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'NET BALANCES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: Color(0xFF334155),
                letterSpacing: 0.8,
              ),
            ),
            InkWell(
              onTap: () {
                _showLedgerSheet(context, members, balances, fmt);
              },
              child: const Text(
                'View Ledger',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _primaryGreen,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF13353B).withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // 1. You (Current Member) - pinned at top if not claimed by a group
              if (!isUserInGroup) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: _walletTeal,
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF6EE7B7), width: 1.5),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              currentMember.name.trim().isNotEmpty
                                  ? currentMember.name.trim()[0].toUpperCase()
                                  : 'Y',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'You (${currentMember.name})',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 1.5),
                              Text(
                                isUserPositive
                                    ? 'Gets back'
                                    : (isUserNegative ? 'Owes in total' : 'Settled even'),
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w600,
                                  color: isUserPositive
                                      ? const Color(0xFF059669)
                                      : (isUserNegative ? const Color(0xFFE11D48) : const Color(0xFF94A3B8)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Text(
                        '$userSign₹${fmt.format(userBal.abs())}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: isUserPositive
                              ? const Color(0xFF059669)
                              : (isUserNegative ? const Color(0xFFE11D48) : const Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                ),
                if (activeSettlementGroups.isNotEmpty || ungroupedMembers.isNotEmpty)
                  const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
              ],

              // 2. Combined Settlement Groups (e.g. Dinesh sir Family • 4 members)
              for (int gi = 0; gi < activeSettlementGroups.length; gi++) ...[
                Builder(builder: (ctx) {
                  final sg = activeSettlementGroups[gi];
                  final isExpanded = _expandedGroupIds.contains(sg.id);
                  final groupBal = combinedResult.getGroupBalance(sg.id);
                  final isPositive = groupBal >= 0.01;
                  final isNegative = groupBal <= -0.01;
                  final sign = isPositive ? '+' : (isNegative ? '-' : '');
                  final groupMembers = members.where((m) => sg.memberIds.contains(m.id)).toList();
                  final groupInitial = sg.name.trim().isNotEmpty ? sg.name.trim()[0].toUpperCase() : 'G';
                  final isFamily = sg.name.toLowerCase().contains('family') ||
                      sg.name.toLowerCase().contains('sir') ||
                      sg.name.toLowerCase().contains('couple');
                  final groupLabel = isFamily ? 'Family' : 'Group';

                  return Column(
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedGroupIds.remove(sg.id);
                            } else {
                              _expandedGroupIds.add(sg.id);
                            }
                          });
                        },
                        child: Container(
                          color: isExpanded ? const Color(0xFFF8FAFC) : Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      CircleAvatar(
                                        radius: 15,
                                        backgroundColor: _brandDark,
                                        child: Text(
                                          groupInitial,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        bottom: -2,
                                        right: -2,
                                        child: Container(
                                          width: 14,
                                          height: 14,
                                          decoration: BoxDecoration(
                                            color: _primaryGreen,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 1.5),
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            '${sg.memberIds.length}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 8,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            sg.name,
                                            style: const TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFECFDF5),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: const Color(0xFFA7F3D0)),
                                            ),
                                            child: Text(
                                              '$groupLabel • ${sg.memberIds.length} members',
                                              style: const TextStyle(
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF047857),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 1.5),
                                      Text(
                                        isPositive
                                            ? '$groupLabel net gets back'
                                            : (isNegative ? '$groupLabel net owes' : '$groupLabel settled even'),
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                          color: isPositive
                                              ? const Color(0xFF059669)
                                              : (isNegative ? const Color(0xFFE11D48) : const Color(0xFF94A3B8)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Text(
                                    '$sign₹${fmt.format(groupBal.abs())}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: isPositive
                                          ? const Color(0xFF059669)
                                          : (isNegative ? const Color(0xFFE11D48) : const Color(0xFF64748B)),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  AnimatedRotation(
                                    turns: isExpanded ? 0.5 : 0.0,
                                    duration: const Duration(milliseconds: 200),
                                    child: const Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      size: 18,
                                      color: Color(0xFF94A3B8),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Expanded Member Tree Breakdown
                      if (isExpanded)
                        Container(
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAF9),
                            border: Border(
                              top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                              bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (int mi = 0; mi < groupMembers.length; mi++) ...[
                                Builder(builder: (ctx) {
                                  final m = groupMembers[mi];
                                  final mBal = balances[m.id] ?? 0.0;
                                  final mPositive = mBal >= 0.01;
                                  final mNegative = mBal <= -0.01;
                                  final mSign = mPositive ? '+' : (mNegative ? '-' : '');
                                  final isLast = mi == groupMembers.length - 1;
                                  final isHead = mi == 0;
                                  final mInitial = m.name.trim().isNotEmpty ? m.name.trim()[0].toUpperCase() : '?';

                                  return SizedBox(
                                    height: 38,
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 22,
                                          height: 38,
                                          child: CustomPaint(
                                            painter: TreeBranchPainter(isLast: isLast),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        CircleAvatar(
                                          radius: 10,
                                          backgroundColor: isHead ? _brandDark : const Color(0xFF475569),
                                          child: Text(
                                            mInitial,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                m.id == currentMember.id ? 'You (${m.name})' : m.name,
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF1E293B),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                '${isHead ? "Head • " : ""}${mPositive ? "Gets back" : (mNegative ? "Owes" : "Settled")}',
                                                style: const TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF94A3B8),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          '$mSign₹${fmt.format(mBal.abs())}',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w800,
                                            color: mPositive
                                                ? const Color(0xFF059669)
                                                : (mNegative ? const Color(0xFFE11D48) : const Color(0xFF64748B)),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ],
                          ),
                        ),
                    ],
                  );
                }),
                if (gi < activeSettlementGroups.length - 1 || ungroupedMembers.isNotEmpty)
                  const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
              ],

              // 3. Ungrouped Individual Members
              for (int ui = 0; ui < ungroupedMembers.length; ui++) ...[
                Builder(builder: (ctx) {
                  final m = ungroupedMembers[ui];
                  final bal = balances[m.id] ?? 0.0;
                  final isPositive = bal >= 0.01;
                  final isNegative = bal <= -0.01;
                  final sign = isPositive ? '+' : (isNegative ? '-' : '');
                  final initial = m.name.trim().isNotEmpty ? m.name.trim()[0].toUpperCase() : '?';

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 15,
                              backgroundColor: _getAvatarColor(ui),
                              child: Text(
                                initial,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.name,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 1.5),
                                Text(
                                  isPositive
                                      ? 'Gets back'
                                      : (isNegative ? 'Owes in total' : 'Settled even'),
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: isPositive
                                        ? const Color(0xFF059669)
                                        : (isNegative ? const Color(0xFFE11D48) : const Color(0xFF94A3B8)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Text(
                          '$sign₹${fmt.format(bal.abs())}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: isPositive
                                ? const Color(0xFF059669)
                                : (isNegative ? const Color(0xFFE11D48) : const Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (ui < ungroupedMembers.length - 1)
                  const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // VIEW LEDGER MODAL SHEET
  // ─────────────────────────────────────────────────────────────────────────
  void _showLedgerSheet(
    BuildContext context,
    List<SplitMember> members,
    Map<String, double> balances,
    NumberFormat fmt,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Group Ledger Summary',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...members.map((m) {
              final bal = balances[m.id] ?? 0.0;
              final isPositive = bal >= 0.01;
              final isNegative = bal <= -0.01;
              final sign = isPositive ? '+' : (isNegative ? '-' : '');
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      m.name,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                    ),
                    Text(
                      '$sign₹${fmt.format(bal.abs())}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: isPositive ? const Color(0xFF059669) : (isNegative ? const Color(0xFFE11D48) : const Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brandDark,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close Ledger', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SETTLEMENT HISTORY SECTION (Matches Reference Design)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSettlementHistorySection(
    BuildContext context, {
    required List<Settlement> settlements,
    required Map<String, String> memberMap,
    required SplitMember currentMember,
    required SplitProvider sp,
    required NumberFormat fmt,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  'SETTLEMENT HISTORY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF334155),
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F4EA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${settlements.length} Settled',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF047857),
                    ),
                  ),
                ),
              ],
            ),
            InkWell(
              onTap: () {
                _showAllSettlementsModal(context, settlements, memberMap, currentMember, fmt, sp);
              },
              child: const Text(
                'View All',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _primaryGreen,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF13353B).withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (int i = 0; i < settlements.length; i++) ...[
                Builder(builder: (ctx) {
                  final s = settlements[i];
                  final fromName = memberMap[s.fromMemberId] ?? 'Member';
                  final toName = memberMap[s.toMemberId] ?? 'Member';
                  final isFromCurrent = s.fromMemberId == currentMember.id;
                  final isToCurrent = s.toMemberId == currentMember.id;
                  final displayFrom = isFromCurrent ? 'You ($fromName)' : fromName;
                  final displayTo = isToCurrent ? 'You ($toName)' : toName;
                  final fromInitial = fromName.trim().isNotEmpty ? fromName.trim()[0].toUpperCase() : '?';

                  // Derive tag and subtitle
                  String methodTag = 'Settled via UPI';
                  String receiptSubtitle = 'Receipt #${(s.id.hashCode.abs() % 900) + 100}';

                  if (s.note != null && s.note!.trim().isNotEmpty) {
                    final noteLower = s.note!.toLowerCase();
                    if (noteLower.contains('cash')) {
                      methodTag = 'Settled • Cash';
                      receiptSubtitle = (noteLower == 'cash' || noteLower.contains('cash payment') || noteLower.contains('settled'))
                          ? 'Direct Cash'
                          : s.note!;
                    } else if (noteLower.contains('upi') || noteLower.contains('slide to pay')) {
                      methodTag = 'Settled via UPI';
                      receiptSubtitle = (noteLower == 'upi' || noteLower.contains('settled'))
                          ? 'Receipt #${(s.id.hashCode.abs() % 900) + 100}'
                          : s.note!;
                    } else {
                      methodTag = 'Settled';
                      receiptSubtitle = s.note!;
                    }
                  }

                  final dateStr = _formatRelativeSettlementTime(s.settledAt);

                  return InkWell(
                    onTap: () {
                      _showSettlementReceiptDetails(context, s, displayFrom, displayTo, fmt, sp);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          // Dark slate avatar with green check badge overlay
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              CircleAvatar(
                                radius: 17,
                                backgroundColor: const Color(0xFF334155),
                                child: Text(
                                  fromInitial,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: -1,
                                right: -1,
                                child: Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00B865),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1.5),
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.check_rounded,
                                    size: 9,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 10),

                          // From -> To and Pill + Date
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        displayFrom,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF1E293B),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 4),
                                      child: Icon(
                                        Icons.arrow_forward_rounded,
                                        size: 11,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        displayTo,
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF1E293B),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE6F4EA),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        methodTag,
                                        style: const TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF047857),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      dateStr,
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Amount, Subtitle & Receipt Outline Icon
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '₹${fmt.format(s.amount)}',
                                    style: const TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 1.5),
                                  Text(
                                    receiptSubtitle,
                                    style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.receipt_long_outlined,
                                size: 19,
                                color: Color(0xFF94A3B8),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                if (i < settlements.length - 1)
                  const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RELATIVE SETTLEMENT DATE FORMATTER
  // ─────────────────────────────────────────────────────────────────────────
  String _formatRelativeSettlementTime(DateTime dt) {
    final now = DateTime.now();
    final timeStr = DateFormat('h:mm a').format(dt);
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day;

    if (isToday) {
      return 'Today, $timeStr';
    } else if (isYesterday) {
      return 'Yesterday, $timeStr';
    } else {
      return DateFormat('d MMM, h:mm a').format(dt);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SETTLEMENT RECEIPT DETAILS MODAL
  // ─────────────────────────────────────────────────────────────────────────
  void _showSettlementReceiptDetails(
    BuildContext context,
    Settlement s,
    String fromName,
    String toName,
    NumberFormat fmt,
    SplitProvider sp,
  ) {
    final receiptNum = 'Receipt #${(s.id.hashCode.abs() % 900) + 100}';
    final dateStr = DateFormat('d MMMM yyyy, h:mm a').format(s.settledAt);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE6F4EA),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.receipt_long_outlined, size: 20, color: _primaryGreen),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Settlement Receipt',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          receiptNum,
                          style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Settled Amount', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      Text(
                        '₹${fmt.format(s.amount)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: Color(0xFFE2E8F0)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Paid By', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      Text(fromName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Paid To', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      Text(toName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Settled On', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                      Text(dateStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                    ],
                  ),
                  if (s.note != null && s.note!.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Note', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                        Text(s.note!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (dCtx) => AlertDialog(
                          title: const Text('Delete Settlement?'),
                          content: Text('Remove recorded settlement of ₹${fmt.format(s.amount)} from $fromName to $toName?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () => Navigator.pop(dCtx, true),
                              child: const Text('Delete', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await sp.deleteSettlement(s.id, widget.group.id);
                      }
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 16),
                    label: const Text('Delete Settlement', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _brandDark,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // VIEW ALL SETTLEMENTS MODAL
  // ─────────────────────────────────────────────────────────────────────────
  void _showAllSettlementsModal(
    BuildContext context,
    List<Settlement> settlements,
    Map<String, String> memberMap,
    SplitMember currentMember,
    NumberFormat fmt,
    SplitProvider sp,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Settlement History',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F4EA),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${settlements.length} Settled',
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF047857)),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.separated(
                  controller: scrollController,
                  itemCount: settlements.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (_, i) {
                    final s = settlements[i];
                    final fromName = memberMap[s.fromMemberId] ?? 'Member';
                    final toName = memberMap[s.toMemberId] ?? 'Member';
                    final isFromCurrent = s.fromMemberId == currentMember.id;
                    final isToCurrent = s.toMemberId == currentMember.id;
                    final displayFrom = isFromCurrent ? 'You ($fromName)' : fromName;
                    final displayTo = isToCurrent ? 'You ($toName)' : toName;
                    final fromInitial = fromName.trim().isNotEmpty ? fromName.trim()[0].toUpperCase() : '?';

                    String methodTag = 'Settled via UPI';
                    String receiptSubtitle = 'Receipt #${(s.id.hashCode.abs() % 900) + 100}';
                    if (s.note != null && s.note!.trim().isNotEmpty) {
                      final nl = s.note!.toLowerCase();
                      if (nl.contains('cash')) {
                        methodTag = 'Settled • Cash';
                        receiptSubtitle = (nl == 'cash' || nl.contains('cash payment') || nl.contains('settled'))
                            ? 'Direct Cash'
                            : s.note!;
                      } else if (nl.contains('upi') || nl.contains('slide to pay')) {
                        methodTag = 'Settled via UPI';
                        receiptSubtitle = (nl == 'upi' || nl.contains('settled'))
                            ? 'Receipt #${(s.id.hashCode.abs() % 900) + 100}'
                            : s.note!;
                      } else {
                        methodTag = 'Settled';
                        receiptSubtitle = s.note!;
                      }
                    }

                    return InkWell(
                      onTap: () => _showSettlementReceiptDetails(context, s, displayFrom, displayTo, fmt, sp),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                CircleAvatar(
                                  radius: 17,
                                  backgroundColor: const Color(0xFF334155),
                                  child: Text(
                                    fromInitial,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                                  ),
                                ),
                                Positioned(
                                  bottom: -1,
                                  right: -1,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00B865),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 1.5),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Icon(Icons.check_rounded, size: 9, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          displayFrom,
                                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 4),
                                        child: Icon(Icons.arrow_forward_rounded, size: 11, color: Color(0xFF94A3B8)),
                                      ),
                                      Flexible(
                                        child: Text(
                                          displayTo,
                                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE6F4EA),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          methodTag,
                                          style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: Color(0xFF047857)),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _formatRelativeSettlementTime(s.settledAt),
                                        style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w500, color: Color(0xFF94A3B8)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹${fmt.format(s.amount)}',
                                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                                ),
                                const SizedBox(height: 1.5),
                                Text(
                                  receiptSubtitle,
                                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.receipt_long_outlined, size: 19, color: Color(0xFF94A3B8)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TREE BRANCH PAINTER (Connects parent group to sub-members with curved branch)
// ─────────────────────────────────────────────────────────────────────────────
class TreeBranchPainter extends CustomPainter {
  final bool isLast;
  TreeBranchPainter({required this.isLast});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;

    final startX = size.width / 2;
    final midY = size.height / 2;

    final path = Path();
    path.moveTo(startX, 0);
    path.lineTo(startX, midY - 6);
    path.quadraticBezierTo(startX, midY, startX + 6, midY);
    path.lineTo(size.width, midY);
    canvas.drawPath(path, paint);

    if (!isLast) {
      canvas.drawLine(
        Offset(startX, midY),
        Offset(startX, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant TreeBranchPainter oldDelegate) => oldDelegate.isLast != isLast;
}
