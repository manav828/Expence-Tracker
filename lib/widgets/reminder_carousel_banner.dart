import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../models/payment_reminder.dart';
import '../providers/expense_provider.dart';
import '../providers/reminder_provider.dart';
import '../screens/payment_reminders_screen.dart';
import '../utils/category_icons.dart';

class ReminderCarouselBanner extends StatefulWidget {
  const ReminderCarouselBanner({super.key});

  @override
  State<ReminderCarouselBanner> createState() => _ReminderCarouselBannerState();
}

class _ReminderCarouselBannerState extends State<ReminderCarouselBanner> {
  late final PageController _pageController;
  Timer? _autoRotateTimer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoRotate();
  }

  @override
  void dispose() {
    _autoRotateTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoRotate() {
    _autoRotateTimer?.cancel();
    _autoRotateTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients) return;
      final provider = context.read<ReminderProvider>();
      final count = provider.dashboardActionableReminders.length;
      if (count <= 1) return;

      final nextPage = (_currentPage + 1) % count;
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  void _restartAutoRotate() {
    _autoRotateTimer?.cancel();
    _startAutoRotate();
  }

  @override
  Widget build(BuildContext context) {
    final ReminderProvider provider;
    try {
      provider = Provider.of<ReminderProvider>(context);
    } catch (_) {
      return const SizedBox.shrink();
    }

    if (provider.isBannerDismissed) return const SizedBox.shrink();

    final reminders = provider.dashboardActionableReminders;
    if (reminders.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 82,
      decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Swipeable & Auto-rotating PageView
              PageView.builder(
                controller: _pageController,
                itemCount: reminders.length,
                onPageChanged: (idx) {
                  setState(() => _currentPage = idx);
                  _restartAutoRotate();
                },
                itemBuilder: (context, idx) {
                  final reminder = reminders[idx];
                  return _buildReminderItem(context, reminder, provider);
                },
              ),

              // Dismiss 'X' Button on top-right
              Positioned(
                top: 6,
                right: 6,
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: () => provider.dismissBannerForSession(),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white70,
                        size: 14,
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom Dot Indicators (only if multiple items)
              if (reminders.length > 1)
                Positioned(
                  bottom: 5,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(reminders.length, (dotIdx) {
                      final isSelected = dotIdx == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        width: isSelected ? 14 : 5,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.accentMint : Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                ),
            ],
          ),
        );
  }

  Widget _buildReminderItem(
    BuildContext context,
    PaymentReminder reminder,
    ReminderProvider provider,
  ) {
    final currencyFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final isOverdue = reminder.isOverdue;
    final isDueToday = reminder.isDueToday;

    Color tagColor;
    Color tagBg;
    if (isOverdue) {
      tagColor = const Color(0xFFFF5252);
      tagBg = const Color(0x33FF5252);
    } else if (isDueToday) {
      tagColor = const Color(0xFFFFB300);
      tagBg = const Color(0x33FFB300);
    } else {
      tagColor = const Color(0xFF818CF8);
      tagBg = const Color(0x33818CF8);
    }

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PaymentRemindersScreen()),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 36, 12),
          child: Row(
            children: [
            // Category Icon Badge
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Center(
                child: Icon(
                  CategoryIcons.get(reminder.category),
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Title & Due Tag
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          reminder.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Due Status Tag
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: tagBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          reminder.dueStatusText,
                          style: TextStyle(
                            color: tagColor,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (reminder.splitGroupId != null) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.group_rounded, color: Colors.white70, size: 12),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${currencyFmt.format(reminder.amount)} • ${reminder.frequency.label}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // 1-Tap "Mark Paid" Button
            ElevatedButton(
              onPressed: () async {
                final expenseProvider = context.read<ExpenseProvider>();
                final paid = await provider.markAsPaid(
                  reminder.id,
                  expenseProvider: expenseProvider,
                );
                if (context.mounted && paid != null) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Paid ${currencyFmt.format(reminder.amount)} for ${reminder.title}! Logged to history.',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: AppColors.primary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentMint,
                foregroundColor: AppColors.onAccentMint,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Mark Paid',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
