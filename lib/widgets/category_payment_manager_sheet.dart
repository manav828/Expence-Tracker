import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../utils/category_icons.dart';
import 'category_icon_picker_dialog.dart';

class CategoryPaymentManagerSheet extends StatefulWidget {
  const CategoryPaymentManagerSheet({super.key});

  @override
  State<CategoryPaymentManagerSheet> createState() => _CategoryPaymentManagerSheetState();
}

class _CategoryPaymentManagerSheetState extends State<CategoryPaymentManagerSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _categorySortMode = 'custom'; // 'custom', 'most_used', 'az'
  String _paymentMethodSortMode = 'custom'; // 'custom', 'most_used', 'az'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _promptAdd(BuildContext context, bool isCategory) {
    final controller = TextEditingController();
    String selectedIconKey = isCategory ? 'category' : '';
    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final selectedIconData = isCategory
              ? (CategoryIcons.availableIcons.firstWhere(
                  (opt) => opt.key == selectedIconKey,
                  orElse: () => const CategoryIconOption(key: 'category', label: 'General', icon: Icons.category),
                ).icon)
              : Icons.category;

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(
              isCategory ? 'Add New Category' : 'Add Payment Method',
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
                    labelText: isCategory ? 'Category Name' : 'Payment Method Name',
                    hintText: isCategory ? 'e.g. Subscriptions, Fuel' : 'e.g. NetBanking, Wallet',
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
                                  color: const Color(0xFF006948).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(selectedIconData, color: const Color(0xFF006948), size: 20),
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
                  backgroundColor: const Color(0xFF006948),
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

  void _promptEdit(BuildContext context, bool isCategory, String currentName) {
    final controller = TextEditingController(text: currentName);
    String selectedIconKey = isCategory ? CategoryIcons.getKeyForCategory(currentName) : '';
    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final selectedIconData = isCategory
              ? (CategoryIcons.availableIcons.firstWhere(
                  (opt) => opt.key == selectedIconKey,
                  orElse: () => const CategoryIconOption(key: 'category', label: 'General', icon: Icons.category),
                ).icon)
              : Icons.category;

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(
              isCategory ? 'Edit Category' : 'Edit Payment Method',
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
                    labelText: isCategory ? 'Category Name' : 'Payment Method Name',
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
                                  color: const Color(0xFF006948).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(selectedIconData, color: const Color(0xFF006948), size: 20),
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
                  final newText = controller.text.trim();
                  if (newText.isNotEmpty) {
                    final provider = Provider.of<ExpenseProvider>(context, listen: false);
                    if (isCategory) {
                      if (newText != currentName) {
                        await CategoryIcons.renameCategory(currentName, newText);
                        await provider.updateCategory(currentName, newText);
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
                  backgroundColor: const Color(0xFF006948),
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

  void _confirmDelete(BuildContext context, bool isCategory, String name) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete $name?'),
        content: Text('Are you sure you want to remove "$name" from ${isCategory ? "categories" : "payment methods"}?'),
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
                await provider.deleteCategory(name);
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

  Widget _buildSortChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF006948).withValues(alpha: 0.12) : const Color(0xFFF2F3FF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isSelected ? const Color(0xFF006948) : Colors.black12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? const Color(0xFF006948) : const Color(0xFF6D7A72),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? const Color(0xFF006948) : const Color(0xFF6D7A72),
              ),
            ),
          ],
        ),
      ),
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
    final categories = <String>[];
    final seenCats = <String>{};
    for (final c in rawCategories) {
      final trimmed = c.trim();
      if (trimmed.isNotEmpty && seenCats.add(trimmed.toLowerCase())) {
        categories.add(trimmed);
      }
    }

    List<String> rawPaymentMethods;
    if (_paymentMethodSortMode == 'most_used') {
      rawPaymentMethods = provider.getSortedPaymentMethods(mostUsedFirst: true);
    } else if (_paymentMethodSortMode == 'az') {
      rawPaymentMethods = List<String>.from(provider.paymentMethods)..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    } else {
      rawPaymentMethods = List<String>.from(provider.paymentMethods);
    }
    final paymentMethods = <String>[];
    final seenPms = <String>{};
    for (final p in rawPaymentMethods) {
      final trimmed = p.trim();
      if (trimmed.isNotEmpty && seenPms.add(trimmed.toLowerCase())) {
        paymentMethods.add(trimmed);
      }
    }

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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
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
            labelColor: const Color(0xFF006948),
            unselectedLabelColor: const Color(0xFF6D7A72),
            indicatorColor: const Color(0xFF006948),
            tabs: const [
              Tab(text: 'Categories'),
              Tab(text: 'Payment Methods'),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Categories tab
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildSortChip(
                                    label: 'Drag & Drop',
                                    icon: Icons.drag_indicator,
                                    isSelected: _categorySortMode == 'custom',
                                    onTap: () => setState(() => _categorySortMode = 'custom'),
                                  ),
                                  const SizedBox(width: 6),
                                  _buildSortChip(
                                    label: 'Most Used',
                                    icon: Icons.local_fire_department,
                                    isSelected: _categorySortMode == 'most_used',
                                    onTap: () async {
                                      final sorted = provider.getSortedCategories(mostUsedFirst: true);
                                      await provider.setCustomCategoryOrder(sorted);
                                      setState(() => _categorySortMode = 'most_used');
                                    },
                                  ),
                                  const SizedBox(width: 6),
                                  _buildSortChip(
                                    label: 'A-Z',
                                    icon: Icons.sort_by_alpha,
                                    isSelected: _categorySortMode == 'az',
                                    onTap: () async {
                                      final sorted = List<String>.from(provider.categories)
                                        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
                                      await provider.setCustomCategoryOrder(sorted);
                                      setState(() => _categorySortMode = 'az');
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _promptAdd(context, true),
                            icon: const Icon(Icons.add, size: 16, color: Colors.white),
                            label: const Text('Add Category', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF006948),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        itemCount: categories.length,
                        onReorder: (oldIndex, newIndex) async {
                          setState(() => _categorySortMode = 'custom');
                          await provider.reorderCategories(oldIndex, newIndex);
                        },
                        itemBuilder: (ctx, i) {
                          final cat = categories[i];
                          final usageCount = provider.getCategoryUsageCount(cat);
                          final catIcon = CategoryIcons.get(cat);

                          return Container(
                            key: ValueKey('cat_$cat'),
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0x0F000000)),
                            ),
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              onTap: () => _promptEdit(context, true, cat),
                              leading: Tooltip(
                                message: 'Tap to change icon',
                                child: InkWell(
                                  onTap: () async {
                                    final currentKey = CategoryIcons.getKeyForCategory(cat);
                                    final picked = await CategoryIconPickerDialog.show(
                                      context,
                                      currentIconKey: currentKey,
                                    );
                                    if (picked != null && mounted) {
                                      await CategoryIcons.setCustomIcon(cat, picked.key);
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
                                        Icon(catIcon, size: 20, color: const Color(0xFF006948)),
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
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(cat, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                  ),
                                  if (usageCount > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEAEDFF),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${usageCount}x',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF3323CC)),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Text(
                                usageCount > 0 ? '$usageCount txns • Drag ⠿ to reorder' : 'Not used yet • Drag ⠿ to reorder',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF6D7A72)),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 19, color: Color(0xFF006948)),
                                    tooltip: 'Edit name & icon',
                                    onPressed: () => _promptEdit(context, true, cat),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 19, color: Color(0xFFBA1A1A)),
                                    tooltip: 'Delete',
                                    onPressed: () => _confirmDelete(context, true, cat),
                                  ),
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
                ),
                // Payment Methods tab
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildSortChip(
                                    label: 'Drag & Drop',
                                    icon: Icons.drag_indicator,
                                    isSelected: _paymentMethodSortMode == 'custom',
                                    onTap: () => setState(() => _paymentMethodSortMode = 'custom'),
                                  ),
                                  const SizedBox(width: 6),
                                  _buildSortChip(
                                    label: 'Most Used',
                                    icon: Icons.local_fire_department,
                                    isSelected: _paymentMethodSortMode == 'most_used',
                                    onTap: () async {
                                      final sorted = provider.getSortedPaymentMethods(mostUsedFirst: true);
                                      await provider.setCustomPaymentMethodOrder(sorted);
                                      setState(() => _paymentMethodSortMode = 'most_used');
                                    },
                                  ),
                                  const SizedBox(width: 6),
                                  _buildSortChip(
                                    label: 'A-Z',
                                    icon: Icons.sort_by_alpha,
                                    isSelected: _paymentMethodSortMode == 'az',
                                    onTap: () async {
                                      final sorted = List<String>.from(provider.paymentMethods)
                                        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
                                      await provider.setCustomPaymentMethodOrder(sorted);
                                      setState(() => _paymentMethodSortMode = 'az');
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _promptAdd(context, false),
                            icon: const Icon(Icons.add, size: 16, color: Colors.white),
                            label: const Text('Add Method', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF006948),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ReorderableListView.builder(
                        buildDefaultDragHandles: false,
                        itemCount: paymentMethods.length,
                        onReorder: (oldIndex, newIndex) async {
                          setState(() => _paymentMethodSortMode = 'custom');
                          await provider.reorderPaymentMethods(oldIndex, newIndex);
                        },
                        itemBuilder: (ctx, i) {
                          final pm = paymentMethods[i];
                          final usageCount = provider.getPaymentMethodUsageCount(pm);
                          final pmIcon = CategoryIcons.getPaymentMethodIcon(pm);

                          return Container(
                            key: ValueKey('pm_$pm'),
                            margin: const EdgeInsets.symmetric(vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0x0F000000)),
                            ),
                            child: ListTile(
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                              onTap: () => _promptEdit(context, false, pm),
                              leading: Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3323CC).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(pmIcon, size: 20, color: const Color(0xFF3323CC)),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(pm, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                  ),
                                  if (usageCount > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEAEDFF),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${usageCount}x',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF3323CC)),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Text(
                                usageCount > 0 ? '$usageCount txns • Drag ⠿ to reorder' : 'Not used yet • Drag ⠿ to reorder',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF6D7A72)),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 19, color: Color(0xFF006948)),
                                    tooltip: 'Edit name',
                                    onPressed: () => _promptEdit(context, false, pm),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 19, color: Color(0xFFBA1A1A)),
                                    tooltip: 'Delete',
                                    onPressed: () => _confirmDelete(context, false, pm),
                                  ),
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
