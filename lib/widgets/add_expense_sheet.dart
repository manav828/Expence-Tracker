import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../providers/budget_provider.dart';
import '../utils/category_icons.dart';
import 'searchable_selection_sheet.dart';
import 'category_icon_picker_dialog.dart';
import 'receipt_attachment_sheet.dart';

class AddExpenseSheet extends StatefulWidget {
  final Expense? expenseToEdit;
  final double? initialAmount;
  final String? initialCategory;
  final String? initialPaymentMethod;
  final String? initialComment;
  final bool isAutoDetected;
  final bool autoSaveOnDismiss;

  const AddExpenseSheet({
    super.key,
    this.expenseToEdit,
    this.initialAmount,
    this.initialCategory,
    this.initialPaymentMethod,
    this.initialComment,
    this.isAutoDetected = false,
    this.autoSaveOnDismiss = false,
  });

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _commentController = TextEditingController();

  String? _category;
  String? _paymentMethod;
  String? _receiptUrl;
  late DateTime _selectedDate;

  bool get isEditing => widget.expenseToEdit != null;

  @override
  void initState() {
    super.initState();
    if (widget.expenseToEdit != null) {
      final e = widget.expenseToEdit!;
      _amountController.text = e.amount.toStringAsFixed(
        e.amount.truncateToDouble() == e.amount ? 0 : 2,
      );
      _category = e.category;
      _paymentMethod = e.paymentMethod;
      _commentController.text = e.comment ?? '';
      _receiptUrl = e.receiptUrl;
      _selectedDate = DateTime.fromMillisecondsSinceEpoch(e.expenseDate);
    } else {
      if (widget.initialAmount != null && widget.initialAmount! > 0) {
        _amountController.text = widget.initialAmount!.toStringAsFixed(
          widget.initialAmount!.truncateToDouble() == widget.initialAmount! ? 0 : 2,
        );
      }
      if (widget.initialCategory != null) {
        _category = widget.initialCategory;
      }
      if (widget.initialPaymentMethod != null) {
        _paymentMethod = widget.initialPaymentMethod;
      }
      if (widget.initialComment != null) {
        _commentController.text = widget.initialComment!;
      }
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF006948),
              onPrimary: Colors.white,
              onSurface: Color(0xFF131B2E),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final now = DateTime.now();
      setState(() {
        _selectedDate = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDate.hour != 0 ? _selectedDate.hour : now.hour,
          _selectedDate.minute != 0 ? _selectedDate.minute : now.minute,
        );
      });
    }
  }

  String _formatDisplayDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(dt.year, dt.month, dt.day);

    if (dateOnly == today) {
      return 'Today, ${DateFormat('d MMM yyyy').format(dt)}';
    } else if (dateOnly == today.subtract(const Duration(days: 1))) {
      return 'Yesterday, ${DateFormat('d MMM yyyy').format(dt)}';
    }
    return DateFormat('EEE, d MMM yyyy').format(dt);
  }

  void _promptAddCustom(BuildContext context, bool isCategory) {
    final controller = TextEditingController();
    String selectedIconKey = 'category';
    IconData selectedIconData = Icons.category;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            isCategory ? 'Add New Category' : 'Add Payment Method',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF131B2E)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: isCategory ? 'e.g. Health, Coffee' : 'e.g. NetBanking, Forex',
                  filled: true,
                  fillColor: const Color(0xFFF2F3FF),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              if (isCategory) ...[
                const SizedBox(height: 14),
                InkWell(
                  onTap: () async {
                    final picked = await CategoryIconPickerDialog.show(ctx, currentIconKey: selectedIconKey);
                    if (picked != null) {
                      setDialogState(() {
                        selectedIconKey = picked.key;
                        selectedIconData = picked.icon;
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F3FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: const Color(0xFF006948).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(selectedIconData, color: const Color(0xFF006948), size: 18),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Category Icon',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF131B2E)),
                            ),
                          ],
                        ),
                        const Row(
                          children: [
                            Text(
                              'Choose',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF006948)),
                            ),
                            Icon(Icons.chevron_right, size: 18, color: Color(0xFF006948)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF6D7A72))),
            ),
            ElevatedButton(
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  final provider = Provider.of<ExpenseProvider>(context, listen: false);
                  if (isCategory) {
                    await CategoryIcons.setCustomIcon(text, selectedIconKey);
                    await provider.addCategory(text);
                    setState(() => _category = text);
                  } else {
                    await provider.addPaymentMethod(text);
                    setState(() => _paymentMethod = text);
                  }
                  if (ctx.mounted) {
                    Navigator.pop(dialogCtx);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006948),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Expense?'),
        content: const Text('Are you sure you want to remove this transaction from the ledger?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6D7A72))),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFBA1A1A)),
            child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final provider = Provider.of<ExpenseProvider>(context, listen: false);
      if (widget.expenseToEdit!.id != null) {
        await provider.deleteExpense(widget.expenseToEdit!.id!);
      }
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Expense deleted from ledger'),
            backgroundColor: Color(0xFFBA1A1A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _submit() async {
    if (_formKey.currentState!.validate()) {
      final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
      final provider = Provider.of<ExpenseProvider>(context, listen: false);
      final finalCategory = _category ?? (provider.categories.isNotEmpty ? provider.categories.first : 'Food & Dining');
      final finalPaymentMethod = _paymentMethod ?? (provider.paymentMethods.isNotEmpty ? provider.paymentMethods.first : 'UPI');
      final comment = _commentController.text.trim().isEmpty ? null : _commentController.text.trim();

      if (isEditing) {
        final updated = widget.expenseToEdit!.copyWith(
          amount: amount,
          category: finalCategory,
          paymentMethod: finalPaymentMethod,
          comment: comment,
          receiptUrl: _receiptUrl,
          expenseDate: _selectedDate.millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );

        await provider.updateExpense(updated);
        if (!mounted) return;
        context.read<BudgetProvider>().checkForOverspend(updated, provider.expenses);
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updated spend: ₹${amount.toStringAsFixed(2)} ($finalCategory)'),
            backgroundColor: const Color(0xFF006948),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      } else {
        final newExpense = Expense(
          amount: amount,
          category: finalCategory,
          paymentMethod: finalPaymentMethod,
          comment: comment,
          receiptUrl: _receiptUrl,
          expenseDate: _selectedDate.millisecondsSinceEpoch,
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        );

        await provider.addExpense(newExpense);
        if (!mounted) return;
        final overspendWarning = context.read<BudgetProvider>().checkForOverspend(newExpense, provider.expenses);
        Navigator.of(context).pop();

        if (overspendWarning != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Budget limit exceeded for $finalCategory!',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFBA1A1A),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added ₹${amount.toStringAsFixed(2)} to $finalCategory'),
              backgroundColor: const Color(0xFF006948),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);
    final categories = provider.categories.isNotEmpty
        ? provider.categories
        : ['Food & Dining', 'Shopping', 'Transport', 'Bills & Utilities', 'Entertainment', 'Health & Wellness', 'Investment', 'General'];
    final paymentMethods = provider.paymentMethods.isNotEmpty
        ? provider.paymentMethods
        : ['UPI', 'Card', 'Cash', 'Transfer'];

    final effectiveCategory = categories.contains(_category) ? _category! : categories.first;
    final effectivePayment = paymentMethods.contains(_paymentMethod) ? _paymentMethod! : paymentMethods.first;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        // Discard without logging on cancel or dismiss
      },
      child: Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Color(0x1F0F172A),
              blurRadius: 28,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 18),
                if (widget.isAutoDetected) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF85F8C4).withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF006948).withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.flash_on, color: Color(0xFF006948), size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Transaction Auto-Detected',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF006948)),
                              ),
                              SizedBox(height: 1),
                              Text(
                                'Tap Cancel to discard, or Save to confirm',
                                style: TextStyle(fontSize: 11, color: Color(0xFF3D4A42)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing
                              ? 'Edit Expense'
                              : widget.isAutoDetected
                                  ? 'Transaction Detected'
                                  : 'Add Spend',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF131B2E),
                            letterSpacing: -0.4,
                          ),
                        ),
                        Text(
                          isEditing
                              ? 'Modify or update transaction details'
                              : widget.isAutoDetected
                                  ? 'Auto-filled from detected transaction'
                                  : 'Record an outflow into ExpenCircle Private Ledger',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF6D7A72)),
                        ),
                      ],
                    ),
                  if (isEditing)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Color(0xFFBA1A1A)),
                      tooltip: 'Delete transaction',
                      onPressed: _confirmDelete,
                    ),
                  if (widget.isAutoDetected)
                    IconButton(
                      icon: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131B2E).withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 18, color: Color(0xFF131B2E)),
                      ),
                      tooltip: 'Discard',
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Amount Field
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                autofocus: !isEditing,
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF006948)),
                decoration: InputDecoration(
                  prefixText: '₹ ',
                  prefixStyle: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF006948)),
                  labelText: 'Amount',
                  labelStyle: const TextStyle(color: Color(0xFF6D7A72)),
                  filled: true,
                  fillColor: const Color(0xFFF2F3FF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter amount';
                  final num = double.tryParse(val.trim());
                  if (num == null || num <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Date Picker Selector Card
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F3FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF006948).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.calendar_today, color: Color(0xFF006948), size: 18),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Transaction Date',
                                style: TextStyle(fontSize: 11, color: Color(0xFF6D7A72), fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatDisplayDate(_selectedDate),
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF131B2E)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0x1F006948)),
                        ),
                        child: const Row(
                          children: [
                            Text(
                              'Change',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF006948)),
                            ),
                            SizedBox(width: 2),
                            Icon(Icons.arrow_drop_down, size: 18, color: Color(0xFF006948)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Category with Searchable Selection and Icon Picker
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final selected = await SearchableSelectionSheet.show(
                          context,
                          title: 'Select Category',
                          items: categories,
                          selectedItem: effectiveCategory,
                          isCategory: true,
                          onAddNew: () => _promptAddCustom(context, true),
                        );
                        if (selected != null && mounted) {
                          setState(() => _category = selected);
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F3FF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            // Category Icon with tap to change icon
                            Tooltip(
                              message: 'Tap to change category icon',
                              child: InkWell(
                                onTap: () async {
                                  final currentKey = CategoryIcons.getKeyForCategory(effectiveCategory);
                                  final picked = await CategoryIconPickerDialog.show(
                                    context,
                                    currentIconKey: currentKey,
                                  );
                                  if (picked != null && mounted) {
                                    await CategoryIcons.setCustomIcon(effectiveCategory, picked.key);
                                    setState(() {});
                                  }
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF006948).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Icon(
                                        CategoryIcons.get(effectiveCategory),
                                        size: 20,
                                        color: const Color(0xFF006948),
                                      ),
                                      Positioned(
                                        bottom: 1,
                                        right: 1,
                                        child: Container(
                                          padding: const EdgeInsets.all(1.5),
                                          decoration: const BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.edit, size: 8, color: Color(0xFF006948)),
                                        ),
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
                                  const Text(
                                    'Category',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF6D7A72), fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    effectiveCategory,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF131B2E),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, color: Color(0xFF6D7A72)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    height: 56,
                    width: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F3FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add, color: Color(0xFF006948)),
                      tooltip: 'Add Category',
                      onPressed: () => _promptAddCustom(context, true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Payment Method with Searchable Selection
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        final selected = await SearchableSelectionSheet.show(
                          context,
                          title: 'Select Payment Method',
                          items: paymentMethods,
                          selectedItem: effectivePayment,
                          isCategory: false,
                          onAddNew: () => _promptAddCustom(context, false),
                        );
                        if (selected != null && mounted) {
                          setState(() => _paymentMethod = selected);
                        }
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F3FF),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: const Color(0xFF3323CC).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                CategoryIcons.getPaymentMethodIcon(effectivePayment),
                                size: 20,
                                color: const Color(0xFF3323CC),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Payment Method',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF6D7A72), fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    effectivePayment,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF131B2E),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_drop_down, color: Color(0xFF6D7A72)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    height: 56,
                    width: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F3FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.add, color: Color(0xFF006948)),
                      tooltip: 'Add Payment Method',
                      onPressed: () => _promptAddCustom(context, false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Note / Payee
              TextFormField(
                controller: _commentController,
                decoration: InputDecoration(
                  labelText: 'Note / Payee (Optional)',
                  labelStyle: const TextStyle(color: Color(0xFF6D7A72)),
                  filled: true,
                  fillColor: const Color(0xFFF2F3FF),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Bill & Receipt Attachment
              _buildReceiptSection(),
              const SizedBox(height: 24),

              // Cancel + Submit Buttons
              if (widget.isAutoDetected) ...[
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFBA1A1A),
                            side: const BorderSide(color: Color(0xFFBA1A1A), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF006948),
                            foregroundColor: Colors.white,
                            elevation: 4,
                            shadowColor: const Color(0xFF006948).withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: const Text(
                            'Save Spend',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                // Normal Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF006948),
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: const Color(0xFF006948).withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: Text(
                      isEditing ? 'Update Spend' : 'Save Spend',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildReceiptSection() {
    const primaryColor = Color(0xFF006948);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Bill & Receipt (Optional)',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF131B2E)),
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
            borderRadius: BorderRadius.circular(16),
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
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.receipt_long_outlined, color: primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attach Bill or Invoice',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: primaryColor),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Upload photo or paste receipt link',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.add_circle_outline, color: primaryColor, size: 20),
                ],
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primaryColor.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => FullScreenReceiptViewer.show(
                    context,
                    imageUrl: _receiptUrl!,
                    title: _commentController.text.trim().isNotEmpty
                        ? _commentController.text.trim()
                        : '$_category Bill',
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
                          Icon(Icons.check_circle, color: primaryColor, size: 15),
                          SizedBox(width: 4),
                          Text(
                            'Receipt Attached',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF131B2E)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Receipt attached securely',
                        style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => FullScreenReceiptViewer.show(
                    context,
                    imageUrl: _receiptUrl!,
                    title: _commentController.text.trim().isNotEmpty
                        ? _commentController.text.trim()
                        : '$_category Bill',
                  ),
                  child: const Text('View', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: primaryColor)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
