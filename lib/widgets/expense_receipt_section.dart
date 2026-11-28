import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import 'receipt_attachment_sheet.dart';

class ExpenseReceiptSection extends StatelessWidget {
  const ExpenseReceiptSection({
    super.key,
    this.receiptUrl,
    required this.title,
    required this.onAttach,
    required this.onRemove,
  });

  final String? receiptUrl;
  final String title;
  final VoidCallback? onAttach;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    const primaryColor = AppColors.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Bill & Receipt (Optional)',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Color(0xFF131B2E),
              ),
            ),
            if (receiptUrl != null)
              TextButton(
                onPressed: onRemove,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Remove Bill',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (receiptUrl == null)
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onAttach,
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
                    child: const Icon(
                      Icons.receipt_long_outlined,
                      color: primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attach Bill or Invoice',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: primaryColor,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Upload photo or take picture',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.add_circle_outline,
                    color: primaryColor,
                    size: 20,
                  ),
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
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap:
                      () => FullScreenReceiptViewer.show(
                        context,
                        imageUrl: receiptUrl!,
                        title: title,
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
                            receiptUrl!,
                            fit: BoxFit.cover,
                            errorBuilder:
                                (_, __, ___) => Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(
                                    Icons.broken_image,
                                    size: 20,
                                    color: Colors.grey,
                                  ),
                                ),
                          ),
                          Container(
                            color: Colors.black.withValues(alpha: 0.2),
                            child: const Icon(
                              Icons.zoom_in,
                              color: Colors.white,
                              size: 20,
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
                      const Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: primaryColor,
                            size: 15,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Receipt Attached',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: Color(0xFF131B2E),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Receipt attached securely',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed:
                      () => FullScreenReceiptViewer.show(
                        context,
                        imageUrl: receiptUrl!,
                        title: title,
                      ),
                  child: const Text(
                    'View',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
