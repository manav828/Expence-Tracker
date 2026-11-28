import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../models/app_notification.dart';
import '../models/payment_reminder.dart';
import '../providers/budget_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/reminder_provider.dart';
import '../services/announcement_service.dart';
import '../utils/category_icons.dart';

/// Unified Notification Center bottom sheet opened by the top-bar Bell icon.
/// Combines urgent Payment Reminders, Budget Alerts (>=80% / Over Budget),
/// and promotional/update messages from [AnnouncementService].
class NotificationsSheet extends StatelessWidget {
  final void Function(String route)? onNavigateRoute;

  const NotificationsSheet({super.key, this.onNavigateRoute});

  static int computeBadgeCount({
    required ReminderProvider reminderProvider,
    required BudgetProvider budgetProvider,
    required ExpenseProvider expenseProvider,
    required AnnouncementService announcementService,
  }) {
    final urgentBills = reminderProvider.notificationBadgeCount;
    final budgetAlerts = budgetProvider
        .getAllBudgetProgress(expenseProvider.expenses)
        .where((p) => p.isOverspent || p.isNearLimit)
        .length;
    final promoUnread = announcementService.unreadCount;
    return urgentBills + budgetAlerts + promoUnread;
  }

  static Future<void> show(
    BuildContext context, {
    void Function(String route)? onNavigateRoute,
  }) {
    AnnouncementService.instance.refresh();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NotificationsSheet(onNavigateRoute: onNavigateRoute),
    );
  }

  void _handleRoute(BuildContext context, String route) {
    Navigator.of(context).pop();
    onNavigateRoute?.call(route);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AnnouncementService.instance,
      builder: (context, _) {
        final remProvider = context.watch<ReminderProvider>();
        final budgetProvider = context.watch<BudgetProvider>();
        final expenseProvider = context.watch<ExpenseProvider>();
        final annService = AnnouncementService.instance;

        final urgentReminders = [
          ...remProvider.overdueReminders,
          ...remProvider.dueTodayReminders,
          ...remProvider.dueTomorrowReminders,
        ];
        final budgetAlerts = budgetProvider
            .getAllBudgetProgress(expenseProvider.expenses)
            .where((p) => p.isOverspent || p.isNearLimit)
            .toList()
          ..sort((a, b) => b.percentage.compareTo(a.percentage));
        final announcements = annService.activeAnnouncements;

        final totalCount =
            urgentReminders.length + budgetAlerts.length + announcements.length;
        final currencyFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');

        return DraggableScrollableSheet(
          initialChildSize: 0.68,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          expand: false,
          builder: (sheetCtx, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 12, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryLight,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.notifications_active_outlined,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Notifications',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                totalCount == 0
                                    ? 'All caught up'
                                    : '$totalCount active ${totalCount == 1 ? 'alert' : 'alerts'}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (announcements.isNotEmpty)
                          TextButton(
                            onPressed: () => annService.markAllRead(),
                            child: const Text(
                              'Mark read',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  Expanded(
                    child: totalCount == 0
                        ? _buildEmptyState(context)
                        : ListView(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                            children: [
                              if (urgentReminders.isNotEmpty) ...[
                                _buildSectionHeader(
                                  'BILL REMINDERS (${urgentReminders.length})',
                                  actionLabel: 'Manage Bills',
                                  onAction: () => _handleRoute(context, 'plan:1'),
                                ),
                                const SizedBox(height: 8),
                                ...urgentReminders.map(
                                  (r) => _buildReminderNotificationTile(
                                    context,
                                    r,
                                    remProvider,
                                    expenseProvider,
                                    currencyFmt,
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              if (budgetAlerts.isNotEmpty) ...[
                                _buildSectionHeader(
                                  'BUDGET ALERTS (${budgetAlerts.length})',
                                  actionLabel: 'View Budgets',
                                  onAction: () => _handleRoute(context, 'plan:0'),
                                ),
                                const SizedBox(height: 8),
                                ...budgetAlerts.map(
                                  (p) => _buildBudgetNotificationTile(
                                    context,
                                    p,
                                    currencyFmt,
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              if (announcements.isNotEmpty) ...[
                                _buildSectionHeader(
                                  'UPDATES & OFFERS (${announcements.length})',
                                ),
                                const SizedBox(height: 8),
                                ...announcements.map(
                                  (a) => _buildAnnouncementTile(context, a, annService),
                                ),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 32,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No New Notifications',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Due bill reminders, budget limit warnings, and special updates will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.4),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () => _handleRoute(context, 'plan:1'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primaryBorder),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              icon: const Icon(Icons.event_note_outlined, size: 18),
              label: const Text(
                'Open Budgets & Bills',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    String title, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.7,
            color: Color(0xFF64748B),
          ),
        ),
        if (actionLabel != null && onAction != null)
          InkWell(
            onTap: onAction,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildReminderNotificationTile(
    BuildContext context,
    PaymentReminder reminder,
    ReminderProvider remProvider,
    ExpenseProvider expProvider,
    NumberFormat fmt,
  ) {
    final isOverdue = reminder.isOverdue;
    final badgeBg = isOverdue ? const Color(0xFFFFEDED) : const Color(0xFFFFF4E5);
    final badgeFg = isOverdue ? const Color(0xFFD92D20) : const Color(0xFFB45309);
    final dueText = reminder.isDueTomorrow
        ? 'Due tomorrow'
        : (reminder.isDueToday ? 'Due today' : reminder.dueStatusText);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverdue ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
        ),
      ),
      child: InkWell(
        onTap: () => _handleRoute(context, 'plan:1'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: badgeBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CategoryIcons.get(reminder.category),
                  color: badgeFg,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          fmt.format(reminder.amount),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            dueText,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: badgeFg,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  await remProvider.markAsPaid(
                    reminder.id,
                    expenseProvider: expProvider,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text(
                  'Mark Paid',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBudgetNotificationTile(
    BuildContext context,
    BudgetProgress progress,
    NumberFormat fmt,
  ) {
    final isOver = progress.isOverspent;
    final bg = isOver ? const Color(0xFFFFEDED) : const Color(0xFFFEF3C7);
    final fg = isOver ? const Color(0xFFBA1A1A) : const Color(0xFFB45309);
    final statusText = isOver
        ? 'Over Budget (${progress.percentage.toStringAsFixed(0)}%)'
        : 'Near Limit (${progress.percentage.toStringAsFixed(0)}%)';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOver ? const Color(0xFFFECACA) : const Color(0xFFFDE68A),
        ),
      ),
      child: InkWell(
        onTap: () => _handleRoute(context, 'plan:0'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: bg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOver ? Icons.warning_amber_rounded : Icons.trending_up_rounded,
                  color: fg,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      progress.category,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${fmt.format(progress.spentThisMonth)} spent of ${fmt.format(progress.limit)} limit',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncementTile(
    BuildContext context,
    AppAnnouncement item,
    AnnouncementService service,
  ) {
    final IconData icon;
    final String badge;
    final Color accent;
    final Color accentBg;
    switch (item.category) {
      case AnnouncementCategory.update:
        icon = Icons.auto_awesome_rounded;
        badge = 'UPDATE';
        accent = const Color(0xFF4B41E1);
        accentBg = const Color(0xFFEEF2FF);
        break;
      case AnnouncementCategory.tip:
        icon = Icons.lightbulb_outline_rounded;
        badge = 'TIP';
        accent = const Color(0xFF008096);
        accentBg = const Color(0xFFE0F7FA);
        break;
      case AnnouncementCategory.promo:
        icon = Icons.local_offer_outlined;
        badge = 'OFFER';
        accent = AppColors.primary;
        accentBg = AppColors.primaryLight;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accentBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => service.dismissAnnouncement(item.id),
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(Icons.close_rounded, size: 16, color: AppColors.textMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  item.message,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
                if (item.ctaLabel != null &&
                    item.ctaLabel!.isNotEmpty &&
                    item.ctaRoute != null &&
                    item.ctaRoute!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      service.dismissAnnouncement(item.id);
                      _handleRoute(context, item.ctaRoute!);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: accentBg,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      item.ctaLabel!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: accent,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
