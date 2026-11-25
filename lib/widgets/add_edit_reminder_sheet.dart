import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../models/payment_reminder.dart';
import '../providers/expense_provider.dart';
import '../providers/reminder_provider.dart';
import '../utils/category_icons.dart';
import 'searchable_selection_sheet.dart';

class AddEditReminderSheet extends StatefulWidget {
  final PaymentReminder? reminderToEdit;

  const AddEditReminderSheet({super.key, this.reminderToEdit});

  @override
  State<AddEditReminderSheet> createState() => _AddEditReminderSheetState();
}

class _AddEditReminderSheetState extends State<AddEditReminderSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _customDaysController;
  late final TextEditingController _notesController;

  late String _selectedCategory;
  late String _selectedPaymentMethod;
  late ReminderFrequency _selectedFrequency;
  late DateTime _selectedDueDate;
  int? _dueDay;

  @override
  void initState() {
    super.initState();
    final rem = widget.reminderToEdit;
    _titleController = TextEditingController(text: rem?.title ?? '');
    _amountController = TextEditingController(
      text: rem != null ? rem.amount.toStringAsFixed(0) : '',
    );
    _customDaysController = TextEditingController(
      text: rem?.customIntervalDays?.toString() ?? '30',
    );
    _notesController = TextEditingController(text: rem?.notes ?? '');

    _selectedCategory = rem?.category ?? 'Bills & Utilities';
    _selectedPaymentMethod = rem?.paymentMethod ?? 'UPI';
    _selectedFrequency = rem?.frequency ?? ReminderFrequency.monthly;
    _selectedDueDate = rem?.nextDueDate ?? DateTime.now().add(const Duration(days: 1));
    _dueDay = rem?.dueDay ?? _selectedDueDate.day;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _customDaysController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<String?> _promptAddCustom(
    BuildContext context,
    bool isCategory, {
    String? initialText,
  }) async {
    final controller = TextEditingController(text: initialText ?? '');
    String selectedIconKey = isCategory ? 'category' : '';

    return await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              isCategory ? 'New Category' : 'New Payment Method',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: isCategory ? 'e.g. Wi-Fi, Rent' : 'e.g. Credit Card, Wallet',
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
                if (isCategory) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Icon',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 112,
                    width: double.maxFinite,
                    child: GridView.builder(
                      shrinkWrap: true,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                      ),
                      itemCount: CategoryIcons.availableIcons.length,
                      itemBuilder: (context, idx) {
                        final item = CategoryIcons.availableIcons[idx];
                        final isSel = selectedIconKey == item.key;
                        return InkWell(
                          onTap: () {
                            setDialogState(() {
                              selectedIconKey = item.key;
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSel ? AppColors.primary : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              item.icon,
                              size: 18,
                              color: isSel ? Colors.white : const Color(0xFF334155),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  final text = controller.text.trim();
                  if (text.isNotEmpty) {
                    final provider = ctx.read<ExpenseProvider>();
                    if (isCategory) {
                      await CategoryIcons.setCustomIcon(text, selectedIconKey);
                      await provider.addCategory(text);
                    } else {
                      await provider.addPaymentMethod(text);
                    }
                    if (ctx.mounted) Navigator.pop(ctx, text);
                  }
                },
                child: const Text('Add', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDueDate = picked;
        _dueDay = picked.day;
      });
    }
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;

    final expenseProvider = context.read<ExpenseProvider>();
    final categories = expenseProvider.getSortedCategories();
    final paymentMethods = expenseProvider.getSortedPaymentMethods();
    final effectiveCategory = categories.contains(_selectedCategory)
        ? _selectedCategory
        : (categories.firstOrNull ?? _selectedCategory);
    final effectivePayment = paymentMethods.contains(_selectedPaymentMethod)
        ? _selectedPaymentMethod
        : (paymentMethods.firstOrNull ?? _selectedPaymentMethod);

    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid bill amount')),
      );
      return;
    }

    final customDays = _selectedFrequency == ReminderFrequency.customDays
        ? int.tryParse(_customDaysController.text.trim())
        : null;

    final reminder = PaymentReminder(
      id: widget.reminderToEdit?.id,
      userId: widget.reminderToEdit?.userId,
      title: title,
      amount: amount,
      category: effectiveCategory,
      paymentMethod: effectivePayment,
      frequency: _selectedFrequency,
      customIntervalDays: customDays,
      dueDay: _selectedFrequency != ReminderFrequency.oneTime ? _dueDay : null,
      dueDate: _selectedFrequency == ReminderFrequency.oneTime ? _selectedDueDate : null,
      nextDueDate: _selectedDueDate,
      lastPaidDate: widget.reminderToEdit?.lastPaidDate,
      notifiedDayBeforeAt: widget.reminderToEdit?.notifiedDayBeforeAt,
      notifiedDueDayAt: widget.reminderToEdit?.notifiedDueDayAt,
      isActive: widget.reminderToEdit?.isActive ?? true,
      isCompleted: widget.reminderToEdit?.isCompleted ?? false,
      splitGroupId: widget.reminderToEdit?.splitGroupId,
      splitType: widget.reminderToEdit?.splitType ?? ReminderSplitType.personal,
      splitTargetMemberId: widget.reminderToEdit?.splitTargetMemberId,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
    );

    final provider = context.read<ReminderProvider>();
    if (widget.reminderToEdit == null) {
      await provider.addReminder(reminder);
    } else {
      await provider.updateReminder(reminder);
    }

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.reminderToEdit == null
                ? 'Reminder for "$title" scheduled!'
                : 'Reminder "$title" updated!',
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildSearchableSelectorField({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6D7A72),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_drop_down, size: 20, color: Color(0xFF6D7A72)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expenseProvider = context.watch<ExpenseProvider>();
    final categories = expenseProvider.getSortedCategories();
    final paymentMethods = expenseProvider.getSortedPaymentMethods();
    final effectiveCategory = categories.contains(_selectedCategory)
        ? _selectedCategory
        : (categories.firstOrNull ?? _selectedCategory);
    final effectivePayment = paymentMethods.contains(_selectedPaymentMethod)
        ? _selectedPaymentMethod
        : (paymentMethods.firstOrNull ?? _selectedPaymentMethod);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 16,
          ),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Sheet Title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.alarm_add_rounded, color: AppColors.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        widget.reminderToEdit == null
                            ? 'Add Payment Reminder'
                            : 'Edit Payment Reminder',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Title & Amount
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Bill / Reminder Name',
                      hintText: 'e.g., Flat Rent, Electricity, Wi-Fi',
                      prefixIcon: const Icon(Icons.receipt_long_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Enter reminder title' : null,
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Amount (₹)',
                      hintText: '15000',
                      prefixIcon: const Icon(Icons.currency_rupee_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Enter amount' : null,
                  ),
                  const SizedBox(height: 18),

                  // Frequency Selector
                  const Text(
                    'Frequency / Recurrence',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ReminderFrequency.values.map((freq) {
                      final isSelected = _selectedFrequency == freq;
                      return ChoiceChip(
                        label: Text(freq.label),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) setState(() => _selectedFrequency = freq);
                        },
                        selectedColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 12.5,
                        ),
                        backgroundColor: AppColors.surfaceSubtle,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Custom Interval Input (if customDays)
                  if (_selectedFrequency == ReminderFrequency.customDays) ...[
                    TextFormField(
                      controller: _customDaysController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Repeat Every (Days)',
                        hintText: 'e.g. 28 for mobile prepaid plan',
                        prefixIcon: const Icon(Icons.repeat_rounded),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      validator: (v) {
                        final n = int.tryParse(v ?? '');
                        if (n == null || n <= 0) return 'Enter valid days';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Due Date Selector
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded, color: AppColors.primary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedFrequency == ReminderFrequency.oneTime
                                      ? 'Due Date (One-Time)'
                                      : 'Next Due Date (Repeats ${_selectedFrequency.label.toLowerCase()})',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  DateFormat('EEEE, d MMMM yyyy').format(_selectedDueDate),
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Searchable Category & Payment Method Selectors
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSearchableSelectorField(
                        label: 'Category',
                        value: effectiveCategory,
                        icon: CategoryIcons.get(effectiveCategory),
                        onTap: () async {
                          final selected = await SearchableSelectionSheet.show(
                            context,
                            title: 'Select Category',
                            items: categories,
                            selectedItem: effectiveCategory,
                            isCategory: true,
                            onAddNew: (query) async {
                              final created = await _promptAddCustom(
                                context,
                                true,
                                initialText: query,
                              );
                              if (created != null && mounted) {
                                setState(() => _selectedCategory = created);
                              }
                            },
                          );
                          if (selected != null && mounted) {
                            setState(() => _selectedCategory = selected);
                          }
                        },
                      ),
                      const SizedBox(width: 10),
                      _buildSearchableSelectorField(
                        label: 'Payment Method',
                        value: effectivePayment,
                        icon: CategoryIcons.getPaymentMethodIcon(effectivePayment),
                        onTap: () async {
                          final selected = await SearchableSelectionSheet.show(
                            context,
                            title: 'Select Payment Method',
                            items: paymentMethods,
                            selectedItem: effectivePayment,
                            isCategory: false,
                            onAddNew: (query) async {
                              final created = await _promptAddCustom(
                                context,
                                false,
                                initialText: query,
                              );
                              if (created != null && mounted) {
                                setState(() => _selectedPaymentMethod = created);
                              }
                            },
                          );
                          if (selected != null && mounted) {
                            setState(() => _selectedPaymentMethod = selected);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Optional Notes
                  TextFormField(
                    controller: _notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: 'Notes / Account Details (Optional)',
                      hintText: 'e.g. Account number, consumer ID, landlord UPI',
                      prefixIcon: const Icon(Icons.notes_rounded),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 2,
                      ),
                      child: Text(
                        widget.reminderToEdit == null ? 'Set Payment Reminder' : 'Update Reminder',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
