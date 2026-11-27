import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/split_provider.dart';
import '../../providers/expense_provider.dart';
import '../../models/split_models.dart';
import '../../models/expense.dart';
import '../../services/pixabay_service.dart';
import 'add_split_expense_sheet.dart';
import 'group_banner_picker_sheet.dart';
import '../../providers/trip_photo_provider.dart';
import 'trip_photo_vault_tab.dart';
import 'views/split_expenses_view.dart';
import 'views/split_settle_view.dart';
import 'views/split_members_view.dart';
import 'widgets/split_bottom_nav_bar.dart';
import '../../core/theme/app_colors.dart';


class SplitGroupDetailScreen extends StatefulWidget {
  final SplitGroup group;
  final int initialTabIndex;
  const SplitGroupDetailScreen({super.key, required this.group, this.initialTabIndex = 0});
  @override
  State<SplitGroupDetailScreen> createState() => _SplitGroupDetailScreenState();
}

class _SplitGroupDetailScreenState extends State<SplitGroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late SplitGroup _group;
  late int _currentTabIndex;
  bool _loadingDetail = true;
  static const _primaryColor = AppColors.primary;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _currentTabIndex = widget.initialTabIndex;
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTabIndex);
    _tabController.addListener(() {
      if (mounted && _tabController.index != _currentTabIndex) {
        setState(() => _currentTabIndex = _tabController.index);
      }
    });
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _loadingDetail = true);
    await context.read<SplitProvider>().loadGroupDetail(_group.id);
    if (mounted) setState(() => _loadingDetail = false);
  }

  Future<void> _shareInvite() async {
    final webUrl = kIsWeb
        ? '${Uri.base.origin}/?code=${_group.inviteCode}'
        : 'https://expensetracker.web.app/?code=${_group.inviteCode}';
    final shareText = 'Join our group "${_group.name}" on ExpenCircle!\n'
        'Invite Code: ${_group.inviteCode}\n'
        'Direct link: $webUrl';
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: shareText,
          subject: 'Join ${_group.name} on ExpenCircle',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open share options: $e'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showEditGroupDialog() async {
    final nameCtrl = TextEditingController(text: _group.name);
    final descCtrl = TextEditingController(text: _group.description ?? '');
    String currentCoverUrl = _group.imageUrl ?? _getCoverImageUrl(_group.name);
    bool isRefreshingCover = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit Group Details', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Group Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: InputDecoration(
                  labelText: 'Description / Tagline',
                  hintText: 'e.g. Good food, better people 🌴',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Cover Photo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
              const SizedBox(height: 8),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 56,
                      height: 40,
                      child: Image.network(
                        currentCoverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: _primaryColor.withValues(alpha: 0.1),
                          child: const Icon(Icons.image, size: 20, color: _primaryColor),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor.withValues(alpha: 0.12),
                        foregroundColor: _primaryColor,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      onPressed: () async {
                        final chosen = await showModalBottomSheet<String>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => GroupBannerPickerSheet(
                            initialUrl: currentCoverUrl,
                            suggestedKeyword: nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : _group.name,
                          ),
                        );
                        if (chosen != null && chosen.isNotEmpty) {
                          setDialogState(() => currentCoverUrl = chosen);
                        }
                      },
                      icon: const Icon(Icons.panorama_outlined, size: 16),
                      label: const Text('Change Banner', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Auto-pick from Pixabay',
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    onPressed: isRefreshingCover
                        ? null
                        : () async {
                            setDialogState(() => isRefreshingCover = true);
                            final searchName = nameCtrl.text.trim().isNotEmpty ? nameCtrl.text.trim() : _group.name;
                            final newUrl = await PixabayService.fetchImageForGroup(
                              name: searchName,
                              description: descCtrl.text.trim(),
                            );
                            setDialogState(() {
                              currentCoverUrl = newUrl;
                              isRefreshingCover = false;
                            });
                          },
                    icon: isRefreshingCover
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.auto_awesome, size: 16, color: _primaryColor),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                final newName = nameCtrl.text.trim();
                if (newName.isNotEmpty) {
                  final updated = _group.copyWith(
                    name: newName,
                    description: descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : null,
                    imageUrl: currentCoverUrl,
                  );
                  await context.read<SplitProvider>().updateGroup(updated);
                  if (mounted) {
                    setState(() => _group = updated);
                  }
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                  }
                }
              },
              child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  String _getCoverImageUrl(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('udaipur') || lower.contains('rajasthan') || lower.contains('palace') || lower.contains('lake') || lower.contains('jaipur')) {
      return 'https://images.unsplash.com/photo-1595846519845-68e298c2edd8?auto=format&fit=crop&w=1200&q=80';
    } else if (lower.contains('bali') || lower.contains('temple') || lower.contains('indonesia')) {
      return 'https://images.unsplash.com/photo-1537996194471-e657df975ab4?auto=format&fit=crop&w=1200&q=80';
    } else if (lower.contains('trip') || lower.contains('tour') || lower.contains('travel') || lower.contains('vacation')) {
      return 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80';
    } else if (lower.contains('goa') || lower.contains('beach') || lower.contains('sea')) {
      return 'https://images.unsplash.com/photo-1512343879784-a960bf40e7f2?auto=format&fit=crop&w=1200&q=80';
    } else if (lower.contains('trek') || lower.contains('mountain') || lower.contains('manali') || lower.contains('hike') || lower.contains('camp')) {
      return 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=1200&q=80';
    } else if (lower.contains('flat') || lower.contains('room') || lower.contains('house') || lower.contains('rent') || lower.contains('home')) {
      return 'https://images.unsplash.com/photo-1502672260266-1c1ef2d93688?auto=format&fit=crop&w=1200&q=80';
    } else if (lower.contains('food') || lower.contains('dinner') || lower.contains('lunch') || lower.contains('party') || lower.contains('cafe')) {
      return 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1200&q=80';
    } else if (lower.contains('office') || lower.contains('work') || lower.contains('project')) {
      return 'https://images.unsplash.com/photo-1486406146926-c627a92ad1ab?auto=format&fit=crop&w=1200&q=80';
    }
    return 'https://images.unsplash.com/photo-1595846519845-68e298c2edd8?auto=format&fit=crop&w=1200&q=80';
  }

  void _showAddMemberDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Member'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Member name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final newName = ctrl.text.trim();
              if (newName.isNotEmpty) {
                final existing = context.read<SplitProvider>().getMembersForGroup(_group.id);
                if (existing.any((m) => m.name.trim().toLowerCase() == newName.toLowerCase())) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Member "$newName" already exists in this group'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                await context.read<SplitProvider>().addMember(_group.id, newName);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEndTripModeDialog(BuildContext context, SplitGroup group, SplitProvider sp) {
    final expenses = sp.getExpensesForGroup(group.id);
    final totalSpend = expenses.fold(0.0, (sum, exp) => sum + exp.totalAmount);
    final userNetShare = sp.calculateUserNetShare(group.id);
    final fmt = NumberFormat('#,##0.00', 'en_IN');
    bool saveToPersonal = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 14,
              bottom: MediaQuery.of(ctx).padding.bottom + 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.flight_land_rounded, color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'End Trip Mode: ${group.name}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF131B2E)),
                          ),
                          const Text(
                            'Review trip spend and sync to personal expenses',
                            style: TextStyle(fontSize: 12, color: Color(0xFF6D7A72)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Group Spend', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                          Text('₹${fmt.format(totalSpend)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1E293B))),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Your Total Net Share', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13.5)),
                          Text('₹${fmt.format(userNetShare)}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.primary)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Based on ${expenses.length} group expenses',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.bookmark_added_rounded, color: AppColors.primary, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Save Trip Share to Personal Expenses',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF131B2E)),
                            ),
                            Text(
                              'Logs ₹${fmt.format(userNetShare)} under category "Travel"',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF6D7A72)),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: saveToPersonal,
                        activeColor: AppColors.primary,
                        onChanged: (v) => setSheetState(() => saveToPersonal = v),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await sp.disableTripMode();

                      if (saveToPersonal && userNetShare > 0 && context.mounted) {
                        await context.read<ExpenseProvider>().addExpense(
                          Expense(
                            amount: userNetShare,
                            category: 'Travel',
                            paymentMethod: 'UPI',
                            comment: 'Trip: ${group.name} (Total Net Cost)',
                            expenseDate: DateTime.now().millisecondsSinceEpoch,
                            createdAt: DateTime.now().millisecondsSinceEpoch,
                            updatedAt: DateTime.now().millisecondsSinceEpoch,
                            type: TransactionType.expense,
                          ),
                        );
                      }

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(saveToPersonal && userNetShare > 0
                                ? 'Trip Mode ended & ₹${fmt.format(userNetShare)} saved to Travel expenses!'
                                : 'Trip Mode ended for "${group.name}".'),
                            backgroundColor: AppColors.primary,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        );
                      }
                    },
                    child: Text(
                      saveToPersonal ? 'End Trip & Save to Expenses' : 'Turn Off Trip Mode',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Keep Trip Mode Active', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openAddExpenseSheet() async {
    final members = context.read<SplitProvider>().getMembersForGroup(_group.id);
    if (members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add members first')),
      );
      return;
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddSplitExpenseSheet(
        groupId: _group.id,
        members: members,
        currentMemberName: context.read<SplitProvider>().currentMemberName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SplitProvider>(
      builder: (context, sp, _) {
        final members = sp.getMembersForGroup(_group.id);
        TripPhotoProvider? photoProv;
        try {
          photoProv = Provider.of<TripPhotoProvider>(context);
        } catch (_) {
          photoProv = null;
        }

        if (_loadingDetail && members.isEmpty) {
          return const Scaffold(
            backgroundColor: Color(0xFFF5F8F7),
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        final views = [
          // Tab 0: Expenses
          SplitExpensesView(
            group: _group,
            onAddExpenseTap: _openAddExpenseSheet,
            onSettleUpTap: () {
              setState(() {
                _currentTabIndex = 1;
                _tabController.index = 1;
              });
            },
            onEditGroupTap: _showEditGroupDialog,
            onShareInviteTap: _shareInvite,
            onTripModeTap: () {
              final isThisTripActive = sp.isTripModeActive && sp.activeTripGroupId == _group.id;
              if (isThisTripActive) {
                _showEndTripModeDialog(context, _group, sp);
              } else {
                sp.enableTripMode(_group.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✈️ Trip Mode activated for "${_group.name}"! All new expenses will default here.'),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            },
          ),

          // Tab 1: Settle
          SplitSettleView(
            group: _group,
            onAddExpenseTap: _openAddExpenseSheet,
            onBackTap: () => Navigator.of(context).pop(),
            onSettingsTap: _showEditGroupDialog,
          ),

          // Tab 2: Members
          SplitMembersView(
            group: _group,
            onBackTap: () => Navigator.of(context).pop(),
            onSettingsTap: _showEditGroupDialog,
            onAddMemberTap: _showAddMemberDialog,
            onShareInviteTap: _shareInvite,
            onCombineGroupTap: (existing) => _showSettlementGroupModal(context, _group, members, existing: existing),
            onExpenseGroupTap: (existing) => _showExpenseGroupModal(context, _group, members, existing: existing),
          ),

          // Tab 3: Photos
          Builder(
            builder: (ctx) {
              final content = TripPhotoVaultTab(
                group: _group,
                currentMemberName: sp.currentMemberName ?? 'Member',
              );
              final wrapped = photoProv != null
                  ? content
                  : ChangeNotifierProvider<TripPhotoProvider>(
                      create: (_) => TripPhotoProvider(),
                      child: content,
                    );
              return Scaffold(
                backgroundColor: Colors.white,
                appBar: AppBar(
                  title: Column(
                    children: [
                      const Text(
                        'Photo Vault',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF191C1E),
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        _group.name,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  centerTitle: true,
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF191C1E)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, color: Color(0xFF191C1E)),
                      onPressed: _showEditGroupDialog,
                    ),
                    const SizedBox(width: 4),
                  ],
                  backgroundColor: Colors.white,
                  elevation: 0,
                ),
                body: wrapped,
              );
            },
          ),
        ];

        return Scaffold(
          backgroundColor: const Color(0xFFF5F8F7),
          body: IndexedStack(
            index: _currentTabIndex,
            children: views,
          ),
          bottomNavigationBar: SplitBottomNavBar(
            currentIndex: _currentTabIndex,
            onTabSelected: (index) {
              setState(() {
                _currentTabIndex = index;
                _tabController.index = index;
              });
            },
            onAddExpenseTap: _openAddExpenseSheet,
            photoCount: photoProv?.totalCount ?? 0,
          ),
        );
      },
    );
  }
}

void _showExpenseGroupModal(
  BuildContext context,
  SplitGroup group,
  List<SplitMember> members, {
  SplitExpenseGroup? existing,
}) {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final descCtrl = TextEditingController(text: existing?.description ?? '');
  final selectedIds = Set<String>.from(existing?.memberIds ?? members.map((m) => m.id));

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F7F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.playlist_add_check_rounded, color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            existing == null ? 'Create Expense Group' : 'Edit Expense Group',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Quick shortcut for participant selection',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Group Name *',
                    hintText: "e.g. Dinesh Sir's Family, Roommates",
                    prefixIcon: const Icon(Icons.group_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: InputDecoration(
                    labelText: 'Description (optional)',
                    hintText: 'e.g. For food & hotel splits',
                    prefixIcon: const Icon(Icons.notes_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Members (${selectedIds.length}/${members.length})',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1E293B)),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              selectedIds.addAll(members.map((m) => m.id));
                            });
                          },
                          child: const Text('All', style: TextStyle(fontSize: 12)),
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              selectedIds.clear();
                            });
                          },
                          child: const Text('Clear', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: members.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (ctx, i) {
                      final m = members[i];
                      final isSelected = selectedIds.contains(m.id);
                      return CheckboxListTile(
                        value: isSelected,
                        dense: true,
                        activeColor: AppColors.primary,
                        title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              selectedIds.add(m.id);
                            } else {
                              selectedIds.remove(m.id);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a group name'), backgroundColor: Colors.red),
                        );
                        return;
                      }
                      if (selectedIds.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Select at least one member'), backgroundColor: Colors.red),
                        );
                        return;
                      }
                      final sp = context.read<SplitProvider>();
                      final desc = descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim();
                      if (existing == null) {
                        await sp.createExpenseGroup(
                          groupId: group.id,
                          name: name,
                          description: desc,
                          memberIds: selectedIds.toList(),
                        );
                      } else {
                        await sp.updateExpenseGroup(
                          expenseGroupId: existing.id,
                          groupId: group.id,
                          name: name,
                          description: desc,
                          memberIds: selectedIds.toList(),
                        );
                      }
                      if (context.mounted) Navigator.pop(ctx);
                    },
                    child: Text(existing == null ? 'Create Group' : 'Save Changes', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

void _showSettlementGroupModal(
  BuildContext context,
  SplitGroup group,
  List<SplitMember> members, {
  SplitSettlementGroup? existing,
}) {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final selectedIds = Set<String>.from(existing?.memberIds ?? []);
  final sp = context.read<SplitProvider>();

  // Only list individual members not already assigned to another combined settlement group
  final allSettlementGroups = sp.getSettlementGroupsForGroup(group.id);
  final takenMemberIds = <String>{};
  for (final sg in allSettlementGroups) {
    if (existing != null && sg.id == existing.id) continue;
    takenMemberIds.addAll(sg.memberIds);
  }
  final availableMembers = members.where((m) => !takenMemberIds.contains(m.id)).toList();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.call_merge_rounded, color: Color(0xFF4F46E5), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            existing == null ? 'Combine Settlement' : 'Edit Combined Settlement',
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0F172A)),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Combines net balances into one financial entity',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Color(0xFF166534)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Members will keep their own separate expense records, but will settle as one combined entity.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF166534), height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Combined Group Name *',
                    hintText: "e.g. Dinesh Sir's Family, Couple",
                    prefixIcon: const Icon(Icons.group_outlined, size: 20),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Select 2 or More Members (${selectedIds.length} selected)',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1E293B)),
                ),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 220),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: availableMembers.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                              'No individual members available. All members are already combined into groups.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: availableMembers.length,
                          separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (ctx, i) {
                            final m = availableMembers[i];
                            final isSelected = selectedIds.contains(m.id);

                            return CheckboxListTile(
                              value: isSelected,
                              dense: true,
                              activeColor: const Color(0xFF4F46E5),
                              title: Text(
                                m.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    selectedIds.add(m.id);
                                  } else {
                                    selectedIds.remove(m.id);
                                  }
                                });
                              },
                            );
                          },
                        ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a group name'), backgroundColor: Colors.red),
                        );
                        return;
                      }
                      if (selectedIds.length < 2) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Select at least 2 members to combine settlement'), backgroundColor: Colors.red),
                        );
                        return;
                      }
                      final sp = context.read<SplitProvider>();
                      if (existing == null) {
                        await sp.createSettlementGroup(
                          groupId: group.id,
                          name: name,
                          memberIds: selectedIds.toList(),
                        );
                      } else {
                        await sp.updateSettlementGroup(
                          settlementGroupId: existing.id,
                          groupId: group.id,
                          name: name,
                          memberIds: selectedIds.toList(),
                        );
                      }
                      if (context.mounted) Navigator.pop(ctx);
                    },
                    child: Text(existing == null ? 'Combine Settlement' : 'Save Changes', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

