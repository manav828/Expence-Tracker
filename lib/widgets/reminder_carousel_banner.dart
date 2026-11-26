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

    final activeIdx = _currentPage.clamp(0, reminders.length - 1);
    final activeReminder = reminders[activeIdx];
    final palette = _bannerPalette(activeReminder);
    final hasMultiple = reminders.length > 1;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: hasMultiple ? 120 : 112,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, palette.surfaceTint],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF131B2E).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
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
              return _buildReminderItem(
                context,
                reminder,
                provider,
                hasMultiple: hasMultiple,
              );
            },
          ),

          // Dismiss 'X' Button on top-right
          Positioned(
            top: 10,
            right: 10,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: () => provider.dismissBannerForSession(),
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF64748B),
                    size: 14,
                  ),
                ),
              ),
            ),
          ),

          // Bottom Dot Indicators (only if multiple items)
          if (hasMultiple)
            Positioned(
              bottom: 7,
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
                          ? palette.accentColor
                          : const Color(0xFFD1D5DB),
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

  _BannerPalette _bannerPalette(PaymentReminder reminder) {
    if (reminder.isOverdue) {
      return const _BannerPalette(
        accentColor: Color(0xFFDC2626),
        iconBg: Color(0xFFFEE2E2),
        tagBg: Color(0xFFFEE2E2),
        tagText: Color(0xFFB91C1C),
        borderColor: Color(0xFFFECACA),
        surfaceTint: Color(0xFFFFF8F8),
      );
    }
    if (reminder.isDueToday) {
      return const _BannerPalette(
        accentColor: Color(0xFFD97706),
        iconBg: Color(0xFFFEF3C7),
        tagBg: Color(0xFFFEF3C7),
        tagText: Color(0xFFB45309),
        borderColor: Color(0xFFFDE68A),
        surfaceTint: Color(0xFFFFFCF3),
      );
    }
    return const _BannerPalette(
      accentColor: AppColors.primary,
      iconBg: AppColors.primaryLight,
      tagBg: AppColors.primaryFill,
      tagText: AppColors.primary,
      borderColor: AppColors.primaryBorder,
      surfaceTint: Color(0xFFF5FCF8),
    );
  }

  Widget _buildReminderItem(
    BuildContext context,
    PaymentReminder reminder,
    ReminderProvider provider, {
    required bool hasMultiple,
  }) {
    final currencyFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);
    final palette = _bannerPalette(reminder);

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
          padding: EdgeInsets.fromLTRB(14, 12, 14, hasMultiple ? 20 : 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Category Icon Badge
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: palette.iconBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Icon(
                        CategoryIcons.get(reminder.category),
                        color: palette.accentColor,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Title, Status Pill & Frequency
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  reminder.title,
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (reminder.splitGroupId != null) ...[
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.group_rounded,
                                  color: AppColors.textMuted,
                                  size: 14,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.tagBg,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  reminder.dueStatusText,
                                  style: TextStyle(
                                    color: palette.tagText,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  reminder.frequency.label,
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Bottom Row: Amount + 1-Tap "Mark Paid" Action
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    currencyFmt.format(reminder.amount),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
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
                    icon: const Icon(Icons.check_rounded, size: 15),
                    label: const Text(
                      'Mark Paid',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.1,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 7,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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

class _BannerPalette {
  final Color accentColor;
  final Color iconBg;
  final Color tagBg;
  final Color tagText;
  final Color borderColor;
  final Color surfaceTint;

  const _BannerPalette({
    required this.accentColor,
    required this.iconBg,
    required this.tagBg,
    required this.tagText,
    required this.borderColor,
    required this.surfaceTint,
  });
}
