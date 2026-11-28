import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../utils/category_icons.dart';

class CategoryIconPickerDialog extends StatefulWidget {
  final String? initialIconKey;

  const CategoryIconPickerDialog({super.key, this.initialIconKey});

  static Future<CategoryIconOption?> show(
    BuildContext context, {
    String? currentIconKey,
  }) {
    return showDialog<CategoryIconOption>(
      context: context,
      builder: (_) => CategoryIconPickerDialog(initialIconKey: currentIconKey),
    );
  }

  @override
  State<CategoryIconPickerDialog> createState() =>
      _CategoryIconPickerDialogState();
}

class _CategoryIconPickerDialogState extends State<CategoryIconPickerDialog> {
  CategoryIconGroup? _group;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final group = _group;
    final options =
        group == null
            ? CategoryIcons.availableIcons
            : CategoryIcons.groups[group]!;
    final results = options.where((option) => option.matches(_query)).toList();

    return AlertDialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
      contentPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(
        children: [
          const Expanded(child: Text('Choose an icon')),
          IconButton(
            tooltip: 'Close icon picker',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      content: SizedBox(
        width: 544,
        height: 412,
        child: Column(
          children: [
            TextField(
              onChanged: (value) => setState(() => _query = value.trim()),
              decoration: InputDecoration(
                labelText: 'Search icons',
                hintText: 'Try metro, salary, or coffee',
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.primary,
                ),
                filled: true,
                fillColor: AppColors.surfaceSubtle,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _groupChip('All', null),
                  for (final group in CategoryIconGroup.values)
                    _groupChip(group.label, group),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child:
                  results.isEmpty
                      ? const Center(
                        child: Text(
                          'No icons match. Try another search or choose All.',
                          textAlign: TextAlign.center,
                        ),
                      )
                      : LayoutBuilder(
                        builder: (context, constraints) {
                          final textScaler = MediaQuery.textScalerOf(context);
                          return GridView.builder(
                            key: ValueKey((_group, _query)),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount:
                                      (constraints.maxWidth / 88)
                                          .floor()
                                          .clamp(2, 5)
                                          .toInt(),
                                  crossAxisSpacing: 8,
                                  mainAxisSpacing: 8,
                                  mainAxisExtent: 46 + textScaler.scale(24),
                                ),
                            itemCount: results.length,
                            itemBuilder:
                                (context, index) =>
                                    _buildOption(results[index]),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupChip(String label, CategoryIconGroup? group) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        showCheckmark: false,
        label: Text(label),
        selected: _group == group,
        selectedColor: AppColors.primaryLight,
        labelStyle: TextStyle(
          color:
              _group == group ? AppColors.primaryDark : AppColors.textSecondary,
        ),
        onSelected: (_) => setState(() => _group = group),
      ),
    );
  }

  Widget _buildOption(CategoryIconOption option) {
    final selected = widget.initialIconKey == option.key;
    final borderRadius = BorderRadius.circular(12);
    return Tooltip(
      message: option.label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? AppColors.primaryLight : AppColors.surfaceSubtle,
          shape: RoundedRectangleBorder(
            borderRadius: borderRadius,
            side: BorderSide(
              color: selected ? AppColors.primary : AppColors.borderSubtle,
            ),
          ),
          child: InkWell(
            borderRadius: borderRadius,
            onTap: () => Navigator.pop(context, option),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    option.icon,
                    size: 23,
                    color: selected ? AppColors.primary : AppColors.textPrimary,
                  ),
                  const SizedBox(height: 4),
                  Flexible(
                    child: Text(
                      option.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, height: 1.1),
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
