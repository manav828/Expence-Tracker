import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../models/payment_reminder.dart';
import '../models/split_models.dart';
import '../providers/expense_provider.dart';
import '../providers/reminder_provider.dart';
import '../providers/split_provider.dart';
import '../services/split_service.dart';
import '../utils/category_icons.dart';

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

  bool _isSplitEnabled = false;
  String? _selectedSplitGroupId;
  ReminderSplitType _selectedSplitType = ReminderSplitType.splitExpense;
  String? _selectedTargetMemberId;
  List<SplitMember> _groupMembers = [];
  bool _isLoadingMembers = false;

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

    _isSplitEnabled = rem?.splitGroupId != null && rem!.splitGroupId!.isNotEmpty;
    _selectedSplitGroupId = rem?.splitGroupId;
    _selectedSplitType = rem?.splitType ?? ReminderSplitType.splitExpense;
    _selectedTargetMemberId = rem?.splitTargetMemberId;

    if (_selectedSplitGroupId != null) {
      _loadGroupMembers(_selectedSplitGroupId!);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _customDaysController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupMembers(String groupId) async {
    setState(() => _isLoadingMembers = true);
    try {
      final members = await SplitService.instance.getMembers(groupId);
      if (mounted) {
        setState(() {
          _groupMembers = members;
          _isLoadingMembers = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingMembers = false);
    }
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
      category: _selectedCategory,
      paymentMethod: _selectedPaymentMethod,
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
      splitGroupId: _isSplitEnabled ? _selectedSplitGroupId : null,
      splitType: _isSplitEnabled ? _selectedSplitType : ReminderSplitType.personal,
      splitTargetMemberId: _isSplitEnabled ? _selectedTargetMemberId : null,
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

  @override
  Widget build(BuildContext context) {
    final expenseProvider = context.watch<ExpenseProvider>();
    final splitProvider = context.watch<SplitProvider>();
    final categories = expenseProvider.categories;
    final paymentMethods = expenseProvider.paymentMethods;
    final groups = splitProvider.groups;

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

                  // Category & Payment Method Side-by-Side
                  Row(
                    children: [
                      // Category
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: categories.contains(_selectedCategory) ? _selectedCategory : categories.firstOrNull,
                          decoration: InputDecoration(
                            labelText: 'Category',
                            prefixIcon: Icon(CategoryIcons.get(_selectedCategory), size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          items: categories.map((cat) {
                            return DropdownMenuItem(
                              value: cat,
                              child: Text(cat, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedCategory = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Payment Method
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: paymentMethods.contains(_selectedPaymentMethod) ? _selectedPaymentMethod : paymentMethods.firstOrNull,
                          decoration: InputDecoration(
                            labelText: 'Payment Method',
                            prefixIcon: const Icon(Icons.payment_rounded, size: 20),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          items: paymentMethods.map((pm) {
                            return DropdownMenuItem(
                              value: pm,
                              child: Text(pm, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _selectedPaymentMethod = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Splitwise Group Integration Toggle
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _isSplitEnabled
                          ? AppColors.secondary.withValues(alpha: 0.06)
                          : AppColors.surfaceSubtle,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isSplitEnabled
                            ? AppColors.secondary.withValues(alpha: 0.3)
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.group_rounded,
                              color: _isSplitEnabled ? AppColors.secondary : AppColors.textMuted,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Split with Group',
                                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                                  ),
                                  Text(
                                    'Auto-split bill in Splitwise when paid',
                                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _isSplitEnabled,
                              activeColor: AppColors.secondary,
                              onChanged: (val) {
                                setState(() {
                                  _isSplitEnabled = val;
                                  if (val && groups.isNotEmpty && _selectedSplitGroupId == null) {
                                    _selectedSplitGroupId = groups.first.id;
                                    _loadGroupMembers(groups.first.id);
                                  }
                                });
                              },
                            ),
                          ],
                        ),

                        if (_isSplitEnabled) ...[
                          const Divider(height: 20),
                          if (groups.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 4),
                              child: Text(
                                'No Split groups created yet. Create a group in Split tab first.',
                                style: TextStyle(fontSize: 12, color: AppColors.warning),
                              ),
                            )
                          else ...[
                            // Group Selector
                            DropdownButtonFormField<String>(
                              value: groups.any((g) => g.id == _selectedSplitGroupId)
                                  ? _selectedSplitGroupId
                                  : groups.first.id,
                              decoration: InputDecoration(
                                labelText: 'Select Split Group',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                              items: groups.map((g) {
                                return DropdownMenuItem(value: g.id, child: Text(g.name));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedSplitGroupId = val);
                                  _loadGroupMembers(val);
                                }
                              },
                            ),
                            const SizedBox(height: 12),

                            // Split Type: Split Expense vs Settlement
                            Row(
                              children: [
                                Expanded(
                                  child: ChoiceChip(
                                    label: const Text('Split Expense'),
                                    selected: _selectedSplitType == ReminderSplitType.splitExpense,
                                    selectedColor: AppColors.secondary,
                                    labelStyle: TextStyle(
                                      color: _selectedSplitType == ReminderSplitType.splitExpense
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                    onSelected: (val) {
                                      if (val) setState(() => _selectedSplitType = ReminderSplitType.splitExpense);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ChoiceChip(
                                    label: const Text('Debt Settlement'),
                                    selected: _selectedSplitType == ReminderSplitType.settlement,
                                    selectedColor: AppColors.secondary,
                                    labelStyle: TextStyle(
                                      color: _selectedSplitType == ReminderSplitType.settlement
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                    onSelected: (val) {
                                      if (val) setState(() => _selectedSplitType = ReminderSplitType.settlement);
                                    },
                                  ),
                                ),
                              ],
                            ),

                            // If Settlement: Target Member Selector
                            if (_selectedSplitType == ReminderSplitType.settlement) ...[
                              const SizedBox(height: 12),
                              if (_isLoadingMembers)
                                const Center(child: CircularProgressIndicator())
                              else if (_groupMembers.isNotEmpty)
                                DropdownButtonFormField<String>(
                                  value: _groupMembers.any((m) => m.id == _selectedTargetMemberId)
                                      ? _selectedTargetMemberId
                                      : _groupMembers.first.id,
                                  decoration: InputDecoration(
                                    labelText: 'Member You Owe',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  items: _groupMembers.map((m) {
                                    return DropdownMenuItem(value: m.id, child: Text(m.name));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _selectedTargetMemberId = val);
                                  },
                                ),
                            ],
                          ],
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

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
