import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/split_provider.dart';
import '../../models/split_models.dart';
import '../../services/auth_service.dart';
import 'split_group_detail_screen.dart';
import 'create_group_screen.dart';
import 'join_group_screen.dart';
import 'split_illustrations.dart';

class SplitScreen extends StatefulWidget {
  const SplitScreen({super.key});

  @override
  State<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends State<SplitScreen> {
  static const _primaryColor = Color(0xFF006948);
  static const _secondaryColor = Color(0xFF4B41E1);
  static const _bgColor = Color(0xFFFAF9FD);

  String _searchQuery = '';
  String _sortBy = 'recent'; // 'recent', 'highest', 'name'
  final TextEditingController _searchController = TextEditingController();

  static const List<Color> _avatarColors = [
    Color(0xFF006948),
    Color(0xFF4B41E1),
    Color(0xFF0284C7),
    Color(0xFFD97706),
    Color(0xFFDC2626),
    Color(0xFF8B5CF6),
    Color(0xFF059669),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SplitProvider>().loadGroups();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: Consumer<SplitProvider>(
        builder: (context, sp, _) {
          if (sp.isLoading && sp.groups.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: _primaryColor),
            );
          }
          if (sp.error != null && sp.groups.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(
                      sp.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => sp.loadGroups(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (sp.groups.isEmpty) {
            return _buildEmptyState(context);
          }

          return _buildGroupList(context, sp);
        },
      ),
      floatingActionButton: Consumer<SplitProvider>(
        builder: (context, sp, _) {
          if (sp.groups.isEmpty) return const SizedBox.shrink();
          return _buildFloatingActions(context);
        },
      ),
    );
  }

  // ─── 1. Empty State (Matching split_home.png Pixel-Perfect & Centered) ──────
  Widget _buildEmptyState(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RefreshIndicator(
          color: _primaryColor,
          onRefresh: () => context.read<SplitProvider>().loadGroups(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 3D Empty State Illustration (properly bounded to eliminate top dead-space)
                    ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxHeight: 220,
                        maxWidth: 340,
                      ),
                      child: const AspectRatio(
                        aspectRatio: 1.5,
                        child: SplitIllustration.emptyState(
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Heading
                    const Text(
                      'No Split Groups Yet',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF131B2E),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Subtitle
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'Create a group to split bills with friends & family.\nMembers can join via a link — no app needed!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons Row (Clear separation from floating bottom navigation button)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final group = await Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
                              );
                              if (!context.mounted) return;
                              if (group is SplitGroup) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => SplitGroupDetailScreen(group: group)),
                                );
                              }
                            },
                            icon: const Icon(Icons.add_circle_outline, size: 18, color: Colors.white),
                            label: const Text('Create Group'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const JoinGroupScreen()),
                            ),
                            icon: const Icon(Icons.link, size: 18, color: Colors.white),
                            label: const Text('Join Group'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _secondaryColor,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              textStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

  // ─── 2. Populated State (Matching split_home_details.png Pixel-Perfect) ────
  Widget _buildGroupList(BuildContext context, SplitProvider sp) {
    // Filter by search query
    var filtered = sp.groups.where((g) {
      if (_searchQuery.isEmpty) return true;
      final query = _searchQuery.toLowerCase();
      final nameMatches = g.name.toLowerCase().contains(query);
      final descMatches = g.description?.toLowerCase().contains(query) ?? false;
      return nameMatches || descMatches;
    }).toList();

    // Sort
    if (_sortBy == 'highest') {
      filtered.sort((a, b) {
        final expA = sp.getExpensesForGroup(a.id).fold(0.0, (s, e) => s + e.totalAmount);
        final expB = sp.getExpensesForGroup(b.id).fold(0.0, (s, e) => s + e.totalAmount);
        return expB.compareTo(expA);
      });
    } else if (_sortBy == 'name') {
      filtered.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else {
      // Recent (default)
      filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return RefreshIndicator(
      onRefresh: sp.loadGroups,
      color: _primaryColor,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 200),
        children: [
          // 1. Hero Banner Card
          _buildHeroBannerCard(),
          const SizedBox(height: 16),

          if (sp.hasPendingSync) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.cloud_sync_outlined, size: 18, color: Color(0xFF2563EB)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Offline changes saved locally. Will sync when online.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: () => sp.syncAll(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Sync Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // 2. Search & Sort Bar
          _buildSearchAndSortBar(),
          const SizedBox(height: 14),

          // 3. Group List Cards
          if (filtered.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 40),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.search_off_rounded, size: 40, color: Color(0xFF94A3B8)),
                  const SizedBox(height: 8),
                  Text(
                    'No groups found matching "$_searchQuery"',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF131B2E)),
                  ),
                ],
              ),
            )
          else
            ...filtered.map((group) => _buildGroupCard(context, group, sp)),
        ],
      ),
    );
  }

  // ─── Hero Banner Card ───────────────────────────────────────────────────────
  Widget _buildHeroBannerCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE8FBF5), Color(0xFFE0F4FB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFCEECE3)),
        boxShadow: const [
          BoxShadow(color: Color(0x060F172A), blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left text block
          const Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SPLIT EXPENSES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: Color(0xFF006948),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Shared moments,\nsimpler splits.',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF131B2E),
                    height: 1.2,
                    letterSpacing: -0.4,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Create a group, add expenses and\nkeep track of everyone’s share.',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          // Right 3D illustration
          const Expanded(
            flex: 4,
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: 115,
                child: SplitIllustration.banner(
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Search & Sort Bar ─────────────────────────────────────────────────────
  Widget _buildSearchAndSortBar() {
    return Row(
      children: [
        // Search input field
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              style: const TextStyle(fontSize: 13, color: Color(0xFF131B2E), fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'Search groups...',
                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF64748B)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16, color: Color(0xFF64748B)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Sort Button ('Recent')
        PopupMenuButton<String>(
          initialValue: _sortBy,
          onSelected: (val) => setState(() => _sortBy = val),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          itemBuilder: (ctx) => [
            const PopupMenuItem(value: 'recent', child: Text('Recent', style: TextStyle(fontWeight: FontWeight.w600))),
            const PopupMenuItem(value: 'highest', child: Text('Highest Expense', style: TextStyle(fontWeight: FontWeight.w600))),
            const PopupMenuItem(value: 'name', child: Text('Alphabetical', style: TextStyle(fontWeight: FontWeight.w600))),
          ],
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.swap_vert, size: 16, color: Color(0xFF131B2E)),
                const SizedBox(width: 4),
                Text(
                  _sortBy == 'recent' ? 'Recent' : (_sortBy == 'highest' ? 'Highest' : 'Name'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF131B2E),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ─── Group Card ────────────────────────────────────────────────────────────
  Widget _buildGroupCard(BuildContext context, SplitGroup group, SplitProvider sp) {
    final members = sp.getMembersForGroup(group.id);
    final expenses = sp.getExpensesForGroup(group.id);
    final totalExpense = expenses.fold(0.0, (s, e) => s + e.totalAmount);

    // Compute balance for current user
    final balances = sp.getBalancesForGroup(group.id);
    final myName = sp.currentMemberName ?? AuthService.instance.userDisplayName;
    double myBalance = 0.0;
    // Find matching member entry (case-insensitive)
    for (var entry in balances.entries) {
      if (entry.key.toLowerCase().trim() == myName.toLowerCase().trim()) {
        myBalance = entry.value;
        break;
      }
    }

    // Latest activity info
    String lastActivityStr = 'No expenses yet';
    if (expenses.isNotEmpty) {
      final sortedExp = List<SplitExpense>.from(expenses)..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final latest = sortedExp.first;
      final timeAgo = _formatTimeAgo(latest.createdAt);
      lastActivityStr = 'Last activity • $timeAgo • ${latest.title}';
    }

    return InkWell(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SplitGroupDetailScreen(group: group)),
        );
        sp.loadGroups();
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: const [
            BoxShadow(color: Color(0x050F172A), blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1. Group Thumbnail / Icon
            _buildGroupThumbnail(group),
            const SizedBox(width: 12),

            // 2. Middle Details (Name, member count, avatar stack, last activity)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          group.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF131B2E),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getGroupEmoji(group.name),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${members.length} members',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Overlapping Avatar Stack
                  _buildAvatarStack(members),
                  const SizedBox(height: 6),
                  // Last Activity
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 10.5, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          lastActivityStr,
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF64748B),
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
            const SizedBox(width: 8),

            // 3. Right Financial Summary (Total Expenses + Balance Pill)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Total Expenses',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '₹${NumberFormat('#,##,##0', 'en_IN').format(totalExpense.round())}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF131B2E),
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                // Balance Badge Pill
                _buildBalancePill(myBalance),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }

  // ─── Balance Pill ──────────────────────────────────────────────────────────
  Widget _buildBalancePill(double balance) {
    if (balance > 0.5) {
      // You are owed (Green)
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F8F2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF006948).withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.download, size: 13, color: Color(0xFF00875A)),
            const SizedBox(width: 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'You are owed',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF00875A),
                  ),
                ),
                Text(
                  '₹${NumberFormat('#,##,##0', 'en_IN').format(balance.round())}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF00875A),
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else if (balance < -0.5) {
      // You owe (Red / Coral)
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFFEECEC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.upload, size: 13, color: Color(0xFFDC2626)),
            const SizedBox(width: 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'You owe',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFDC2626),
                  ),
                ),
                Text(
                  '₹${NumberFormat('#,##,##0', 'en_IN').format(balance.abs().round())}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFDC2626),
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } else {
      // Settled up (Grey)
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'Settled up',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF64748B),
          ),
        ),
      );
    }
  }

  // ─── Group Thumbnail (Curated & Contextual) ────────────────────────────────
  Widget _buildGroupThumbnail(SplitGroup group) {
    final l = group.name.toLowerCase();
    String? imageUrl = group.imageUrl;
    IconData fallbackIcon = Icons.groups;
    Color iconColor = const Color(0xFF006948);
    Color bgColor = const Color(0xFFE6F4EA);

    if (imageUrl == null || imageUrl.isEmpty) {
      if (l.contains('trip') || l.contains('travel') || l.contains('tour') || l.contains('bali') || l.contains('goa') || l.contains('flight')) {
        imageUrl = 'https://images.unsplash.com/photo-1537996194471-e657df975ab4?auto=format&fit=crop&w=200&q=80';
        fallbackIcon = Icons.flight;
        iconColor = const Color(0xFF0284C7);
        bgColor = const Color(0xFFE0F2FE);
      } else if (l.contains('flat') || l.contains('room') || l.contains('house') || l.contains('rent') || l.contains('home')) {
        imageUrl = 'https://images.unsplash.com/photo-1554995207-c18c203602cb?auto=format&fit=crop&w=200&q=80';
        fallbackIcon = Icons.home;
        iconColor = const Color(0xFFD97706);
        bgColor = const Color(0xFFFEF3C7);
      } else if (l.contains('office') || l.contains('work') || l.contains('commute') || l.contains('cab')) {
        imageUrl = 'https://images.unsplash.com/photo-1497215728101-856f4ea42174?auto=format&fit=crop&w=200&q=80';
        fallbackIcon = Icons.directions_car;
        iconColor = const Color(0xFFDC2626);
        bgColor = const Color(0xFFFEE2E2);
      } else if (l.contains('food') || l.contains('dinner') || l.contains('lunch') || l.contains('cafe') || l.contains('restaurant')) {
        imageUrl = 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=200&q=80';
        fallbackIcon = Icons.restaurant;
        iconColor = const Color(0xFFE11D48);
        bgColor = const Color(0xFFFFE4E6);
      }
    }

    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: imageUrl != null
            ? Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildFallbackThumbnail(group, fallbackIcon, iconColor, bgColor),
              )
            : _buildFallbackThumbnail(group, fallbackIcon, iconColor, bgColor),
      ),
    );
  }

  Widget _buildFallbackThumbnail(SplitGroup group, IconData icon, Color iconColor, Color bgColor) {
    return Container(
      color: bgColor,
      child: Center(
        child: Icon(icon, color: iconColor, size: 28),
      ),
    );
  }

  // ─── Overlapping Avatar Stack ──────────────────────────────────────────────
  Widget _buildAvatarStack(List<SplitMember> members) {
    if (members.isEmpty) return const SizedBox.shrink();

    final displayMembers = members.take(4).toList();
    final extraCount = members.length - 4;

    return Row(
      children: [
        SizedBox(
          height: 24,
          child: Row(
            children: [
              for (int i = 0; i < displayMembers.length; i++)
                Align(
                  widthFactor: 0.72,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: _avatarColors[i % _avatarColors.length],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        displayMembers[i].name.isNotEmpty
                            ? displayMembers[i].name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (extraCount > 0) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '+$extraCount',
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF475569),
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ─── Floating Actions (Populated State) ────────────────────────────────────
  Widget _buildFloatingActions(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 86),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'join_group_fab',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const JoinGroupScreen()),
            ),
            label: const Text('Join Group', style: TextStyle(fontWeight: FontWeight.w700)),
            icon: const Icon(Icons.link, size: 18),
            backgroundColor: _secondaryColor,
            foregroundColor: Colors.white,
            elevation: 3,
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'create_group_fab',
            onPressed: () async {
              final group = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
              );
              if (!context.mounted) return;
              if (group is SplitGroup) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SplitGroupDetailScreen(group: group)),
                );
              }
            },
            label: const Text('Create Group', style: TextStyle(fontWeight: FontWeight.w800)),
            icon: const Icon(Icons.add, size: 20),
            backgroundColor: _primaryColor,
            foregroundColor: Colors.white,
            elevation: 4,
          ),
        ],
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────
  String _getGroupEmoji(String name) {
    final l = name.toLowerCase();
    if (l.contains('trip') || l.contains('tour') || l.contains('travel') || l.contains('bali') || l.contains('goa') || l.contains('flight')) {
      return '✈️';
    }
    if (l.contains('flat') || l.contains('room') || l.contains('house') || l.contains('rent') || l.contains('home')) {
      return '🏠';
    }
    if (l.contains('office') || l.contains('work') || l.contains('commute') || l.contains('cab')) {
      return '🚗';
    }
    if (l.contains('food') || l.contains('dinner') || l.contains('lunch') || l.contains('cafe') || l.contains('party')) {
      return '🍴';
    }
    return '👥';
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      final m = diff.inMinutes.clamp(1, 60);
      return '$m min ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} hours ago';
    } else if (diff.inDays == 1) {
      return '1 day ago';
    } else if (diff.inDays < 30) {
      return '${diff.inDays} days ago';
    } else {
      return DateFormat('d MMM').format(dt);
    }
  }
}
