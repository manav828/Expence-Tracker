import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_colors.dart';
import '../models/payment_reminder.dart';
import '../providers/expense_provider.dart';
import '../providers/reminder_provider.dart';
import '../utils/category_icons.dart';
import '../widgets/add_edit_reminder_sheet.dart';

class PaymentRemindersScreen extends StatefulWidget {
  const PaymentRemindersScreen({super.key});

  @override
  State<PaymentRemindersScreen> createState() => _PaymentRemindersScreenState();
}

class _PaymentRemindersScreenState extends State<PaymentRemindersScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _currencyFmt = NumberFormat.currency(symbol: '₹', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openAddSheet([PaymentReminder? reminder]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddEditReminderSheet(reminderToEdit: reminder),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ReminderProvider>(
      builder: (context, provider, _) {
        final activeReminders = provider.activeReminders;
        final completedReminders = provider.completedReminders;
        final pausedReminders = provider.pausedReminders;
        final monthlyCommitted = provider.totalMonthlyCommittedAmount;

        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text(
              'Payment Reminders',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            backgroundColor: Colors.white,
            foregroundColor: AppColors.textPrimary,
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textMuted,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  tabs: [
                    Tab(text: 'Due & Upcoming (${activeReminders.length})'),
                    Tab(text: 'Completed (${completedReminders.length})'),
                    Tab(text: 'Paused (${pausedReminders.length})'),
                  ],
                ),
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openAddSheet(),
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Reminder', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          body: Column(
            children: [
              // Monthly Fixed Commitments Header Card
              Container(
                margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF006948), Color(0xFF00855D)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F006948),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Monthly Fixed Bills Commitment',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currencyFmt.format(monthlyCommitted),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${activeReminders.length} active recurring commitments',
                            style: const TextStyle(color: Colors.white60, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // TabBar View
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: Active / Due / Upcoming
                    _buildReminderList(activeReminders, provider, isCompletedTab: false),

                    // Tab 2: Completed / History
                    _buildReminderList(completedReminders, provider, isCompletedTab: true),

                    // Tab 3: Paused
                    _buildReminderList(pausedReminders, provider, isPausedTab: true),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReminderList(
    List<PaymentReminder> list,
    ReminderProvider provider, {
    bool isCompletedTab = false,
    bool isPausedTab = false,
  }) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isCompletedTab
                    ? Icons.task_alt_rounded
                    : isPausedTab
                        ? Icons.pause_circle_outline_rounded
                        : Icons.notifications_off_outlined,
                size: 54,
                color: AppColors.textMuted.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 14),
              Text(
                isCompletedTab
                    ? 'No completed bills yet'
                    : isPausedTab
                        ? 'No paused reminders'
                        : 'No pending reminders scheduled',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isCompletedTab
                    ? 'When you mark a reminder as paid, it will show up here.'
                    : 'Add recurring bills like Rent, Wi-Fi, Recharge to stay on top of payments.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final reminder = list[idx];
        return _buildReminderCard(context, reminder, provider, isCompletedTab);
      },
    );
  }

  Widget _buildReminderCard(
    BuildContext context,
    PaymentReminder reminder,
    ReminderProvider provider,
    bool isCompletedTab,
  ) {
    final isOverdue = reminder.isOverdue;
    final isDueToday = reminder.isDueToday;

    Color tagColor;
    Color tagBg;
    if (reminder.isCompleted) {
      tagColor = AppColors.success;
      tagBg = AppColors.accentMint.withValues(alpha: 0.2);
    } else if (isOverdue) {
      tagColor = AppColors.error;
      tagBg = AppColors.errorContainer;
    } else if (isDueToday) {
      tagColor = const Color(0xFFD97706);
      tagBg = const Color(0xFFFEF3C7);
    } else {
      tagColor = AppColors.secondary;
      tagBg = const Color(0xFFEDE9FE);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOverdue ? AppColors.error.withValues(alpha: 0.3) : const Color(0x0F000000),
          width: isOverdue ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openAddSheet(reminder),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Category Icon, Title, Amount & Menu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Icon(
                          CategoryIcons.get(reminder.category),
                          color: AppColors.primary,
                          size: 24,
                        ),
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
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                reminder.frequency.label,
                                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                              ),
                              if (reminder.splitGroupId != null) ...[
                                const SizedBox(width: 6),
                                const Icon(Icons.group_rounded, size: 14, color: AppColors.secondary),
                                const SizedBox(width: 2),
                                const Text(
                                  'Split',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.secondary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _currencyFmt.format(reminder.amount),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: tagBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            reminder.dueStatusText,
                            style: TextStyle(
                              color: tagColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),

                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, color: AppColors.textMuted, size: 20),
                      onSelected: (action) async {
                        if (action == 'edit') {
                          _openAddSheet(reminder);
                        } else if (action == 'toggle') {
                          await provider.toggleReminderActive(reminder.id);
                        } else if (action == 'delete') {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Reminder?'),
                              content: Text('Are you sure you want to delete "${reminder.title}"?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await provider.deleteReminder(reminder.id);
                          }
                        }
                      },
                      itemBuilder: (ctx) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit Reminder')),
                        PopupMenuItem(
                          value: 'toggle',
                          child: Text(reminder.isActive ? 'Pause Reminder' : 'Resume Reminder'),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 10),

                // Bottom Row: Due Date display & 1-Tap "Mark Paid" button
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, size: 15, color: isOverdue ? AppColors.error : AppColors.textMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        reminder.isCompleted && reminder.lastPaidDate != null
                            ? 'Paid on ${DateFormat('d MMM yyyy').format(reminder.lastPaidDate!)}'
                            : 'Due on ${DateFormat('EEE, d MMM yyyy').format(reminder.nextDueDate)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isOverdue ? AppColors.error : AppColors.textMuted,
                          fontWeight: isOverdue ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),

                    if (!reminder.isCompleted && reminder.isActive)
                      ElevatedButton.icon(
                        onPressed: () async {
                          final expenseProvider = context.read<ExpenseProvider>();
                          final paid = await provider.markAsPaid(
                            reminder.id,
                            expenseProvider: expenseProvider,
                          );
                          if (context.mounted && paid != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Paid ${_currencyFmt.format(reminder.amount)} for ${reminder.title}! Logged to expenses.',
                                ),
                                backgroundColor: AppColors.primary,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: const Text('Mark Paid', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
