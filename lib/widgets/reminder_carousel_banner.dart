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
  final EdgeInsetsGeometry? margin;

  const ReminderCarouselBanner({super.key, this.margin});

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

    final activeIdx = _currentPage.clamp(0, reminders.length - 1);
    final hasMultiple = reminders.length > 1;
    const accentGreen = Color(0xFF00B16A);

    return Container(
      margin: widget.margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: hasMultiple ? 136 : 126,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6ECF2), width: 1),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF131B2E).withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            // Left Vertical Emerald Accent Bar
            const Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 5,
              child: ColoredBox(color: accentGreen),
            ),

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
                return _buildReminderItem(
                  context,
                  reminder,
                  provider,
                  hasMultiple: hasMultiple,
                );
              },
            ),

            // Bottom Dot Indicators (only if multiple items)
            if (hasMultiple)
              Positioned(
                bottom: 6,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(reminders.length, (dotIdx) {
                    final isSelected = dotIdx == activeIdx;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      width: isSelected ? 16 : 5,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? accentGreen
                            : const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderItem(
    BuildContext context,
    PaymentReminder reminder,
    ReminderProvider provider, {
    required bool hasMultiple,
  }) {
    final currencyFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    const accentGreen = Color(0xFF00B16A);

    final String dueLabel;
    final Color dueBg;
    final Color dueFg;
    if (reminder.isOverdue) {
      dueLabel = reminder.dueStatusText;
      dueBg = const Color(0xFFFFEDED);
      dueFg = const Color(0xFFD92D20);
    } else if (reminder.isDueToday) {
      dueLabel = 'Due today';
      dueBg = const Color(0xFFFFF4E5);
      dueFg = const Color(0xFFB45309);
    } else if (reminder.isDueTomorrow) {
      dueLabel = 'Due tomorrow';
      dueBg = const Color(0xFFFFF4E5);
      dueFg = const Color(0xFFB45309);
    } else {
      dueLabel = reminder.dueStatusText;
      dueBg = const Color(0xFFE8F7F0);
      dueFg = const Color(0xFF047857);
    }

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PaymentRemindersScreen()),
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: EdgeInsets.fromLTRB(18, 13, 16, hasMultiple ? 20 : 13),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Circular Icon + Title + Amount + Due Urgency Badge
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE8F7F0),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        CategoryIcons.get(reminder.category),
                        color: accentGreen,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      reminder.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        currencyFmt.format(reminder.amount),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: dueBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          dueLabel,
                          style: TextStyle(
                            color: dueFg,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Bottom Row: Mark Paid & Snooze Buttons
              Row(
                children: [
                  ElevatedButton.icon(
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
                                const Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
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
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text(
                      'Mark Paid',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: const StadiumBorder(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () => provider.dismissBannerForSession(),
                    icon: const Icon(
                      Icons.access_time_rounded,
                      size: 15,
                      color: Color(0xFF64748B),
                    ),
                    label: const Text(
                      'Snooze',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                        letterSpacing: -0.1,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(
                        color: Color(0xFFCBD5E1),
                        width: 1.2,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: const StadiumBorder(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
