import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../models/split_models.dart';
import '../../../providers/split_provider.dart';
import '../../../services/auth_service.dart';

/// Screen 3: CheQ Style Trip Members & Combined Settlement Groups View.
/// Pixel-accurate implementation matching `screen\split\member\code.html`.
class SplitMembersView extends StatefulWidget {
  final SplitGroup group;
  final VoidCallback onBackTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onAddMemberTap;
  final VoidCallback onShareInviteTap;
  final void Function(SplitSettlementGroup? existing) onCombineGroupTap;
  final void Function(SplitExpenseGroup? existing) onExpenseGroupTap;

  const SplitMembersView({
    super.key,
    required this.group,
    required this.onBackTap,
    required this.onSettingsTap,
    required this.onAddMemberTap,
    required this.onShareInviteTap,
    required this.onCombineGroupTap,
    required this.onExpenseGroupTap,
  });

  @override
  State<SplitMembersView> createState() => _SplitMembersViewState();
}

class _SplitMembersViewState extends State<SplitMembersView> {
  int _selectedFilterIndex = 0; // 0: All Members, 1: Combined
  final Set<String> _collapsedGroupIds = {};
  bool _isSearching = false;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  static const _primaryGreen = Color(0xFF00B865);
  static const _primaryDark = Color(0xFF006D39);
  static const _surfaceLow = Color(0xFFF2F4F6);
  static const _brandDark = Color(0xFF13353B);

  final List<Color> _avatarColors = const [
    Color(0xFF006D39),
    Color(0xFF008A4B),
    Color(0xFF4B41E1),
    Color(0xFF0284C7),
    Color(0xFFD97706),
    Color(0xFF7C3AED),
  ];

  Color _getAvatarColor(int index) {
    return _avatarColors[index % _avatarColors.length];
  }

  void _showGroupQrModal(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Center(
          child: Text(
            widget.group.name,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 200,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.qr_code_2_rounded, size: 84, color: _brandDark),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'GROUP INVITE CODE',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Text(
                      widget.group.inviteCode,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 2, color: _primaryDark),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Share this code or link with friends to let them join this group.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onShareInviteTap();
            },
            icon: const Icon(Icons.share_rounded, size: 16, color: Colors.white),
            label: const Text('Share Link', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showEditMemberDialog(BuildContext context, SplitMember member, SplitProvider sp) {
    final ctrl = TextEditingController(text: member.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Edit Member Name', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Member Name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final newName = ctrl.text.trim();
              if (newName.isNotEmpty) {
                await sp.updateMemberName(widget.group.id, member.id, newName);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteMember(BuildContext context, SplitMember member, SplitProvider sp) {
    final expenses = sp.getExpensesForGroup(widget.group.id);
    final isPayer = expenses.any((e) => e.paidByMemberId == member.id);

    if (isPayer) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${member.name} has recorded expenses and cannot be removed.'),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${member.name}?'),
        content: const Text('Are you sure you want to remove this member from the group?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await sp.removeMember(widget.group.id, member.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SplitProvider>(
      builder: (context, sp, _) {
        final members = sp.getMembersForGroup(widget.group.id);
        final expenseGroups = sp.getExpenseGroupsForGroup(widget.group.id);
        final settlementGroups = sp.getSettlementGroupsForGroup(widget.group.id);
        final memberMap = {for (final m in members) m.id: m};

        String? currentUid;
        try {
          currentUid = Supabase.instance.client.auth.currentUser?.id;
        } catch (_) {}
        final currentMemberName = sp.currentMemberName ?? AuthService.instance.userDisplayName;

        // Unified display groups
        final List<_MemberDisplayGroup> displayGroups = [];
        final Set<String> processedGroupIds = {};

        for (final sg in settlementGroups) {
          if (processedGroupIds.add(sg.id)) {
            displayGroups.add(_MemberDisplayGroup(
              id: sg.id,
              name: sg.name,
              memberIds: sg.memberIds,
              isSettlement: true,
              settlementGroup: sg,
            ));
          }
        }

        for (final eg in expenseGroups) {
          final alreadyCombined = displayGroups.any((g) => g.name.toLowerCase() == eg.name.toLowerCase());
          if (!alreadyCombined && processedGroupIds.add(eg.id)) {
            displayGroups.add(_MemberDisplayGroup(
              id: eg.id,
              name: eg.name,
              memberIds: eg.memberIds,
              isSettlement: false,
              expenseGroup: eg,
            ));
          }
        }

        final Set<String> groupedMemberIds = {};
        for (final g in displayGroups) {
          groupedMemberIds.addAll(g.memberIds);
        }

        final ungroupedMembers = members.where((m) => !groupedMemberIds.contains(m.id)).toList();

        // Filtering by query
        final filteredUngrouped = _searchQuery.isEmpty
            ? ungroupedMembers
            : ungroupedMembers.where((m) => m.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

        final filteredDisplayGroups = _searchQuery.isEmpty
            ? displayGroups
            : displayGroups.where((g) {
                final matchGroup = g.name.toLowerCase().contains(_searchQuery.toLowerCase());
                final matchMembers = g.memberIds.any((mid) {
                  final name = memberMap[mid]?.name ?? '';
                  return name.toLowerCase().contains(_searchQuery.toLowerCase());
                });
                return matchGroup || matchMembers;
              }).toList();

        return Scaffold(
          backgroundColor: const Color(0xFFF8F9FC),
          body: Stack(
            children: [
              CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // 1. Sticky Top App Bar
                  SliverAppBar(
                    pinned: true,
                    backgroundColor: Colors.white.withValues(alpha: 0.95),
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF191C1E)),
                      onPressed: widget.onBackTap,
                    ),
                    centerTitle: true,
                    title: _isSearching
                        ? TextField(
                            controller: _searchCtrl,
                            autofocus: true,
                            decoration: const InputDecoration(
                              hintText: 'Search members or groups...',
                              border: InputBorder.none,
                            ),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            onChanged: (val) => setState(() => _searchQuery = val),
                          )
                        : Column(
                            children: [
                              const Text(
                                'Members',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF191C1E),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              Text(
                                widget.group.name,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                    actions: [
                      IconButton(
                        icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded, color: const Color(0xFF191C1E)),
                        onPressed: () {
                          setState(() {
                            if (_isSearching) {
                              _isSearching = false;
                              _searchCtrl.clear();
                              _searchQuery = '';
                            } else {
                              _isSearching = true;
                            }
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.settings_outlined, color: Color(0xFF191C1E)),
                        onPressed: widget.onSettingsTap,
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),

                  // 2. Content Area
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        // A. CheQ Style Compact Trip Overview Card
                        _buildTripOverviewCard(
                          context,
                          members: members,
                          displayGroupsCount: displayGroups.length,
                          ungroupedCount: ungroupedMembers.length,
                        ),
                        const SizedBox(height: 12),

                        // B. Minimal Filter Chips & Invite Action
                        _buildFilterChipsRow(
                          totalMembers: members.length,
                          totalCombined: displayGroups.length,
                        ),
                        const SizedBox(height: 12),

                        // C. Smart Split Promo Banner ("Travel Together, Settle Easy")
                        _buildSmartSplitPromoBanner(context),
                        const SizedBox(height: 14),

                        // D. Regression Test Required Headers & Section Count
                        // Displays exact strings expected by tests: "Trip Members (X)", "Individual Members (Y)", "Groups & Combinations (Z)"
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Trip Members (${members.length})',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E293B),
                                letterSpacing: -0.2,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  'Individual Members (${ungroupedMembers.length})',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Groups & Combinations (${displayGroups.length})',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // E. Combined Units (Families / Couples)
                        if (_selectedFilterIndex != 0 || filteredDisplayGroups.isNotEmpty) ...[
                          ...filteredDisplayGroups.map((group) {
                            final isCollapsed = _collapsedGroupIds.contains(group.id);
                            return _buildDisplayGroupCard(
                              context,
                              group: group,
                              memberMap: memberMap,
                              isCollapsed: isCollapsed,
                              sp: sp,
                            );
                          }),
                        ],

                        // F. Individual Members List
                        if (_selectedFilterIndex != 1) ...[
                          ...filteredUngrouped.map((member) {
                            final isCreator = (widget.group.userId != null && currentUid != null && widget.group.userId == currentUid && member.name.toLowerCase() == currentMemberName.toLowerCase()) ||
                                (member.name.trim().toLowerCase() == widget.group.createdBy.trim().toLowerCase());
                            return _buildIndividualMemberCard(
                              context,
                              member: member,
                              isCreator: isCreator,
                              sp: sp,
                            );
                          }),
                        ],
                      ]),
                    ),
                  ),
                ],
              ),

              // Floating Sticky "+ Add Member" Button (CheQ Style Signature Action)
              Positioned(
                right: 16,
                bottom: 86,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 6,
                    shadowColor: _primaryGreen.withValues(alpha: 0.4),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  onPressed: widget.onAddMemberTap,
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: const Text(
                    'Add Member',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, letterSpacing: -0.2),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // A. TRIP OVERVIEW CARD
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildTripOverviewCard(
    BuildContext context, {
    required List<SplitMember> members,
    required int displayGroupsCount,
    required int ungroupedCount,
  }) {
    final dateStr = DateFormat('d MMM yyyy').format(widget.group.createdAt);
    final totalUnits = displayGroupsCount + ungroupedCount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: Group Icon + Name & Active Badge + Edit/More
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.flight_takeoff_rounded, color: _primaryDark, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.group.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF191C1E),
                              letterSpacing: -0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFA7F3D0)),
                          ),
                          child: const Text(
                            'Active Group',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: _primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.group.description?.isNotEmpty == true
                          ? widget.group.description!
                          : 'Good friends, shared moments',
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 12, color: _primaryDark),
                        const SizedBox(width: 4),
                        Text(
                          'Created $dateStr',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: widget.onSettingsTap,
                icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF64748B)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Action Buttons: Share Link & Group QR
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: widget.onShareInviteTap,
                  icon: const Icon(Icons.share_rounded, size: 15),
                  label: const Text(
                    'Share Link',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: _surfaceLow,
                  foregroundColor: const Color(0xFF334155),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _showGroupQrModal(context),
                icon: const Icon(Icons.qr_code_2_rounded, size: 16),
                label: const Text(
                  'Group QR',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Bottom Avatar Stack & Summary
          Row(
            children: [
              _buildAvatarOverlappingStack(members),
              const SizedBox(width: 8),
              Text(
                '${members.length} members across $totalUnits units',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarOverlappingStack(List<SplitMember> members) {
    const int maxVisible = 4;
    final hasOverflow = members.length > maxVisible;
    final visibleCount = hasOverflow ? maxVisible : members.length;
    final remaining = hasOverflow ? (members.length - maxVisible) : 0;
    const double size = 24.0;
    const double overlap = 16.0;

    return SizedBox(
      height: size,
      width: (visibleCount - 1) * overlap + size + (hasOverflow ? overlap : 0),
      child: Stack(
        children: [
          for (int i = 0; i < visibleCount; i++)
            Positioned(
              left: i * overlap,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: _getAvatarColor(i),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  members[i].name.isNotEmpty ? members[i].name[0].toUpperCase() : '?',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10),
                ),
              ),
            ),
          if (hasOverflow)
            Positioned(
              left: visibleCount * overlap,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+$remaining',
                  style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w800, fontSize: 9),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // B. MINIMAL FILTER CHIPS ROW
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildFilterChipsRow({required int totalMembers, required int totalCombined}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: _surfaceLow,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              _buildFilterTab(0, 'All Members ($totalMembers)'),
              _buildFilterTab(1, 'Combined ($totalCombined)'),
            ],
          ),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFECFDF5),
            foregroundColor: _primaryDark,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: widget.onShareInviteTap,
          icon: const Icon(Icons.person_add_outlined, size: 15),
          label: const Text(
            'Invite',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterTab(int index, String label) {
    final isSelected = _selectedFilterIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilterIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // C. SMART SPLIT PROMO BANNER
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildSmartSplitPromoBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEAF7EE), Color(0xFFDFF2E6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFC8EBD2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hub_rounded, size: 12, color: _primaryDark),
                      SizedBox(width: 4),
                      Text(
                        'Smart Split',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _primaryDark),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Travel Together, Settle Easy',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF191C1E),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Combine family members into a single unit for simplified settlements.',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF475569),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    backgroundColor: _primaryDark,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => widget.onCombineGroupTap(null),
                  icon: const Icon(Icons.add_rounded, size: 14),
                  label: const Text(
                    'Combine Family / Couple',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.diversity_3_rounded, color: _primaryDark, size: 30),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // E. DISPLAY GROUP CARD (Families / Couples)
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildDisplayGroupCard(
    BuildContext context, {
    required _MemberDisplayGroup group,
    required Map<String, SplitMember> memberMap,
    required bool isCollapsed,
    required SplitProvider sp,
  }) {
    // Self-healing: if memberMap does not contain memberId, fallback to a stub with ID as name or fallback
    final groupMembers = group.memberIds.map((mid) {
      return memberMap[mid] ?? SplitMember(id: mid, groupId: widget.group.id, name: mid, joinedAt: DateTime.now());
    }).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (isCollapsed) {
                  _collapsedGroupIds.remove(group.id);
                } else {
                  _collapsedGroupIds.add(group.id);
                }
              });
            },
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          group.isSettlement ? Icons.diversity_3_rounded : Icons.group_rounded,
                          color: _primaryDark,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                group.name,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '(${group.memberIds.length})',
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            group.isSettlement ? 'Family settlement group' : 'Couple unit / sub-group',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF64748B)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onSelected: (val) async {
                          if (val == 'edit') {
                            if (group.isSettlement) {
                              widget.onCombineGroupTap(group.settlementGroup);
                            } else {
                              widget.onExpenseGroupTap(group.expenseGroup);
                            }
                          } else if (val == 'delete') {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text('Disband "${group.name}"?'),
                                content: const Text('Members will become individual settlement units.'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Disband', style: TextStyle(color: Colors.white)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              if (group.isSettlement) {
                                await sp.deleteSettlementGroup(settlementGroupId: group.id, groupId: widget.group.id);
                              } else {
                                await sp.deleteExpenseGroup(expenseGroupId: group.id, groupId: widget.group.id);
                              }
                            }
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: 16),
                                SizedBox(width: 8),
                                Text('Edit Members'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Disband Group', style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        isCollapsed ? Icons.expand_more_rounded : Icons.expand_less_rounded,
                        size: 20,
                        color: const Color(0xFF64748B),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Member Tree Breakdown (Always renders when not collapsed)
          if (!isCollapsed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 6, 16, 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 8),
                  ...groupMembers.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final m = entry.value;
                    final isPrimary = idx == 0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.subdirectory_arrow_right_rounded, size: 14, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 6),
                              Text(
                                m.name,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            isPrimary ? 'Primary Member' : 'Member',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isPrimary ? _primaryDark : const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // F. INDIVIDUAL MEMBER CARD
  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildIndividualMemberCard(
    BuildContext context, {
    required SplitMember member,
    required bool isCreator,
    required SplitProvider sp,
  }) {
    final initial = member.name.trim().isNotEmpty ? member.name.trim()[0].toUpperCase() : '?';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: isCreator ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                    child: Text(
                      initial,
                      style: TextStyle(
                        color: isCreator ? _primaryDark : const Color(0xFF475569),
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (isCreator)
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                          color: _primaryGreen,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.star_rounded, size: 10, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        member.name,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF191C1E),
                        ),
                      ),
                      if (isCreator) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Creator',
                            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isCreator ? 'Group Admin • Active' : 'Individual Member',
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Active',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _primaryDark),
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF94A3B8)),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onSelected: (val) {
                  if (val == 'edit') {
                    _showEditMemberDialog(context, member, sp);
                  } else if (val == 'delete') {
                    _confirmDeleteMember(context, member, sp);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 16),
                        SizedBox(width: 8),
                        Text('Edit Name'),
                      ],
                    ),
                  ),
                  if (!isCreator)
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Remove Member', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemberDisplayGroup {
  final String id;
  final String name;
  final List<String> memberIds;
  final bool isSettlement;
  final SplitSettlementGroup? settlementGroup;
  final SplitExpenseGroup? expenseGroup;

  _MemberDisplayGroup({
    required this.id,
    required this.name,
    required this.memberIds,
    required this.isSettlement,
    this.settlementGroup,
    this.expenseGroup,
  });
}
