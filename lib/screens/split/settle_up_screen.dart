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
  static const _primaryColor = Color(0xFF006948);

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(text: widget.debt.amount.toStringAsFixed(2));
  }

  @override
  void dispose() {
    _amountCtrl.dispose(); _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final from = widget.memberMap[widget.debt.fromMemberId] ?? widget.debt.fromMemberId;
    final to = widget.memberMap[widget.debt.toMemberId] ?? widget.debt.toMemberId;
    final fmt = NumberFormat('#,##0.00');

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      decoration: const BoxDecoration(
        color: Color(0xFFFAF8FF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 44, height: 4,
                decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text('Record Settlement', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF006948).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _MemberChip(name: from, color: Colors.red),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(Icons.arrow_forward, color: Color(0xFF6D7A72)),
                  ),
                  _MemberChip(name: to, color: _primaryColor),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                labelText: 'Amount (₹)',
                prefixIcon: const Icon(Icons.currency_rupee, color: Color(0xFF006948)),
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _primaryColor, width: 1.5)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              decoration: InputDecoration(
                labelText: 'Note (optional)', hintText: 'e.g. Paid via UPI',
                prefixIcon: const Icon(Icons.notes_outlined, color: Color(0xFF6D7A72)),
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _primaryColor, width: 1.5)),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () async {
                  final amount = double.tryParse(_amountCtrl.text.trim());
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Enter a valid amount')));
                    return;
                  }
                  final messenger = ScaffoldMessenger.of(context);
                  final nav = Navigator.of(context);
                  setState(() => _isLoading = true);
                  try {
                    await context.read<SplitProvider>().recordSettlement(
                      groupId: widget.groupId,
                      fromMemberId: widget.debt.fromMemberId,
                      toMemberId: widget.debt.toMemberId,
                      amount: amount,
                      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
                    );
                    if (mounted) {
                      nav.pop(amount);
                      messenger.showSnackBar(
                        SnackBar(content: Text('Settlement of ₹${fmt.format(amount)} recorded!'),
                            backgroundColor: _primaryColor));
                    }
                  } catch (e) {
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                    }
                  }
                  if (mounted) {
                    setState(() => _isLoading = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Mark as Settled', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberChip extends StatelessWidget {
  final String name; final Color color;
  const _MemberChip({required this.name, required this.color});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(name, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
  );
}
