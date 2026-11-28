import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../models/expense.dart';
import '../providers/budget_provider.dart';
import '../providers/expense_provider.dart';
import '../services/auth_service.dart';
import '../services/cloudflare_r2_service.dart';
import '../utils/category_icons.dart';
import 'receipt_attachment_sheet.dart';
import 'expense_receipt_section.dart';
import 'searchable_selection_sheet.dart';

class _AddAnotherEntryButton extends StatelessWidget {
  const _AddAnotherEntryButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add_rounded, size: 19),
        label: const Text('Add Another Entry'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class MultipleEntriesForm extends StatefulWidget {
  const MultipleEntriesForm({
    super.key,
    required this.firstEntry,
    required this.firstAmountText,
    required this.addCustomOption,
    required this.onInitialReceiptSaved,
  });

  final Expense firstEntry;
  final String firstAmountText;
  final Future<String?> Function(bool isCategory, bool isIncome, String? query)
  addCustomOption;
  final VoidCallback onInitialReceiptSaved;

  @override
  State<MultipleEntriesForm> createState() => _MultipleEntriesFormState();
}

class _MultipleEntriesFormState extends State<MultipleEntriesForm> {
  final _formKey = GlobalKey<FormState>();
  final _currency = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );
  late final List<_EntryDraft> _entries;
  final _draftReceipts = <String>{};
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    final first = widget.firstEntry;
    final entry = _EntryDraft(
      amount: widget.firstAmountText,
      note: first.comment ?? '',
      date: first.dateTime,
      type: first.type,
      category: first.category,
      paymentMethod: first.paymentMethod,
      receiptUrl: first.receiptUrl,
    );
    _entries = [entry];
  }

  @override
  void dispose() {
    for (final url in _draftReceipts) {
      CloudflareR2Service.instance.deleteByUrl(url);
    }
    super.dispose();
  }

  Future<void> _attachReceipt(_EntryDraft entry) async {
    final url = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ReceiptAttachmentSheet(),
    );
    if (url == null || url.isEmpty) return;
    if (!mounted || !_entries.contains(entry)) {
      CloudflareR2Service.instance.deleteByUrl(url);
      return;
    }
    setState(() {
      _draftReceipts.add(url);
      entry.receiptUrl = url;
    });
  }

  void _discardReceipt(_EntryDraft entry) {
    final url = entry.receiptUrl;
    entry.receiptUrl = null;
    if (url != null && _draftReceipts.remove(url)) {
      CloudflareR2Service.instance.deleteByUrl(url);
    }
  }

  _EntryDraft _blankAfter(_EntryDraft previous) => _EntryDraft(
    date: previous.date,
    type: previous.type,
    category: previous.category,
    paymentMethod: previous.paymentMethod,
  );

  void _addEntry() {
    FocusScope.of(context).unfocus();
    final entry = _blankAfter(_entries.last);
    setState(() => _entries.add(entry));
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollTo(entry));
  }

  void _scrollTo(_EntryDraft entry) {
    final target = entry.amountField.currentContext;
    if (!mounted || target == null) return;
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 200),
      alignment: 0.15,
    );
  }

  List<String> _categories(ExpenseProvider provider, TransactionType type) =>
      type == TransactionType.income
          ? provider.incomeCategories
          : provider.categories;

  Future<void> _pickOption(
    _EntryDraft entry, {
    required bool isCategory,
  }) async {
    final provider = context.read<ExpenseProvider>();
    final isIncome = entry.type == TransactionType.income;
    final selected = await SearchableSelectionSheet.show(
      context,
      title:
          isCategory
              ? (isIncome ? 'Select Income Category' : 'Select Category')
              : 'Select Payment Method',
      items:
          isCategory
              ? _categories(provider, entry.type)
              : provider.paymentMethods,
      selectedItem: isCategory ? entry.category : entry.paymentMethod,
      isCategory: isCategory,
      isIncomeCategory: isCategory && isIncome,
      compact: true,
      onAddNew: (String? query) async {
        final created = await widget.addCustomOption(
          isCategory,
          isIncome,
          query,
        );
        if (created != null) _setOption(entry, created, isCategory: isCategory);
      },
    );
    if (selected != null) _setOption(entry, selected, isCategory: isCategory);
  }

  void _setOption(
    _EntryDraft entry,
    String choice, {
    required bool isCategory,
  }) {
    if (!mounted || !_entries.contains(entry)) return;
    setState(() {
      if (isCategory) {
        entry.category = choice;
      } else {
        entry.paymentMethod = choice;
      }
    });
  }

  Future<void> _pickDate(_EntryDraft entry) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: entry.date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selected == null || !mounted || !_entries.contains(entry)) return;
    setState(
      () =>
          entry.date = DateTime(
            selected.year,
            selected.month,
            selected.day,
            entry.date.hour,
            entry.date.minute,
          ),
    );
  }

  Future<void> _saveEntries() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) {
      _scrollTo(_entries.firstWhere((entry) => entry.parsedAmount == null));
      return;
    }

    FocusScope.of(context).unfocus();
    final provider = context.read<ExpenseProvider>();
    final budgets = context.read<BudgetProvider?>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final userId = AuthService.instance.currentUser?.id;
    final usedTimestamps =
        provider.expenses.map((expense) => expense.createdAt).toSet();
    final drafts = List.of(_entries);
    final exceededCategories = <String>{};
    var timestamp = DateTime.now().millisecondsSinceEpoch;
    var savedCount = 0;

    setState(() {
      _saving = true;
      _saveError = null;
    });

    for (final entry in drafts) {
      if (!mounted || AuthService.instance.currentUser?.id != userId) break;
      while (!usedTimestamps.add(timestamp)) {
        timestamp++;
      }
      final expense = Expense(
        amount: entry.parsedAmount!,
        category: entry.category,
        paymentMethod: entry.paymentMethod,
        comment: entry.note.trim().isEmpty ? null : entry.note.trim(),
        receiptUrl: entry.receiptUrl,
        expenseDate: entry.date.millisecondsSinceEpoch,
        createdAt: timestamp,
        updatedAt: timestamp,
        type: entry.type,
      );
      try {
        await provider.addExpense(expense);
      } catch (error) {
        debugPrint('Could not save entry: $error');
        break;
      }
      savedCount++;
      final receipt = expense.receiptUrl;
      if (receipt != null) {
        _draftReceipts.remove(receipt);
        if (receipt == widget.firstEntry.receiptUrl)
          widget.onInitialReceiptSaved();
      }
      if (mounted &&
          budgets?.checkForOverspend(expense, provider.expenses) != null) {
        exceededCategories.add(expense.category);
      }
    }

    if (!mounted) return;
    if (savedCount == drafts.length) {
      final noun = savedCount == 1 ? 'entry' : 'entries';
      final budgetNotice =
          exceededCategories.isEmpty
              ? ''
              : ' Budget exceeded for ${exceededCategories.join(', ')}.';
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text('Saved $savedCount $noun.$budgetNotice')),
      );
      return;
    }

    setState(() {
      _entries.removeRange(0, savedCount);
      _saving = false;
      _saveError =
          savedCount == 0
              ? 'Couldn’t save the entries. Your drafts are still here. Try again.'
              : 'Saved $savedCount. ${_entries.length} left to save. Try again.';
    });
  }

  void _changeType(_EntryDraft entry, TransactionType type) {
    if (_saving || entry.type == type) return;
    setState(() {
      entry.type = type;
      entry.category = _categories(context.read<ExpenseProvider>(), type).first;
    });
  }

  Widget _typeToggle(_EntryDraft entry) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          for (final type in TransactionType.values)
            Expanded(
              child: TextButton.icon(
                onPressed: _saving ? null : () => _changeType(entry, type),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  backgroundColor:
                      entry.type == type
                          ? AppColors.surface
                          : Colors.transparent,
                  foregroundColor:
                      entry.type != type
                          ? AppColors.textMuted
                          : type == TransactionType.expense
                          ? AppColors.error
                          : AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: Icon(
                  type == TransactionType.expense
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 16,
                ),
                label: Text(
                  type == TransactionType.expense
                      ? 'Expense (Debit)'
                      : 'Income (Credit)',
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final total = _entries.fold(
      0.0,
      (sum, entry) => sum + (entry.parsedAmount ?? 0),
    );
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: Align(
          alignment: Alignment.bottomCenter,
          heightFactor: 1,
          child: SizedBox(
            width: double.infinity,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: math.max(0.0, media.size.height * .92 - keyboard),
              ),
              child: Material(
                color: AppColors.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                clipBehavior: Clip.antiAlias,
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 10),
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _entries.length > 1
                                        ? 'Add Transactions'
                                        : _entries.single.type ==
                                            TransactionType.income
                                        ? 'Add Income'
                                        : 'Add Spend',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                      letterSpacing: -.4,
                                    ),
                                  ),
                                  Text(
                                    _entries.length > 1
                                        ? 'Record transactions in your personal ledger'
                                        : _entries.single.type ==
                                            TransactionType.income
                                        ? 'Record an inflow into your personal ledger'
                                        : 'Record an outflow into your personal ledger',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              tooltip: 'Close entries',
                              onPressed:
                                  _saving
                                      ? null
                                      : () => Navigator.of(context).pop(),
                              icon: const CircleAvatar(
                                radius: 12,
                                backgroundColor: AppColors.surfaceSubtle,
                                child: Icon(
                                  Icons.close,
                                  size: 18,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            Text(
                              'Entries (${_entries.length})',
                              style: const TextStyle(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Semantics(
                              label: 'Entry total',
                              child: Text(
                                _currency.format(total),
                                style: const TextStyle(
                                  color: AppColors.primaryDark,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                          child: AbsorbPointer(
                            absorbing: _saving,
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (_entries.length == 1)
                                    _typeToggle(_entries.single),
                                  for (final (index, entry)
                                      in _entries.indexed) ...[
                                    _buildEntry(entry, index),
                                    const SizedBox(height: 10),
                                    ExpenseReceiptSection(
                                      receiptUrl: entry.receiptUrl,
                                      title:
                                          entry.note.trim().isEmpty
                                              ? '${entry.category} Bill'
                                              : entry.note.trim(),
                                      onAttach:
                                          _saving
                                              ? null
                                              : () => _attachReceipt(entry),
                                      onRemove:
                                          _saving
                                              ? null
                                              : () => setState(
                                                () => _discardReceipt(entry),
                                              ),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  _AddAnotherEntryButton(
                                    onPressed: _saving ? null : _addEntry,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.borderSubtle),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_saveError != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    _saveError!,
                                    style: const TextStyle(
                                      color: AppColors.error,
                                    ),
                                  ),
                                ),
                              ),
                            FilledButton(
                              onPressed: _saving ? null : _saveEntries,
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(0, 48),
                              ),
                              child: Text(
                                _saving
                                    ? 'Saving…'
                                    : _entries.length == 1
                                    ? 'Save Entry'
                                    : 'Save ${_entries.length} Entries',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEntry(_EntryDraft entry, int index) {
    final isIncome = entry.type == TransactionType.income;
    final amount = TextFormField(
      key: entry.amountField,
      initialValue: entry.amount,
      enabled: !_saving,
      onChanged: (value) => setState(() => entry.amount = value),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      decoration: _fieldDecoration('Amount', prefixText: '₹ '),
      validator:
          (_) => entry.parsedAmount == null ? 'Enter a valid amount' : null,
    );
    final category = _EntrySelector(
      label: entry.category,
      tooltip: 'Category for entry ${index + 1}',
      icon: CategoryIcons.get(entry.category),
      onPressed: _saving ? null : () => _pickOption(entry, isCategory: true),
    );
    final payment = _EntrySelector(
      label: entry.paymentMethod,
      tooltip: 'Payment method for entry ${index + 1}',
      icon: CategoryIcons.getPaymentMethodIcon(entry.paymentMethod),
      onPressed: _saving ? null : () => _pickOption(entry, isCategory: false),
    );
    final date = _EntrySelector(
      label:
          DateUtils.isSameDay(entry.date, DateTime.now())
              ? 'Today, ${DateFormat('d MMM').format(entry.date)}'
              : DateFormat('d MMM yyyy').format(entry.date),
      tooltip: 'Date for entry ${index + 1}',
      icon: Icons.calendar_today_outlined,
      onPressed: _saving ? null : () => _pickDate(entry),
    );
    final note = TextFormField(
      initialValue: entry.note,
      enabled: !_saving,
      onChanged: (value) => entry.note = value,
      textInputAction: TextInputAction.next,
      decoration: _fieldDecoration(
        'Note (optional)',
        icon: Icons.notes_rounded,
      ),
    );
    return Container(
      key: ObjectKey(entry),
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(14),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide =
              constraints.maxWidth >= 330 &&
              MediaQuery.textScalerOf(context).scale(14) <= 17;
          final pairDateAndNote = constraints.maxWidth >= 315;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_entries.length > 1)
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.primaryLight,
                      foregroundColor: AppColors.primaryDark,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const Spacer(),
                    PopupMenuButton<TransactionType>(
                      enabled: !_saving,
                      tooltip: 'Transaction type for entry ${index + 1}',
                      initialValue: entry.type,
                      onSelected: (type) => _changeType(entry, type),
                      itemBuilder:
                          (_) => const [
                            PopupMenuItem(
                              value: TransactionType.expense,
                              child: Text('Expense'),
                            ),
                            PopupMenuItem(
                              value: TransactionType.income,
                              child: Text('Income'),
                            ),
                          ],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isIncome ? 'Income' : 'Expense',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Icon(
                              Icons.expand_more,
                              size: 16,
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove entry ${index + 1}',
                      onPressed:
                          _saving || _entries.length == 1
                              ? null
                              : () {
                                setState(() {
                                  _discardReceipt(entry);
                                  _entries.remove(entry);
                                });
                              },
                      icon: const Icon(Icons.delete_outline_rounded, size: 19),
                    ),
                  ],
                ),
              if (!wide) ...[amount, const SizedBox(height: 6)],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (wide) ...[
                    Expanded(flex: 3, child: amount),
                    const SizedBox(width: 6),
                  ],
                  Expanded(flex: wide ? 4 : 1, child: category),
                  const SizedBox(width: 6),
                  Expanded(flex: wide ? 3 : 1, child: payment),
                ],
              ),
              const SizedBox(height: 6),
              if (pairDateAndNote)
                Row(
                  children: [
                    Expanded(flex: 2, child: date),
                    const SizedBox(width: 6),
                    Expanded(flex: 3, child: note),
                  ],
                )
              else ...[
                date,
                const SizedBox(height: 6),
                note,
              ],
            ],
          );
        },
      ),
    );
  }

  InputDecoration _fieldDecoration(
    String label, {
    String? prefixText,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.never,
      isDense: true,
      constraints: const BoxConstraints(minHeight: 48),
      prefixText: prefixText,
      prefixIcon:
          icon == null ? null : Icon(icon, size: 17, color: AppColors.primary),
      prefixIconConstraints: const BoxConstraints(minWidth: 34),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      filled: true,
      fillColor: AppColors.surfaceSubtle,
      border: _fieldBorder,
      enabledBorder: _fieldBorder,
    );
  }
}

const _fieldBorder = OutlineInputBorder(
  borderRadius: BorderRadius.all(Radius.circular(10)),
  borderSide: BorderSide(color: AppColors.borderSubtle),
);

class _EntrySelector extends StatelessWidget {
  const _EntrySelector({
    required this.label,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: const Size(0, 48),
          backgroundColor: AppColors.surfaceSubtle,
          foregroundColor: AppColors.textPrimary,
          side: const BorderSide(color: AppColors.borderSubtle),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppColors.primary),
            const SizedBox(width: 5),
            Expanded(
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const Icon(Icons.expand_more, size: 15, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _EntryDraft {
  _EntryDraft({
    this.amount = '',
    this.note = '',
    required this.date,
    required this.type,
    required this.category,
    required this.paymentMethod,
    this.receiptUrl,
  });

  final amountField = GlobalKey<FormFieldState<String>>();
  String amount;
  String note;
  DateTime date;
  TransactionType type;
  String category;
  String paymentMethod;
  String? receiptUrl;

  double? get parsedAmount {
    final value = double.tryParse(amount.trim().replaceAll(',', ''));
    return value != null && value.isFinite && value > 0 ? value : null;
  }
}
