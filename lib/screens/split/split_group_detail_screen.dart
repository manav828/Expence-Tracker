import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/split_provider.dart';
import '../../models/split_models.dart';
import 'add_split_expense_sheet.dart';
import 'settle_up_screen.dart';

class SplitGroupDetailScreen extends StatefulWidget {
  final SplitGroup group;
  const SplitGroupDetailScreen({super.key, required this.group});
  @override
  State<SplitGroupDetailScreen> createState() => _SplitGroupDetailScreenState();
}

class _SplitGroupDetailScreenState extends State<SplitGroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loadingDetail = true;
  static const _primaryColor = Color(0xFF006948);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _loadingDetail = true);
    await context.read<SplitProvider>().loadGroupDetail(widget.group.id);
    if (mounted) setState(() => _loadingDetail = false);
  }

  void _shareInvite() {
    final webUrl = kIsWeb
        ? '${Uri.base.origin}/?code=${widget.group.inviteCode}'
        : 'https://expensetracker.web.app/?code=${widget.group.inviteCode}';
    final shareText = 'Join our group "${widget.group.name}" on ExpenCircle!\n'
        'Invite Code: ${widget.group.inviteCode}\n'
        'Direct link: $webUrl';
    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite link copied! Friends can open it in browser or app.'),
        backgroundColor: _primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.group.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            Text('by ${widget.group.createdBy} • Code: ${widget.group.inviteCode}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6D7A72))),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF131B2E),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 20),
            tooltip: 'Share Invite Link',
            onPressed: _shareInvite,
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'delete') {
                final nav = Navigator.of(context);
                final splitProv = context.read<SplitProvider>();
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete Group'),
                    content: const Text('This will permanently delete all expenses and settlements. Are you sure?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirm == true && mounted) {
                  await splitProv.deleteGroup(widget.group.id);
                  if (mounted) nav.pop();
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'delete', child: Row(children: [
                Icon(Icons.delete_outline, color: Colors.red, size: 18),
                SizedBox(width: 8),
                Text('Delete Group', style: TextStyle(color: Colors.red)),
              ])),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: _primaryColor,
          unselectedLabelColor: const Color(0xFF6D7A72),
          indicatorColor: _primaryColor,
          tabs: const [
            Tab(text: 'Balances'),
            Tab(text: 'Expenses'),
            Tab(text: 'Members'),
          ],
        ),
      ),
      body: _loadingDetail
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDetail,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _BalancesTab(groupId: widget.group.id),
                  _ExpensesTab(groupId: widget.group.id),
                  _MembersTab(groupId: widget.group.id),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final members = context.read<SplitProvider>().getMembersForGroup(widget.group.id);
          if (members.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Add members first')));
            return;
          }
          await showModalBottomSheet(
            context: context, isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => AddSplitExpenseSheet(
              groupId: widget.group.id,
              members: members,
              currentMemberName: context.read<SplitProvider>().currentMemberName,
            ),
          );
          _loadDetail();
        },
        label: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.w700)),
        icon: const Icon(Icons.add),
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
      ),
    );
  }
}

// ─── Balances Tab ────────────────────────────────────────────────────────────
class _BalancesTab extends StatelessWidget {
  final String groupId;
  const _BalancesTab({required this.groupId});

  @override
  Widget build(BuildContext context) {
    return Consumer<SplitProvider>(builder: (context, sp, _) {
      final members = sp.getMembersForGroup(groupId);
      final balances = sp.getBalancesForGroup(groupId);
      final debts = sp.getDebtsForGroup(groupId);
      final memberMap = {for (final m in members) m.id: m.name};
      final fmt = NumberFormat('#,##0.00');

      final totalSpend = sp.getExpensesForGroup(groupId)
          .fold(0.0, (s, e) => s + e.totalAmount);
      final expenses = sp.getExpensesForGroup(groupId);
      final hasUnsettled = debts.isNotEmpty || balances.values.any((b) => b.abs() >= 0.01);

      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // Summary card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF006948), Color(0xFF00855D)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Text('Total Group Spend', style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 4),
                Text('₹${fmt.format(totalSpend)}',
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text('${members.length} members • ${expenses.length} expenses',
                    style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (!hasUnsettled) ...[
            Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                Icon(expenses.isEmpty ? Icons.receipt_long_outlined : Icons.check_circle_outline,
                    size: 48, color: const Color(0xFF006948)),
                const SizedBox(height: 8),
                Text(expenses.isEmpty ? 'No expenses yet' : 'All settled up! 🎉',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                if (expenses.isEmpty) ...[
                  const SizedBox(height: 4),
                  const Text('Add expenses to start splitting with the group',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6D7A72))),
                ],
              ]),
            )),
          ] else ...[
            const Text('Who Owes Whom', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF131B2E))),
            const SizedBox(height: 4),
            const Text('Simplified to minimum transactions', style: TextStyle(fontSize: 12, color: Color(0xFF6D7A72))),
            const SizedBox(height: 12),
            ...debts.map((debt) => _DebtCard(
              debt: debt, memberMap: memberMap,
              onSettle: () async {
                await showModalBottomSheet<double>(
                  context: context, isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => SettleUpScreen(
                    debt: debt, memberMap: memberMap,
                    groupId: groupId,
                  ),
                );
              },
            )),
          ],
          if (balances.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('Individual Balances', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF131B2E))),
            const SizedBox(height: 12),
            ...members.map((m) {
              final bal = balances[m.id] ?? 0.0;
              return _BalanceRow(name: m.name, balance: bal);
            }),
          ],
        ],
      );
    });
  }
}

class _DebtCard extends StatelessWidget {
  final Debt debt;
  final Map<String, String> memberMap;
  final VoidCallback onSettle;
  const _DebtCard({required this.debt, required this.memberMap, required this.onSettle});

  @override
  Widget build(BuildContext context) {
    final from = memberMap[debt.fromMemberId] ?? debt.fromMemberId;
    final to = memberMap[debt.toMemberId] ?? debt.toMemberId;
    final fmt = NumberFormat('#,##0.00');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x0A000000)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              RichText(text: TextSpan(
                style: const TextStyle(fontSize: 14, color: Color(0xFF131B2E)),
                children: [
                  TextSpan(text: from, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.red)),
                  const TextSpan(text: ' owes '),
                  TextSpan(text: to, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF006948))),
                ],
              )),
              Text('₹${fmt.format(debt.amount)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF131B2E))),
            ]),
          ),
          ElevatedButton(
            onPressed: onSettle,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006948), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: const Text('Settle', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  final String name; final double balance;
  const _BalanceRow({required this.name, required this.balance});
  @override
  Widget build(BuildContext context) {
    final isPositive = balance >= 0;
    final fmt = NumberFormat('#,##0.00');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x0A000000)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18, backgroundColor: isPositive
                ? const Color(0xFF006948).withValues(alpha: 0.1)
                : Colors.red.withValues(alpha: 0.1),
            child: Text(name[0].toUpperCase(),
                style: TextStyle(fontWeight: FontWeight.w800, color: isPositive ? const Color(0xFF006948) : Colors.red)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(isPositive ? '+ ₹${fmt.format(balance)}' : '- ₹${fmt.format(balance.abs())}',
                style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14,
                  color: isPositive ? const Color(0xFF006948) : Colors.red,
                )),
            Text(isPositive ? 'gets back' : 'owes',
                style: const TextStyle(fontSize: 11, color: Color(0xFF6D7A72))),
          ]),
        ],
      ),
    );
  }
}

// ─── Expenses Tab ─────────────────────────────────────────────────────────────
class _ExpensesTab extends StatelessWidget {
  final String groupId;
  const _ExpensesTab({required this.groupId});

  @override
  Widget build(BuildContext context) {
    return Consumer<SplitProvider>(builder: (context, sp, _) {
      final expenses = sp.getExpensesForGroup(groupId);
      final members = sp.getMembersForGroup(groupId);
      final memberMap = {for (final m in members) m.id: m.name};
      if (expenses.isEmpty) {
        return const Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFFBCCAC0)),
            SizedBox(height: 12),
            Text('No expenses yet', style: TextStyle(color: Color(0xFF6D7A72))),
            SizedBox(height: 4),
            Text('Tap "+ Add Expense" to get started', style: TextStyle(fontSize: 12, color: Color(0xFF6D7A72))),
          ]),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: expenses.length,
        itemBuilder: (context, i) => _ExpenseCard(
          expense: expenses[i],
          memberMap: memberMap,
          groupId: groupId,
          members: members,
        ),
      );
    });
  }
}

class _ExpenseCard extends StatelessWidget {
  final SplitExpense expense;
  final Map<String, String> memberMap;
  final String groupId;
  final List<SplitMember> members;
  const _ExpenseCard({
    required this.expense,
    required this.memberMap,
    required this.groupId,
    required this.members,
  });

  @override
  Widget build(BuildContext context) {
    final paidBy = memberMap[expense.paidByMemberId] ?? 'Former Member';
    final addedBy = memberMap[expense.addedByMemberId] ?? 'Former Member';
    final fmt = NumberFormat('#,##0.00');
    final dateStr = DateFormat('d MMM').format(expense.createdAt);
    return Dismissible(
      key: Key(expense.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Delete Expense'),
          content: Text('Delete "${expense.title}"?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
      onDismissed: (_) => context.read<SplitProvider>().deleteExpense(groupId, expense.id),
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(14)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            await showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => AddSplitExpenseSheet(
                groupId: groupId,
                members: members,
                expenseToEdit: expense,
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x0A000000)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4B41E1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.receipt_outlined, color: Color(0xFF4B41E1), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(expense.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      paidBy == addedBy
                          ? 'Paid by $paidBy • $dateStr'
                          : 'Paid by $paidBy (by $addedBy) • $dateStr',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6D7A72)),
                    ),
                    if (expense.note != null && expense.note!.isNotEmpty)
                      Text(expense.note!, style: const TextStyle(fontSize: 12, color: Color(0xFF6D7A72))),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('₹${fmt.format(expense.totalAmount)}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF131B2E))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF006948).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(expense.splitType.label,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF006948))),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Members Tab ─────────────────────────────────────────────────────────────
class _MembersTab extends StatelessWidget {
  final String groupId;
  const _MembersTab({required this.groupId});

  @override
  Widget build(BuildContext context) {
    return Consumer<SplitProvider>(builder: (context, sp, _) {
      final members = sp.getMembersForGroup(groupId);
      return Column(
        children: [
          Expanded(
            child: members.isEmpty
                ? const Center(child: Text('No members'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    itemCount: members.length,
                    itemBuilder: (context, i) => _MemberTile(member: members[i], groupId: groupId),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final ctrl = TextEditingController();
                  await showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Add Member'),
                      content: TextField(
                        controller: ctrl,
                        decoration: const InputDecoration(hintText: 'Member name'),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF006948)),
                          onPressed: () async {
                            if (ctrl.text.trim().isNotEmpty) {
                              await sp.addMember(groupId, ctrl.text.trim());
                              if (context.mounted) Navigator.pop(context);
                            }
                          },
                          child: const Text('Add', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.person_add_outlined),
                label: const Text('Add Member', style: TextStyle(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006948), foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _MemberTile extends StatelessWidget {
  final SplitMember member; final String groupId;
  const _MemberTile({required this.member, required this.groupId});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x0A000000)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF006948).withValues(alpha: 0.1),
            child: Text(member.name[0].toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF006948))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(member.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Remove Member'),
                  content: Text('Remove ${member.name} from the group?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Remove', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await context.read<SplitProvider>().removeMember(groupId, member.id);
              }
            },
          ),
        ],
      ),
    );
  }
}
