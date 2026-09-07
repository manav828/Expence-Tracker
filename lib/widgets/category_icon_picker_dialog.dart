import 'package:flutter/material.dart';
import '../utils/category_icons.dart';

class CategoryIconPickerDialog extends StatefulWidget {
  final String? initialIconKey;

  const CategoryIconPickerDialog({super.key, this.initialIconKey});

  static Future<CategoryIconOption?> show(BuildContext context, {String? currentIconKey}) {
    return showDialog<CategoryIconOption>(
      context: context,
      builder: (_) => CategoryIconPickerDialog(initialIconKey: currentIconKey),
    );
  }

  @override
  State<CategoryIconPickerDialog> createState() => _CategoryIconPickerDialogState();
}

class _CategoryIconPickerDialogState extends State<CategoryIconPickerDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _filter = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allIcons = CategoryIcons.availableIcons;
    final filtered = allIcons.where((opt) {
      if (_filter.isEmpty) return true;
      return opt.label.toLowerCase().contains(_filter.toLowerCase().trim()) ||
          opt.key.toLowerCase().contains(_filter.toLowerCase().trim());
    }).toList();

    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Select Icon',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF131B2E)),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: Color(0xFF6D7A72)),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 380,
        child: Column(
          children: [
            // Search field
            TextField(
              controller: _searchController,
              autofocus: false,
              onChanged: (val) => setState(() => _filter = val),
              decoration: InputDecoration(
                hintText: 'Search icons (e.g. food, car, bill)...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF6D7A72)),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF006948)),
                filled: true,
                fillColor: const Color(0xFFF2F3FF),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Icon grid
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text('No matching icons found', style: TextStyle(color: Color(0xFF6D7A72))),
                    )
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.9,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final option = filtered[index];
                        final isSelected = widget.initialIconKey == option.key;

                        return InkWell(
                          onTap: () => Navigator.pop(context, option),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected ? const Color(0xFF85F8C4).withValues(alpha: 0.3) : const Color(0xFFF9FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF006948) : const Color(0x0F000000),
                                width: isSelected ? 1.5 : 1.0,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  option.icon,
                                  size: 26,
                                  color: isSelected ? const Color(0xFF006948) : const Color(0xFF131B2E),
                                ),
                                const SizedBox(height: 4),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                  child: Text(
                                    option.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                      color: isSelected ? const Color(0xFF006948) : const Color(0xFF6D7A72),
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Color(0xFF6D7A72))),
        ),
      ],
    );
  }
}
