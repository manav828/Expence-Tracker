import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/expense_provider.dart';
import '../utils/category_icons.dart';

class SearchableSelectionSheet extends StatefulWidget {
  final String title;
  final List<String> items;
  final String? selectedItem;
  final bool isCategory;
  final VoidCallback? onAddNew;

  const SearchableSelectionSheet({
    super.key,
    required this.title,
    required this.items,
    this.selectedItem,
    required this.isCategory,
    this.onAddNew,
  });

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required List<String> items,
    String? selectedItem,
    required bool isCategory,
    VoidCallback? onAddNew,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SearchableSelectionSheet(
        title: title,
        items: items,
        selectedItem: selectedItem,
        isCategory: isCategory,
        onAddNew: onAddNew,
      ),
    );
  }

  @override
  State<SearchableSelectionSheet> createState() => _SearchableSelectionSheetState();
}

class _SearchableSelectionSheetState extends State<SearchableSelectionSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ExpenseProvider>();

    final filteredItems = widget.items.where((item) {
      if (_query.isEmpty) return true;
      return item.toLowerCase().contains(_query.toLowerCase().trim());
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Drag handle
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),

          // Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF131B2E),
                    letterSpacing: -0.3,
                  ),
                ),
                if (widget.onAddNew != null)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onAddNew!();
                    },
                    icon: const Icon(Icons.add, size: 16, color: Color(0xFF006948)),
                    label: const Text(
                      'Add New',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF006948),
                      ),
                    ),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: Color(0xFF6D7A72)),
                    onPressed: () => Navigator.pop(context),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              onChanged: (val) => setState(() => _query = val),
              decoration: InputDecoration(
                hintText: widget.isCategory ? 'Search category...' : 'Search payment method...',
                hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF6D7A72)),
                prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF006948)),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: Color(0xFF6D7A72)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF2F3FF),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Item Count & Sort Indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filteredItems.length} available',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6D7A72)),
                ),
                const Row(
                  children: [
                    Icon(Icons.sort, size: 13, color: Color(0xFF6D7A72)),
                    SizedBox(width: 4),
                    Text(
                      'Most used first',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF6D7A72)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 16),

          // List of Searchable Items
          Expanded(
            child: filteredItems.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            widget.isCategory ? Icons.category_outlined : Icons.payment_outlined,
                            size: 40,
                            color: const Color(0xFFBCCAC0),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No matches found for "$_query"',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF131B2E)),
                          ),
                          if (widget.onAddNew != null) ...[
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(context);
                                widget.onAddNew!();
                              },
                              icon: const Icon(Icons.add, size: 16, color: Colors.white),
                              label: Text('Create "$_query"', style: const TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF006948),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: filteredItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];
                      final isSelected = widget.selectedItem?.toLowerCase().trim() == item.toLowerCase().trim();
                      final usageCount = widget.isCategory
                          ? provider.getCategoryUsageCount(item)
                          : provider.getPaymentMethodUsageCount(item);
                      final icon = widget.isCategory
                          ? CategoryIcons.get(item)
                          : CategoryIcons.getPaymentMethodIcon(item);

                      return InkWell(
                        onTap: () => Navigator.pop(context, item),
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF85F8C4).withValues(alpha: 0.25) : const Color(0xFFF9FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF006948) : Colors.transparent,
                              width: 1.2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFF006948)
                                      : const Color(0xFF006948).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  icon,
                                  size: 20,
                                  color: isSelected ? Colors.white : const Color(0xFF006948),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                        color: const Color(0xFF131B2E),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      usageCount > 0 ? '$usageCount transactions logged' : 'Not used yet',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: usageCount > 0 ? const Color(0xFF3D4A42) : const Color(0xFF6D7A72),
                                        fontWeight: usageCount > 0 ? FontWeight.w600 : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle, color: Color(0xFF006948), size: 22)
                              else if (usageCount > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEAEDFF),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${usageCount}x',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF3323CC),
                                    ),
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
    );
  }
}
