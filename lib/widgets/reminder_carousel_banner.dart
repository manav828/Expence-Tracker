import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_colors.dart';
import '../models/payment_reminder.dart';
import '../providers/expense_provider.dart';
import '../providers/reminder_provider.dart';
import '../screens/payment_reminders_screen.dart';
import '../utils/category_icons.dart';

class ReminderCarouselBanner extends StatelessWidget {
  final EdgeInsetsGeometry? margin;

  const ReminderCarouselBanner({super.key, this.margin});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReminderProvider?>();
    final reminders = provider?.dashboardActionableReminders ?? [];
    if (provider == null || reminders.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: AppColors.surface,
        child:
            reminders.length == 1
                ? _ReminderCard(reminder: reminders.single, provider: provider)
                : _ReminderSlider(reminders: reminders, provider: provider),
      ),
    );
  }
}

class _ReminderSlider extends StatefulWidget {
  const _ReminderSlider({required this.reminders, required this.provider});

  final List<PaymentReminder> reminders;
  final ReminderProvider provider;

  @override
  State<_ReminderSlider> createState() => _ReminderSliderState();
}

class _ReminderSliderState extends State<_ReminderSlider> {
  int _page = 0;
  double _slideDirection = 1;
  double _dragDistance = 0;

  @override
  void didUpdateWidget(covariant _ReminderSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    final id = oldWidget.reminders[_page].id;
    final index = widget.reminders.indexWhere((reminder) => reminder.id == id);
    _page = index >= 0 ? index : _page.clamp(0, widget.reminders.length - 1);
  }

  void _showPage(int page) {
    if (page < 0 || page >= widget.reminders.length || page == _page) return;
    setState(() {
      _slideDirection = page > _page ? 1 : -1;
      _page = page;
    });
  }

  @override
  Widget build(BuildContext context) {
    final reminders = widget.reminders;
    final reminder = reminders[_page];

    return Column(
      children: [
        GestureDetector(
          key: const ValueKey('home-reminder-slides'),
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => _dragDistance = 0,
          onHorizontalDragUpdate:
              (details) => _dragDistance += details.delta.dx,
          onHorizontalDragEnd: (details) {
            final velocity = details.primaryVelocity ?? 0;
            if (velocity.abs() < 280 && _dragDistance.abs() < 40) return;
            final direction = velocity.abs() >= 280 ? velocity : _dragDistance;
            _showPage(_page + (direction < 0 ? 1 : -1));
          },
          child: ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeIn,
                transitionBuilder:
                    (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: Offset(_slideDirection * 0.25, 0),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                layoutBuilder:
                    (currentChild, previousChildren) => Stack(
                      children: [
                        for (final previous in previousChildren)
                          Positioned(
                            key: previous.key,
                            left: 0,
                            top: 0,
                            right: 0,
                            child: ExcludeSemantics(
                              child: IgnorePointer(child: previous),
                            ),
                          ),
                        if (currentChild != null) currentChild,
                      ],
                    ),
                child: _ReminderCard(
                  key: ValueKey(reminder.id),
                  reminder: reminder,
                  provider: widget.provider,
                ),
              ),
            ),
          ),
        ),
        const Divider(height: 1, color: AppColors.borderSubtle),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Previous reminder',
              onPressed: _page > 0 ? () => _showPage(_page - 1) : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Flexible(
              child: Text(
                '${_page + 1} of ${reminders.length} reminders',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
            IconButton(
              tooltip: 'Next reminder',
              onPressed:
                  _page < reminders.length - 1
                      ? () => _showPage(_page + 1)
                      : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    super.key,
    required this.reminder,
    required this.provider,
  });

  final PaymentReminder reminder;
  final ReminderProvider provider;

  static bool stackActions(BuildContext context, double width) =>
      width < 270 || MediaQuery.textScalerOf(context).scale(14) > 19;

  void _dismiss(BuildContext context, {bool snooze = false}) {
    final messenger = ScaffoldMessenger.of(context);
    provider.dismissFromHome(reminder, untilTomorrow: snooze);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            snooze
                ? 'Snoozed on Home until tomorrow.'
                : 'Reminder hidden from Home.',
          ),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => provider.restoreOnHome(reminder),
          ),
        ),
      );
  }

  Future<void> _markPaid(BuildContext context, String amount) async {
    final messenger = ScaffoldMessenger.of(context);
    final expenseProvider = context.read<ExpenseProvider>();
    final paid = await provider.markAsPaid(
      reminder.id,
      expenseProvider: expenseProvider,
    );
    if (!messenger.mounted || paid == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('Logged $amount for ${reminder.title}.')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final amount = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    ).format(reminder.amount);
    final dueLabel =
        reminder.isDueToday
            ? 'Due today'
            : reminder.isDueTomorrow
            ? 'Due tomorrow'
            : reminder.dueStatusText;
    final urgent = reminder.isDueToday || reminder.isDueTomorrow;
    final dueBackground =
        reminder.isOverdue
            ? AppColors.errorContainer
            : urgent
            ? AppColors.warningLight
            : AppColors.primaryLight;
    final dueColor =
        reminder.isOverdue
            ? AppColors.error
            : urgent
            ? const Color(0xFF92400E)
            : AppColors.primaryDark;

    final paid = FilledButton.icon(
      onPressed: () => _markPaid(context, amount),
      icon: const Icon(Icons.check_rounded, size: 18),
      label: const Text('Mark Paid'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
    final snooze = OutlinedButton.icon(
      onPressed: () => _dismiss(context, snooze: true),
      icon: const Icon(Icons.schedule_rounded, size: 18),
      label: const Text('Snooze'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = stackActions(context, constraints.maxWidth);
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap:
                          () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const PaymentRemindersScreen(),
                            ),
                          ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: AppColors.primaryLight,
                              child: Icon(
                                CategoryIcons.get(reminder.category),
                                color: AppColors.primary,
                                size: 19,
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    reminder.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        amount,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          color: dueBackground,
                                        ),
                                        child: Text(
                                          dueLabel,
                                          style: TextStyle(
                                            color: dueColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Hide reminder from Home',
                    onPressed: () => _dismiss(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (stacked) ...[
                paid,
                const SizedBox(height: 6),
                snooze,
              ] else
                Row(
                  children: [
                    Expanded(child: paid),
                    const SizedBox(width: 8),
                    Expanded(child: snooze),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
