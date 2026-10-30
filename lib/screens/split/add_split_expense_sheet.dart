import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/split_provider.dart';
import '../../models/split_models.dart';
import 'receipt_attachment_sheet.dart';

class AddSplitExpenseSheet extends StatefulWidget {
  final String groupId;
  final List<SplitMember> members;
  final String? currentMemberName;
  final SplitExpense? expenseToEdit;

  const AddSplitExpenseSheet({
    super.key,
    required this.groupId,
    required this.members,
    this.currentMemberName,
    this.expenseToEdit,
  });

  @override
  State<AddSplitExpenseSheet> createState() => _AddSplitExpenseSheetState();
}

class _AddSplitExpenseSheetState extends State<AddSplitExpenseSheet> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  SplitType _splitType = SplitType.equal;
  String? _paidByMemberId;
  String? _addedByMemberId;
  Set<String> _includedMembers = {};
  final Map<String, TextEditingController> _customAmountCtrls = {};
  final Map<String, TextEditingController> _percentCtrls = {};
  String? _receiptUrl;
  bool _isLoading = false;

  static const _primaryColor = Color(0xFF006948);

  @override
  void initState() {
    super.initState();
    _includedMembers = widget.members.map((m) => m.id).toSet();
    for (final m in widget.members) {
      final customCtrl = TextEditingController();
      final pctCtrl = TextEditingController(text: '0');
      customCtrl.addListener(_onShareValuesChanged);
      pctCtrl.addListener(_onShareValuesChanged);
      _customAmountCtrls[m.id] = customCtrl;
      _percentCtrls[m.id] = pctCtrl;
    }
    _amountCtrl.addListener(_onShareValuesChanged);

    if (widget.expenseToEdit != null) {
      final exp = widget.expenseToEdit!;
      _titleCtrl.text = exp.title;
      _amountCtrl.text = exp.totalAmount.toStringAsFixed(2);
      _noteCtrl.text = exp.note ?? '';
      _receiptUrl = exp.receiptUrl;
      _splitType = exp.splitType;
      _paidByMemberId = exp.paidByMemberId;
      _addedByMemberId = exp.addedByMemberId;
      _loadExistingShares(exp.id, exp.totalAmount);
    } else {
      // Default payer and adder: current user (by name match) or first member
      if (widget.currentMemberName != null) {
        final match = widget.members
            .where((m) => m.name.toLowerCase() == widget.currentMemberName!.toLowerCase())
            .firstOrNull;
        _paidByMemberId = match?.id ?? widget.members.first.id;
        _addedByMemberId = match?.id ?? widget.members.first.id;
      } else {
        _paidByMemberId = widget.members.first.id;
        _addedByMemberId = widget.members.first.id;
      }
    }
  }

  void _onShareValuesChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadExistingShares(String expenseId, double total) async {
    try {
      final shares = await context.read<SplitProvider>().getSharesForExpense(expenseId);
      if (!mounted || shares.isEmpty) return;

      setState(() {
        _includedMembers = shares.map((s) => s.memberId).toSet();
        for (final s in shares) {
          if (_customAmountCtrls.containsKey(s.memberId)) {
            _customAmountCtrls[s.memberId]!.text = s.shareAmount.toStringAsFixed(2);
          }
          if (_percentCtrls.containsKey(s.memberId) && total > 0) {
            final pct = (s.shareAmount / total) * 100;
            _percentCtrls[s.memberId]!.text = pct.toStringAsFixed(1);
          }
        }
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _amountCtrl.removeListener(_onShareValuesChanged);
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    for (final c in _customAmountCtrls.values) {
      c.removeListener(_onShareValuesChanged);
      c.dispose();
    }
    for (final c in _percentCtrls.values) {
      c.removeListener(_onShareValuesChanged);
      c.dispose();
    }
    super.dispose();
  }

  Map<String, double> _buildShares(double total) {
    final included = _includedMembers.toList();
    if (included.isEmpty) return {};

    if (_splitType == SplitType.equal) {
      final totalCents = (total * 100).round();
      final count = included.length;
      final baseCents = totalCents ~/ count;
      final remainderCents = totalCents % count;
      final result = <String, double>{};
      for (var i = 0; i < count; i++) {
        final cents = baseCents + (i < remainderCents ? 1 : 0);
        result[included[i]] = cents / 100.0;
      }
      return result;
    } else if (_splitType == SplitType.unequal) {
      return {
        for (final id in included)
          id: ((double.tryParse(_customAmountCtrls[id]?.text ?? '0') ?? 0.0) < 0
                  ? 0.0
                  : (double.tryParse(_customAmountCtrls[id]?.text ?? '0') ?? 0.0))
      };
    } else {
      // Percentage split: distribute exact cents, remainder to last member
      final count = included.length;
      var allocatedCents = 0;
      final totalCents = (total * 100).round();
      final result = <String, double>{};

      for (var i = 0; i < count; i++) {
        final id = included[i];
        var pct = double.tryParse(_percentCtrls[id]?.text ?? '0') ?? 0.0;
        if (pct < 0) pct = 0;
        if (i == count - 1) {
          final cents = totalCents - allocatedCents;
          result[id] = (cents > 0 ? cents : 0) / 100.0;
        } else {
          final cents = (totalCents * (pct / 100.0)).round();
          allocatedCents += cents;
          result[id] = cents / 100.0;
        }
      }
      return result;
    }
  }

  bool _validateShares(double total, Map<String, double> shares) {
    if (shares.isEmpty) return false;
    if (shares.values.any((s) => s < 0)) return false;

    if (_splitType == SplitType.percentage) {
      final totalPct = _includedMembers.fold<double>(
        0.0,
        (sum, id) => sum + (double.tryParse(_percentCtrls[id]?.text ?? '0') ?? 0.0),
      );
      if ((totalPct - 100.0).abs() > 0.1) {
        return false;
      }
    }

    final sum = shares.values.fold(0.0, (a, b) => a + b);
    return (sum - total).abs() <= 0.02;
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (title.isEmpty) {
      _showError('Enter a title');
      return;
    }
    if (amount == null || amount <= 0) {
      _showError('Enter a valid amount');
      return;
    }
    if (_paidByMemberId == null) {
      _showError('Select who paid');
      return;
    }
    if (_includedMembers.isEmpty) {
      _showError('Select at least one member to split with');
      return;
    }
    final shares = _buildShares(amount);
    if (!_validateShares(amount, shares)) {
      if (_splitType == SplitType.percentage) {
        _showError('Percentages must add up to 100%');
      } else {
        _showError('Split amounts must sum to ₹${amount.toStringAsFixed(2)}');
      }
      return;
    }
    setState(() => _isLoading = true);
    try {
      if (widget.expenseToEdit != null) {
        await context.read<SplitProvider>().updateExpense(
              groupId: widget.groupId,
              expenseId: widget.expenseToEdit!.id,
              title: title,
              totalAmount: amount,
              paidByMemberId: _paidByMemberId!,
              splitType: _splitType,
              shares: shares,
              note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
              receiptUrl: _receiptUrl,
            );
      } else {
        await context.read<SplitProvider>().addExpense(
              groupId: widget.groupId,
              title: title,
              totalAmount: amount,
              paidByMemberId: _paidByMemberId!,
              splitType: _splitType,
              shares: shares,
              note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
              receiptUrl: _receiptUrl,
              addedByMemberId: _addedByMemberId ?? _paidByMemberId!,
            );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showError('Error: $e');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  Widget _buildAllocationBanner(double total) {
    if (_splitType == SplitType.equal || total <= 0) {
      return const SizedBox.shrink();
    }

    if (_splitType == SplitType.unequal) {
      final allocated = _includedMembers.fold<double>(
        0.0,
        (sum, id) => sum + (double.tryParse(_customAmountCtrls[id]?.text ?? '0') ?? 0.0),
      );
      final remaining = total - allocated;
      final isMatch = remaining.abs() <= 0.02;

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMatch ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isMatch ? const Color(0xFF81C784) : const Color(0xFFE57373)),
        ),
        child: Row(
          children: [
            Icon(isMatch ? Icons.check_circle : Icons.info_outline,
                size: 18, color: isMatch ? const Color(0xFF2E7D32) : const Color(0xFFC62828)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isMatch
                    ? 'Split matches total (₹${total.toStringAsFixed(2)})'
                    : 'Allocated: ₹${allocated.toStringAsFixed(2)} / ₹${total.toStringAsFixed(2)}  •  Remaining: ₹${remaining.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isMatch ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // Percentage
      final allocatedPct = _includedMembers.fold<double>(
        0.0,
        (sum, id) => sum + (double.tryParse(_percentCtrls[id]?.text ?? '0') ?? 0.0),
      );
      final remainingPct = 100.0 - allocatedPct;
      final isMatch = remainingPct.abs() <= 0.05;

      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMatch ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isMatch ? const Color(0xFF81C784) : const Color(0xFFE57373)),
        ),
        child: Row(
          children: [
            Icon(isMatch ? Icons.check_circle : Icons.info_outline,
                size: 18, color: isMatch ? const Color(0xFF2E7D32) : const Color(0xFFC62828)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isMatch
                    ? 'Total matches 100%'
                    : 'Allocated: ${allocatedPct.toStringAsFixed(1)}% / 100%  •  Remaining: ${remainingPct.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isMatch ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildReceiptSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Bill & Receipt',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF131B2E)),
            ),
            if (_receiptUrl != null)
              TextButton(
                onPressed: () => setState(() => _receiptUrl = null),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Remove Bill', style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_receiptUrl == null)
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final chosen = await showModalBottomSheet<String>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const ReceiptAttachmentSheet(),
              );
              if (chosen != null && chosen.isNotEmpty) {
                setState(() => _receiptUrl = chosen);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.receipt_long_outlined, color: _primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attach Bill or Receipt Photo',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: _primaryColor),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Upload photo to Cloudflare R2 or paste receipt link',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.add_circle_outline, color: _primaryColor, size: 20),
                ],
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _primaryColor.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => FullScreenReceiptViewer.show(
                    context,
                    imageUrl: _receiptUrl!,
                    title: _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : 'Receipt',
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 54,
                      height: 54,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            _receiptUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.broken_image, size: 20, color: Colors.grey),
                            ),
                          ),
                          Container(
                            color: Colors.black.withValues(alpha: 0.2),
                            child: const Icon(Icons.zoom_in, color: Colors.white, size: 20),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.check_circle, color: _primaryColor, size: 15),
                          SizedBox(width: 4),
                          Text(
                            'Receipt Attached',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF131B2E)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Stored on Cloudflare Storage',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => FullScreenReceiptViewer.show(
                    context,
                    imageUrl: _receiptUrl!,
                    title: _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : 'Receipt',
                  ),
                  child: const Text('View', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: _primaryColor)),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentTotal = double.tryParse(_amountCtrl.text.trim()) ?? 0.0;
    final isEditing = widget.expenseToEdit != null;

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Color(0xFFFAF8FF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isEditing ? 'Edit Expense' : 'Add Expense',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF131B2E)),
            ),
            const SizedBox(height: 20),
            // Title
            _Field(
              controller: _titleCtrl,
              label: 'What was it for?',
              hint: 'e.g. Dinner at Barbeque Nation',
              icon: Icons.receipt_long_outlined,
            ),
            const SizedBox(height: 12),
            // Amount
            _Field(
              controller: _amountCtrl,
              label: 'Total Amount (₹)',
              hint: '0.00',
              icon: Icons.currency_rupee,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            // Paid by
            const Text('Paid by', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF131B2E))),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: widget.members.map((m) => GestureDetector(
                  onTap: () => setState(() => _paidByMemberId = m.id),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _paidByMemberId == m.id ? _primaryColor : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _paidByMemberId == m.id ? _primaryColor : const Color(0xFFBCCAC0)),
                    ),
                    child: Text(m.name, style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13,
                      color: _paidByMemberId == m.id ? Colors.white : const Color(0xFF131B2E),
                    )),
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 16),
            // Split type
            const Text('Split Type', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF131B2E))),
            const SizedBox(height: 8),
            Row(
              children: SplitType.values.map((t) => GestureDetector(
                onTap: () => setState(() => _splitType = t),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _splitType == t ? const Color(0xFF4B41E1) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _splitType == t ? const Color(0xFF4B41E1) : const Color(0xFFBCCAC0)),
                  ),
                  child: Text(t.label, style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13,
                    color: _splitType == t ? Colors.white : const Color(0xFF131B2E),
                  )),
                ),
              )).toList(),
            ),
            const SizedBox(height: 16),
            // Members to split with
            const Text('Split with', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF131B2E))),
            const SizedBox(height: 8),
            _buildAllocationBanner(currentTotal),
            ...widget.members.map((m) => _MemberSplitRow(
              member: m,
              included: _includedMembers.contains(m.id),
              splitType: _splitType,
              customCtrl: _customAmountCtrls[m.id]!,
              percentCtrl: _percentCtrls[m.id]!,
              onToggle: (v) => setState(() {
                if (v) {
                  _includedMembers.add(m.id);
                } else {
                  _includedMembers.remove(m.id);
                }
              }),
            )),
            const SizedBox(height: 12),
            // Note
            _Field(controller: _noteCtrl, label: 'Note (optional)', hint: 'e.g. split hotel cost', icon: Icons.notes_outlined),
            const SizedBox(height: 14),
            // Bill & Receipt Attachment
            _buildReceiptSection(),
            const SizedBox(height: 24),
            // Added by
            const Text('Added by', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF131B2E))),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: widget.members.map((m) => GestureDetector(
                  onTap: () => setState(() => _addedByMemberId = m.id),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: _addedByMemberId == m.id ? const Color(0xFF008096) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _addedByMemberId == m.id ? const Color(0xFF008096) : const Color(0xFFBCCAC0)),
                    ),
                    child: Text(m.name, style: TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13,
                      color: _addedByMemberId == m.id ? Colors.white : const Color(0xFF131B2E),
                    )),
                  ),
                )).toList(),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryColor, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _isLoading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(isEditing ? 'Update Expense' : 'Add Expense',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _MemberSplitRow extends StatelessWidget {
  final SplitMember member;
  final bool included;
  final SplitType splitType;
  final TextEditingController customCtrl, percentCtrl;
  final ValueChanged<bool> onToggle;
  const _MemberSplitRow({
    required this.member,
    required this.included,
    required this.splitType,
    required this.customCtrl,
    required this.percentCtrl,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: included ? const Color(0xFF006948).withValues(alpha: 0.3) : const Color(0xFFBCCAC0)),
      ),
      child: Row(
        children: [
          Checkbox(
            value: included,
            onChanged: (v) => onToggle(v ?? false),
            activeColor: const Color(0xFF006948),
            visualDensity: VisualDensity.compact,
          ),
          Expanded(child: Text(member.name, style: const TextStyle(fontWeight: FontWeight.w600))),
          if (included && splitType == SplitType.unequal)
            SizedBox(
              width: 80,
              child: TextField(
                controller: customCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  hintText: '0.00',
                  prefixText: '₹',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF006948))),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          if (included && splitType == SplitType.percentage)
            SizedBox(
              width: 80,
              child: TextField(
                controller: percentCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  hintText: '0',
                  suffixText: '%',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  border: OutlineInputBorder(),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF4B41E1))),
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final IconData icon;
  final TextInputType? keyboardType;
  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, size: 20, color: const Color(0xFF6D7A72)),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFBCCAC0))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFBCCAC0))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF006948), width: 1.5)),
        ),
      );
}
