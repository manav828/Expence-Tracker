import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/budget.dart';
import '../providers/budget_provider.dart';
import '../providers/expense_provider.dart';

class SetBudgetSheet extends StatefulWidget {
  final Budget? budgetToEdit;
  final String? initialCategory;
  final double? initialAmount;

  const SetBudgetSheet({
    super.key,
    this.budgetToEdit,
    this.initialCategory,
    this.initialAmount,
  });

  @override
  State<SetBudgetSheet> createState() => _SetBudgetSheetState();
}

class _SetBudgetSheetState extends State<SetBudgetSheet> {
  final TextEditingController _amountController = TextEditingController();
  String? _selectedCategory;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.budgetToEdit != null) {
      _selectedCategory = widget.budgetToEdit!.category;
      _amountController.text = widget.budgetToEdit!.monthlyLimit.toStringAsFixed(0);
    } else if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory;
      if (widget.initialAmount != null) {
        _amountController.text = widget.initialAmount!.toStringAsFixed(0);
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'dining':
      case 'dining & restaurants':
      case 'food & dining':
      case 'food':
        return Icons.restaurant;
      case 'groceries':
      case 'groceries & essentials':
        return Icons.shopping_cart;
      case 'housing':
      case 'housing & utilities':
      case 'rent':
        return Icons.roofing;
      case 'health':
      case 'health & wellness':
      case 'wellness':
        return Icons.favorite_border;
      case 'transport':
      case 'transport & fuel':
        return Icons.directions_car;
      case 'entertainment':
      case 'entertainment & streaming':
        return Icons.tv;
      case 'shopping':
        return Icons.shopping_bag;
      case 'tech & gear':
      case 'tech':
        return Icons.devices;
      case 'bills & utilities':
        return Icons.receipt;
      case 'investment':
        return Icons.trending_up;
      default:
        return Icons.category;
    }
  }

  void _addQuickAmount(double delta) {
    final current = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final updated = current + delta;
    _amountController.text = updated.toStringAsFixed(0);
    setState(() {});
  }

  Future<void> _saveBudget() async {
    if (_selectedCategory == null || _selectedCategory!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final limit = double.tryParse(_amountController.text.trim());
    if (limit == null || limit <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid monthly limit'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await context.read<BudgetProvider>().setBudget(_selectedCategory!, limit);
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Monthly budget of ₹${limit.toStringAsFixed(0)} saved for $_selectedCategory'),
            backgroundColor: const Color(0xFF006948),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving budget: $e'), backgroundColor: const Color(0xFFBA1A1A)),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteBudget() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Remove Limit', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF131B2E))),
        content: Text('Remove monthly budget for $_selectedCategory?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6D7A72))),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove', style: TextStyle(color: Color(0xFFBA1A1A), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      if (widget.budgetToEdit?.id != null) {
        await context.read<BudgetProvider>().deleteBudget(widget.budgetToEdit!.id!);
      } else if (_selectedCategory != null) {
        await context.read<BudgetProvider>().deleteBudgetByCategory(_selectedCategory!);
      }
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Budget limit removed'),
            backgroundColor: Color(0xFF006948),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = context.watch<ExpenseProvider>().categories;
    final isEditing = widget.budgetToEdit != null;

    if (_selectedCategory == null && categories.isNotEmpty) {
      _selectedCategory = categories.first;
    }

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: Color(0x1F131B2E), blurRadius: 32, offset: Offset(0, -8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFBCCAC0).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Sheet Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isEditing ? 'Edit Budget' : 'Add Budget',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF131B2E),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Monthly category spending limit',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6D7A72)),
                  ),
                ],
              ),
              InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF2F3FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 18, color: Color(0xFF6D7A72)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Category Selector Label
          const Text(
            'CATEGORY',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: Color(0xFF6D7A72),
            ),
          ),
          const SizedBox(height: 8),

          // Horizontal Category Pills
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = categories[index];
                final isSelected = _selectedCategory == cat;
                final catIcon = _getCategoryIcon(cat);

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedCategory = cat;
                      final existing = context.read<BudgetProvider>().getBudgetForCategory(cat);
                      if (existing != null) {
                        _amountController.text = existing.monthlyLimit.toStringAsFixed(0);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF85F8C4) : const Color(0xFFF2F3FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          catIcon,
                          size: 15,
                          color: isSelected ? const Color(0xFF002114) : const Color(0xFF131B2E),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          cat,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? const Color(0xFF002114) : const Color(0xFF131B2E),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 18),

          // Amount Input Header with Clear Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'MONTHLY LIMIT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                  color: Color(0xFF6D7A72),
                ),
              ),
              InkWell(
                onTap: () {
                  _amountController.clear();
                  setState(() {});
                },
                child: const Text(
                  'Clear',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFBA1A1A)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Amount Input Container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF2F3FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFBCCAC0).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Text(
                  '₹',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF131B2E),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF131B2E),
                    ),
                    decoration: const InputDecoration(
                      hintText: '0',
                      hintStyle: TextStyle(fontSize: 26, color: Color(0xFF8C9BA2), fontWeight: FontWeight.w700),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Quick Increment Buttons
          Row(
            children: [
              _buildQuickIncrementChip('+₹1k', 1000),
              const SizedBox(width: 8),
              _buildQuickIncrementChip('+₹2.5k', 2500),
              const SizedBox(width: 8),
              _buildQuickIncrementChip('+₹5k', 5000),
              const SizedBox(width: 8),
              _buildQuickIncrementChip('+₹10k', 10000),
            ],
          ),
          const SizedBox(height: 20),

          // Save Envelope Budget CTA
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveBudget,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006948),
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
                elevation: 3,
                shadowColor: const Color(0x40006948),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Save Budget',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
            ),
          ),

          // Delete Limit CTA (if editing)
          if (isEditing) ...[
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: _deleteBudget,
                icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFBA1A1A)),
                label: const Text(
                  'Remove Limit',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFBA1A1A),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickIncrementChip(String label, double amount) {
    return Expanded(
      child: InkWell(
        onTap: () => _addQuickAmount(amount),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFEAEDFF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF131B2E),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
