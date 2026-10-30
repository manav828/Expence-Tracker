import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/split_provider.dart';
import '../../models/split_models.dart';
import 'package:intl/intl.dart';

class SettleUpScreen extends StatefulWidget {
  final Debt debt;
  final Map<String, String> memberMap;
  final String groupId;
  const SettleUpScreen({super.key, required this.debt, required this.memberMap, required this.groupId});
  @override
  State<SettleUpScreen> createState() => _SettleUpScreenState();
}

class _SettleUpScreenState extends State<SettleUpScreen> {
  late TextEditingController _amountCtrl;
  final _noteCtrl = TextEditingController();
  bool _isLoading = false;
  late String _selectedFromMemberId;
  late String _selectedToMemberId;
  static const _primaryColor = Color(0xFF006948);

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(text: widget.debt.amount.toStringAsFixed(2));
    _selectedFromMemberId = widget.debt.fromMemberId;
    _selectedToMemberId = widget.debt.toMemberId;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fromDisplayName = widget.debt.fromGroupName ??
        (widget.memberMap[_selectedFromMemberId] ?? _selectedFromMemberId);
    final toDisplayName = widget.debt.toGroupName ??
        (widget.memberMap[_selectedToMemberId] ?? _selectedToMemberId);
    final fmt = NumberFormat('#,##0.00');

    final fromMembers = widget.debt.fromGroupMemberIds ?? [_selectedFromMemberId];
    final toMembers = widget.debt.toGroupMemberIds ?? [_selectedToMemberId];

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      decoration: const BoxDecoration(
        color: Color(0xFFFAF8FF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Record Settlement', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  if (widget.debt.isFromGroup || widget.debt.isToGroup)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4B41E1).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.merge_type, size: 14, color: Color(0xFF4B41E1)),
                          SizedBox(width: 4),
                          Text(
                            'Combined Group',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF4B41E1)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF006948).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: _MemberChip(
                            name: fromDisplayName,
                            color: Colors.red,
                            isGroup: widget.debt.isFromGroup,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 10),
                          child: Icon(Icons.arrow_forward, color: Color(0xFF6D7A72)),
                        ),
                        Flexible(
                          child: _MemberChip(
                            name: toDisplayName,
                            color: _primaryColor,
                            isGroup: widget.debt.isToGroup,
                          ),
                        ),
                      ],
                    ),
                    if (widget.debt.isFromGroup || widget.debt.isToGroup) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Settling this will update the combined balance for the group while attributing payment to the selected member.',
                        style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700, height: 1.3),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),

              // Payer Member Selection for Combined Groups
              if (widget.debt.isFromGroup && fromMembers.length > 1) ...[
                const SizedBox(height: 16),
                Text(
                  'Payment Made By (${widget.debt.fromGroupName}):',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: fromMembers.map((mId) {
                    final isSelected = _selectedFromMemberId == mId;
                    final name = widget.memberMap[mId] ?? mId;
                    return ChoiceChip(
                      label: Text(name),
                      selected: isSelected,
                      selectedColor: const Color(0xFF006948),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF131B2E),
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12.5,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _selectedFromMemberId = mId);
                      },
                    );
                  }).toList(),
                ),
              ],

              // Receiver Member Selection for Combined Groups
              if (widget.debt.isToGroup && toMembers.length > 1) ...[
                const SizedBox(height: 16),
                Text(
                  'Payment Received By (${widget.debt.toGroupName}):',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: toMembers.map((mId) {
                    final isSelected = _selectedToMemberId == mId;
                    final name = widget.memberMap[mId] ?? mId;
                    return ChoiceChip(
                      label: Text(name),
                      selected: isSelected,
                      selectedColor: const Color(0xFF006948),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF131B2E),
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12.5,
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _selectedToMemberId = mId);
                      },
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 18),
              TextField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                decoration: InputDecoration(
                  labelText: 'Amount (₹)',
                  prefixIcon: const Icon(Icons.currency_rupee, color: Color(0xFF006948)),
                  helperText: 'You can enter a partial amount to settle partially',
                  helperStyle: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _primaryColor, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteCtrl,
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'e.g. Paid via UPI / Cash',
                  prefixIcon: const Icon(Icons.notes_outlined, color: Color(0xFF6D7A72)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _primaryColor, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () async {
                          final amount = double.tryParse(_amountCtrl.text.trim());
                          if (amount == null || amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Enter a valid amount')),
                            );
                            return;
                          }
                          final messenger = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(context);
                          setState(() => _isLoading = true);
                          try {
                            await context.read<SplitProvider>().recordSettlement(
                              groupId: widget.groupId,
                              fromMemberId: _selectedFromMemberId,
                              toMemberId: _selectedToMemberId,
                              amount: amount,
                              note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
                              fromSettlementGroupId: widget.debt.fromSettlementGroupId,
                              toSettlementGroupId: widget.debt.toSettlementGroupId,
                            );
                            if (mounted) {
                              nav.pop(amount);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Settlement of ₹${fmt.format(amount)} recorded!'),
                                  backgroundColor: _primaryColor,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                          if (mounted) {
                            setState(() => _isLoading = false);
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Mark as Settled', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberChip extends StatelessWidget {
  final String name;
  final Color color;
  final bool isGroup;

  const _MemberChip({required this.name, required this.color, this.isGroup = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isGroup) ...[
          Icon(Icons.group, size: 14, color: color),
          const SizedBox(width: 5),
        ],
        Flexible(
          child: Text(
            name,
            style: TextStyle(fontWeight: FontWeight.w700, color: color),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}
