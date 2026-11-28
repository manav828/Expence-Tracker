import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../utils/category_icons.dart';
import 'category_icon_picker_dialog.dart';
import '../core/theme/app_colors.dart';


class CategoryPaymentManagerSheet extends StatefulWidget {
  const CategoryPaymentManagerSheet({super.key});

  @override
  State<CategoryPaymentManagerSheet> createState() => _CategoryPaymentManagerSheetState();
}

class _CategoryPaymentManagerSheetState extends State<CategoryPaymentManagerSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _categorySortMode = 'custom'; // 'custom', 'most_used', 'az'
  String _incomeCategorySortMode = 'custom'; // 'custom', 'most_used', 'az'
  String _paymentMethodSortMode = 'custom'; // 'custom', 'most_used', 'az'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _promptAdd(BuildContext context, bool isCategory, {bool isIncome = false}) {
    final controller = TextEditingController();
    String? selectedIconKey;
    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final selectedIconData = isCategory
              ? CategoryIcons.optionForKey(selectedIconKey ?? CategoryIcons.getKeyForCategory(controller.text)).icon
              : Icons.category;

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(
              isCategory
                  ? (isIncome ? 'Add New Income Category' : 'Add New Category')
                  : 'Add Payment Method',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF131B2E)),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  autofocus: true,
                  onChanged: (_) => setDialogState(() {}),
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: isCategory
                        ? (isIncome ? 'Income Category Name' : 'Category Name')
                        : 'Payment Method Name',
                    hintText: isCategory
                        ? (isIncome ? 'e.g. Bonus, Consulting, Dividend' : 'e.g. Subscriptions, Fuel')
                        : 'e.g. NetBanking, Wallet',
                    filled: true,
                    fillColor: const Color(0xFFF2F3FF),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                if (isCategory) ...[
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await CategoryIconPickerDialog.show(
                        context,
                        currentIconKey: selectedIconKey ?? CategoryIcons.getKeyForCategory(controller.text),
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedIconKey = picked.key;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(selectedIconData, color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Select Icon',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF131B2E)),
                              ),
                            ],
                          ),
                          const Row(
                            children: [
                              Text(
                                'Choose',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                              Icon(Icons.chevron_right, size: 18, color: AppColors.primary),
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
                      final iconKey = selectedIconKey;
                      if (iconKey != null) await CategoryIcons.setCustomIcon(text, iconKey);
                      if (isIncome) {
                        await provider.addIncomeCategory(text);
                      } else {
                        await provider.addCategory(text);
                      }
                    } else {
                      await provider.addPaymentMethod(text);
                    }
                    if (dialogCtx.mounted) {
                      Navigator.pop(dialogCtx);
                    }
                    if (mounted) setState(() {});
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _promptEdit(BuildContext context, bool isCategory, String currentName, {bool isIncome = false}) {
    final controller = TextEditingController(text: currentName);
    String selectedIconKey = isCategory ? CategoryIcons.getKeyForCategory(currentName) : '';
    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final selectedIconData = isCategory
              ? CategoryIcons.optionForKey(selectedIconKey).icon
              : Icons.category;

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(
              isCategory
                  ? (isIncome ? 'Edit Income Category' : 'Edit Category')
                  : 'Edit Payment Method',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF131B2E)),
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
                    labelText: isCategory
                        ? (isIncome ? 'Income Category Name' : 'Category Name')
                        : 'Payment Method Name',
                    filled: true,
                    fillColor: const Color(0xFFF2F3FF),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  ),
                ),
                if (isCategory) ...[
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final picked = await CategoryIconPickerDialog.show(
                        context,
                        currentIconKey: selectedIconKey,
                      );
                      if (picked != null) {
                        setDialogState(() {
                          selectedIconKey = picked.key;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(selectedIconData, color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Change Icon',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF131B2E)),
                              ),
                            ],
                          ),
                          const Row(
                            children: [
                              Text(
                                'Choose',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                              ),
                              Icon(Icons.chevron_right, size: 18, color: AppColors.primary),
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
                  final newText = controller.text.trim();
                  if (newText.isNotEmpty) {
                    final provider = Provider.of<ExpenseProvider>(context, listen: false);
                    if (isCategory) {
                      if (newText != currentName) {
                        await CategoryIcons.renameCategory(currentName, newText);
                        if (isIncome) {
                          await provider.updateIncomeCategory(currentName, newText);
                        } else {
                          await provider.updateCategory(currentName, newText);
                        }
                      }
                      await CategoryIcons.setCustomIcon(newText, selectedIconKey);
                    } else {
                      if (newText != currentName) {
                        await provider.updatePaymentMethod(currentName, newText);
                      }
                    }
                    if (dialogCtx.mounted) {
                      Navigator.pop(dialogCtx);
                    }
                    if (mounted) setState(() {});
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, bool isCategory, String name, {bool isIncome = false}) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete $name?'),
        content: Text('Are you sure you want to remove "$name" from ${isCategory ? (isIncome ? "income categories" : "categories") : "payment methods"}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6D7A72))),
          ),
          TextButton(
            onPressed: () async {
              final provider = Provider.of<ExpenseProvider>(context, listen: false);
              if (isCategory) {
                await CategoryIcons.deleteCategory(name);
                if (isIncome) {
                  await provider.deleteIncomeCategory(name);
                } else {
                  await provider.deleteCategory(name);
                }
              } else {
                await provider.deletePaymentMethod(name);
              }
              if (mounted) setState(() {});
              if (dialogCtx.mounted) {
                Navigator.pop(dialogCtx);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Color(0xFFBA1A1A), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  List<String> _dedupeAndFilter(List<String> raw) {
    final result = <String>[];
    final seen = <String>{};
    final q = _searchQuery.trim().toLowerCase();
    for (final item in raw) {
      final trimmed = item.trim();
      if (trimmed.isNotEmpty && seen.add(trimmed.toLowerCase())) {
        if (q.isEmpty || trimmed.toLowerCase().contains(q)) {
          result.add(trimmed);
        }
      }
    }
    return result;
  }

  Widget _buildManagerTab({
    required BuildContext context,
    required ExpenseProvider provider,
    required List<String> items,
    required bool isCategory,
    required bool isIncome,
    required String sortMode,
    required String addButtonLabel,
    required String searchHint,
    required Future<void> Function(int oldIndex, int newIndex) onReorder,
    required Future<void> Function(String mode) onSelectSort,
  }) {
    final isSearching = _searchQuery.trim().isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: searchHint,
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF6D7A72)),
                    prefixIcon: const Icon(Icons.search, size: 19, color: AppColors.primary),
                    suffixIcon: isSearching
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 17, color: Color(0xFF6D7A72)),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    isDense: true,
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                tooltip: 'Sort & Filter',
                onSelected: onSelectSort,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                    value: 'most_used',
                    child: Row(
                      children: [
                        Icon(
                          Icons.local_fire_department,
                          size: 17,
                          color: sortMode == 'most_used' ? AppColors.primary : const Color(0xFF6D7A72),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Most Used',
                          style: TextStyle(
                            fontWeight: sortMode == 'most_used' ? FontWeight.w700 : FontWeight.w500,
                            color: sortMode == 'most_used' ? AppColors.primary : const Color(0xFF131B2E),
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'az',
                    child: Row(
                      children: [
                        Icon(
                          Icons.sort_by_alpha,
                          size: 17,
                          color: sortMode == 'az' ? AppColors.primary : const Color(0xFF6D7A72),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'A-Z',
                          style: TextStyle(
                            fontWeight: sortMode == 'az' ? FontWeight.w700 : FontWeight.w500,
                            color: sortMode == 'az' ? AppColors.primary : const Color(0xFF131B2E),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: sortMode != 'custom'
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: sortMode != 'custom' ? AppColors.primary : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Icon(
                    Icons.tune_rounded,
                    size: 19,
                    color: sortMode != 'custom' ? AppColors.primary : const Color(0xFF3D4A42),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () => _promptAdd(context, isCategory, isIncome: isIncome),
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                label: Text(
                  addButtonLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  iconColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    isSearching ? 'No matches for "$_searchQuery"' : 'No items yet',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF6D7A72)),
                  ),
                )
              : ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: items.length,
                  onReorder: (oldIndex, newIndex) async {
                    if (isSearching) return;
                    await onReorder(oldIndex, newIndex);
                  },
                  itemBuilder: (ctx, i) {
                    final item = items[i];
                    final itemIcon = isCategory
                        ? CategoryIcons.get(item)
                        : CategoryIcons.getPaymentMethodIcon(item);

                    return Container(
                      key: ValueKey('${isCategory ? (isIncome ? "inc" : "cat") : "pm"}_$item'),
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x0F000000)),
                      ),
                      child: ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        onTap: () => _promptEdit(context, isCategory, item, isIncome: isIncome),
                        leading: isCategory
                            ? Tooltip(
                                message: 'Tap to change icon',
                                child: InkWell(
                                  onTap: () async {
                                    final currentKey = CategoryIcons.getKeyForCategory(item);
                                    final picked = await CategoryIconPickerDialog.show(
                                      context,
                                      currentIconKey: currentKey,
                                    );
                                    if (picked != null && mounted) {
                                      await CategoryIcons.setCustomIcon(item, picked.key);
                                      setState(() {});
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Icon(itemIcon, size: 20, color: AppColors.primary),
                                        Positioned(
                                          bottom: 1,
                                          right: 1,
                                          child: Container(
                                            padding: const EdgeInsets.all(1.5),
                                            decoration: const BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.edit, size: 8, color: AppColors.primary),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(itemIcon, size: 20, color: AppColors.primary),
                              ),
                        title: Text(
                          item,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 19, color: AppColors.primary),
                              tooltip: isCategory ? 'Edit name & icon' : 'Edit name',
                              onPressed: () => _promptEdit(context, isCategory, item, isIncome: isIncome),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 19, color: Color(0xFFBA1A1A)),
                              tooltip: 'Delete',
                              onPressed: () => _confirmDelete(context, isCategory, item, isIncome: isIncome),
                            ),
                            if (!isSearching)
                              ReorderableDragStartListener(
                                index: i,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                  child: const Icon(Icons.drag_indicator, size: 22, color: Color(0xFF6D7A72)),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<ExpenseProvider>(context);

    List<String> rawCategories;
    if (_categorySortMode == 'most_used') {
      rawCategories = provider.getSortedCategories(mostUsedFirst: true);
    } else if (_categorySortMode == 'az') {
      rawCategories = List<String>.from(provider.categories)..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    } else {
      rawCategories = List<String>.from(provider.categories);
    }
    final categories = _dedupeAndFilter(rawCategories);

    List<String> rawIncomeCategories;
    if (_incomeCategorySortMode == 'most_used') {
      rawIncomeCategories = provider.getSortedIncomeCategories(mostUsedFirst: true);
    } else if (_incomeCategorySortMode == 'az') {
      rawIncomeCategories = List<String>.from(provider.incomeCategories)..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    } else {
      rawIncomeCategories = List<String>.from(provider.incomeCategories);
    }
    final incomeCategories = _dedupeAndFilter(rawIncomeCategories);

    List<String> rawPaymentMethods;
    if (_paymentMethodSortMode == 'most_used') {
      rawPaymentMethods = provider.getSortedPaymentMethods(mostUsedFirst: true);
    } else if (_paymentMethodSortMode == 'az') {
      rawPaymentMethods = List<String>.from(provider.paymentMethods)..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    } else {
      rawPaymentMethods = List<String>.from(provider.paymentMethods);
    }
    final paymentMethods = _dedupeAndFilter(rawPaymentMethods);

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
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
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Categories & Methods',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF131B2E)),
                  ),
                  Text(
                    'Drag ⠿ to reorder • Tap pencil to edit',
                    style: TextStyle(fontSize: 12, color: Color(0xFF6D7A72)),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF3D4A42)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: const Color(0xFF6D7A72),
            indicatorColor: AppColors.primary,
            labelPadding: const EdgeInsets.symmetric(horizontal: 6),
            tabs: const [
              Tab(text: 'Categories'),
              Tab(text: 'Income'),
              Tab(text: 'Methods'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildManagerTab(
                  context: context,
                  provider: provider,
                  items: categories,
                  isCategory: true,
                  isIncome: false,
                  sortMode: _categorySortMode,
                  addButtonLabel: 'Add Category',
                  searchHint: 'Search categories...',
                  onReorder: (oldIndex, newIndex) async {
                    setState(() => _categorySortMode = 'custom');
                    await provider.reorderCategories(oldIndex, newIndex);
                  },
                  onSelectSort: (mode) async {
                    if (mode == 'most_used') {
                      final sorted = provider.getSortedCategories(mostUsedFirst: true);
                      await provider.setCustomCategoryOrder(sorted);
                    } else if (mode == 'az') {
                      final sorted = List<String>.from(provider.categories)
                        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
                      await provider.setCustomCategoryOrder(sorted);
                    }
                    setState(() => _categorySortMode = mode);
                  },
                ),
                _buildManagerTab(
                  context: context,
                  provider: provider,
                  items: incomeCategories,
                  isCategory: true,
                  isIncome: true,
                  sortMode: _incomeCategorySortMode,
                  addButtonLabel: 'Add Income',
                  searchHint: 'Search income...',
                  onReorder: (oldIndex, newIndex) async {
                    setState(() => _incomeCategorySortMode = 'custom');
                    await provider.reorderIncomeCategories(oldIndex, newIndex);
                  },
                  onSelectSort: (mode) async {
                    if (mode == 'most_used') {
                      final sorted = provider.getSortedIncomeCategories(mostUsedFirst: true);
                      await provider.setCustomIncomeCategoryOrder(sorted);
                    } else if (mode == 'az') {
                      final sorted = List<String>.from(provider.incomeCategories)
                        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
                      await provider.setCustomIncomeCategoryOrder(sorted);
                    }
                    setState(() => _incomeCategorySortMode = mode);
                  },
                ),
                _buildManagerTab(
                  context: context,
                  provider: provider,
                  items: paymentMethods,
                  isCategory: false,
                  isIncome: false,
                  sortMode: _paymentMethodSortMode,
                  addButtonLabel: 'Add Method',
                  searchHint: 'Search methods...',
                  onReorder: (oldIndex, newIndex) async {
                    setState(() => _paymentMethodSortMode = 'custom');
                    await provider.reorderPaymentMethods(oldIndex, newIndex);
                  },
                  onSelectSort: (mode) async {
                    if (mode == 'most_used') {
                      final sorted = provider.getSortedPaymentMethods(mostUsedFirst: true);
                      await provider.setCustomPaymentMethodOrder(sorted);
                    } else if (mode == 'az') {
                      final sorted = List<String>.from(provider.paymentMethods)
                        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
                      await provider.setCustomPaymentMethodOrder(sorted);
                    }
                    setState(() => _paymentMethodSortMode = mode);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
