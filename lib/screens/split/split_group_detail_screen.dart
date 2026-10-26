import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/split_provider.dart';
import '../../models/split_models.dart';
import '../../services/pixabay_service.dart';
import 'add_split_expense_sheet.dart';
import 'settle_up_screen.dart';

class SplitGroupDetailScreen extends StatefulWidget {
  final SplitGroup group;
  const SplitGroupDetailScreen({super.key, required this.group});
  @override
  State<SplitGroupDetailScreen> createState() => _SplitGroupDetailScreenState();
}

class _SplitGroupDetailScreenState extends State<SplitGroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late SplitGroup _group;
  bool _loadingDetail = true;
  static const _primaryColor = Color(0xFF006948);

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _loadingDetail = true);
    await context.read<SplitProvider>().loadGroupDetail(_group.id);
    if (mounted) setState(() => _loadingDetail = false);
  }

  void _shareInvite() {
    final webUrl = kIsWeb
        ? '${Uri.base.origin}/?code=${_group.inviteCode}'
        : 'https://expensetracker.web.app/?code=${_group.inviteCode}';
    final shareText = 'Join our group "${_group.name}" on ExpenCircle!\n'
        'Invite Code: ${_group.inviteCode}\n'
        'Direct link: $webUrl';
    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite link copied! Friends can open it in browser or app.'),
        backgroundColor: _primaryColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                          : const Icon(Icons.refresh_rounded, size: 16, color: _primaryColor),
                      label: Text(
                        isRefreshingCover ? 'Fetching...' : 'New Pixabay Photo',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _primaryColor),
                      ),
                    ),
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

  static const List<String> _memberAvatarUrls = [
    'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=120&q=80',
    'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=120&q=80',
    'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?auto=format&fit=crop&w=120&q=80',
    'https://images.unsplash.com/photo-1580489944761-15a19d654956?auto=format&fit=crop&w=120&q=80',
    'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=120&q=80',
    'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=120&q=80',
  ];

  static const List<Color> _avatarColors = [
    Color(0xFF2563EB),
    Color(0xFF059669),
    Color(0xFFD97706),
    Color(0xFFDC2626),
    Color(0xFF7C3AED),
    Color(0xFF0891B2),
  ];

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
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF006948)),
            onPressed: () async {
              if (ctrl.text.trim().isNotEmpty) {
                await context.read<SplitProvider>().addMember(_group.id, ctrl.text.trim());
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberAvatarStack(BuildContext context, List<SplitMember> members) {
    const int maxVisible = 3;
    final hasOverflow = members.length > maxVisible;
    final visibleCount = hasOverflow ? maxVisible : members.length;
    final remaining = hasOverflow ? (members.length - maxVisible) : 0;
    final totalItems = visibleCount + (hasOverflow ? 1 : 0);

    const double avatarSize = 32.0;
    const double overlap = 22.0;
    final double stackWidth = totalItems <= 1
        ? avatarSize
        : ((totalItems - 1) * overlap + avatarSize);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (members.isNotEmpty)
          SizedBox(
            height: avatarSize,
            width: stackWidth,
            child: Stack(
              children: [
                for (int i = 0; i < visibleCount; i++)
                  Positioned(
                    left: i * overlap,
                    child: _buildAvatarCircle(members[i], i),
                  ),
                if (hasOverflow)
                  Positioned(
                    left: visibleCount * overlap,
                    child: _buildOverflowCircle(remaining),
                  ),
              ],
            ),
          ),
        const SizedBox(width: 6),
        // Add member circular button
        InkWell(
          onTap: _showAddMemberDialog,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x10000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.add, size: 18, color: Color(0xFF006948)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarCircle(SplitMember member, int index) {
    final avatarUrl = _memberAvatarUrls[index % _memberAvatarUrls.length];
    final fallbackColor = _avatarColors[index % _avatarColors.length];
    final initial = member.name.isNotEmpty ? member.name.substring(0, 1).toUpperCase() : '?';

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.network(
          avatarUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            color: fallbackColor,
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverflowCircle(int remainingCount) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '${remainingCount}+',
        style: const TextStyle(
          color: Color(0xFF1E293B),
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }

  String _computeDateRange(SplitGroup group, List<SplitExpense> expenses) {
    if (expenses.isNotEmpty) {
      final sorted = List<SplitExpense>.from(expenses)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final start = sorted.first.createdAt;
      final end = sorted.last.createdAt;
      if (start.year == end.year && start.month == end.month && start.day == end.day) {
        return DateFormat('d MMM yyyy').format(start);
      } else if (start.year == end.year && start.month == end.month) {
        return '${start.day}-${end.day} ${DateFormat('MMM yyyy').format(end)}';
      } else if (start.year == end.year) {
        return '${DateFormat('d MMM').format(start)} - ${DateFormat('d MMM yyyy').format(end)}';
      } else {
        return '${DateFormat('d MMM yyyy').format(start)} - ${DateFormat('d MMM yyyy').format(end)}';
      }
    }
    return DateFormat('d MMM yyyy').format(group.createdAt);
  }

  Widget _buildHeroBanner(BuildContext context, SplitGroup group, SplitProvider sp) {
    final expenses = sp.getExpensesForGroup(group.id);
    final members = sp.getMembersForGroup(group.id);
    final dateRangeStr = _computeDateRange(group, expenses);
    final coverUrl = group.imageUrl ?? _getCoverImageUrl(group.name);
    final totalSpend = expenses.fold(0.0, (sum, exp) => sum + exp.totalAmount);

    final tagline = group.description?.isNotEmpty == true
        ? group.description!
        : (group.name.toLowerCase().contains('udaipur')
            ? 'Good friends, great food, better memories 💚'
            : (group.name.toLowerCase().contains('trip') || group.name.toLowerCase().contains('bali')
                ? 'Good food, better people, unforgettable moments 🌴'
                : 'Good friends, great food, better memories 💚'));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x18000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background scenic photo
            Image.network(
              coverUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF006948), Color(0xFF008096)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(
                  color: const Color(0xFF1E293B),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  ),
                );
              },
            ),

            // Subtle dark overlay gradient for clean text readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.black.withValues(alpha: 0.65),
                  ],
                ),
              ),
            ),

            // Banner Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Date range badge & Edit button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Date Range Pill Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.38),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_today_outlined, size: 12, color: Colors.white),
                            const SizedBox(width: 5),
                            Text(
                              dateRangeStr,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Edit Translucent Pill Button
                      InkWell(
                        onTap: _showEditGroupDialog,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.42),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_outlined, size: 13, color: Colors.white),
                              SizedBox(width: 4.5),
                              Text(
                                'Edit',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // Middle: Group Name & Tagline
                  Text(
                    group.name,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.4,
                      shadows: [
                        Shadow(
                          color: Color(0x66000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tagline,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.95),
                      fontWeight: FontWeight.w500,
                      shadows: const [
                        Shadow(
                          color: Color(0x66000000),
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const Spacer(),

                  // Bottom Floating White Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 10,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Green Icon Circle (Briefcase / Spend Bag)
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F7F0),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.medical_services_rounded,
                              color: Color(0xFF006948),
                              size: 19,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Spend Info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Total Group Spend',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                '₹${NumberFormat('#,##,##0.00').format(totalSpend)}',
                                style: const TextStyle(
                                  fontSize: 18.5,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                  letterSpacing: -0.4,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 1),
                              Text(
                                '${members.length} members • ${expenses.length} expenses',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Member Avatars with overflow badge & Add button
                        _buildMemberAvatarStack(context, members),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 38,
                height: 38,
                child: Image.network(
                  _group.imageUrl ?? _getCoverImageUrl(_group.name),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: _primaryColor.withValues(alpha: 0.15),
                    child: Center(
                      child: Text(
                        _getGroupEmoji(_group.name),
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _group.name,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(_getGroupEmoji(_group.name), style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                  Consumer<SplitProvider>(
                    builder: (context, sp, _) {
                      final members = sp.getMembersForGroup(_group.id);
                      final isMe = _group.createdBy == sp.currentMemberName;
                      return Text(
                        '${members.length} members · Created by ${isMe ? 'You' : _group.createdBy}',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF6D7A72), fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF131B2E),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Edit Group',
            onPressed: _showEditGroupDialog,
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, size: 20),
            tooltip: 'Share Invite Link',
            onPressed: _shareInvite,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (v) async {
              if (v == 'delete') {
                final nav = Navigator.of(context);
                final splitProv = context.read<SplitProvider>();
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Delete Group'),
                    content: const Text('This will permanently delete all expenses and settlements. Are you sure?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Delete', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirm == true && mounted) {
                  await splitProv.deleteGroup(_group.id);
                  if (mounted) nav.pop();
                }
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red, size: 18),
                    SizedBox(width: 8),
                    Text('Delete Group', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<SplitProvider>(
        builder: (context, sp, _) {
          return Column(
            children: [
              // 1. Group Scenic Banner Card
              _buildHeroBanner(context, _group, sp),

              // 2. Tab Bar: Balances | Expenses | Members
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0x0F000000), width: 1)),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: _primaryColor,
                  unselectedLabelColor: const Color(0xFF6D7A72),
                  indicatorColor: _primaryColor,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                  tabs: const [
                    Tab(text: 'Balances'),
                    Tab(text: 'Expenses'),
                    Tab(text: 'Members'),
                  ],
                ),
              ),

              // 3. TabBarView
              Expanded(
                child: _loadingDetail
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: _loadDetail,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _BalancesTab(groupId: _group.id),
                            _ExpensesTab(groupId: _group.id),
                            _MembersTab(groupId: _group.id),
                          ],
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _tabController.index == 2
          ? null
          : FloatingActionButton.extended(
              onPressed: () async {
                final members = context.read<SplitProvider>().getMembersForGroup(_group.id);
                if (members.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Add members first')));
                  return;
                }
                await showModalBottomSheet(
                  context: context, isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => AddSplitExpenseSheet(
                    groupId: _group.id,
                    members: members,
                    currentMemberName: context.read<SplitProvider>().currentMemberName,
                  ),
                );
                _loadDetail();
              },
              label: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.w700)),
              icon: const Icon(Icons.add),
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
            ),
    );
  }
}

// ─── Balances Tab ────────────────────────────────────────────────────────────
class _BalancesTab extends StatelessWidget {
  final String groupId;
  const _BalancesTab({required this.groupId});

  @override
  Widget build(BuildContext context) {
    return Consumer<SplitProvider>(builder: (context, sp, _) {
      final members = sp.getMembersForGroup(groupId);
      final balances = sp.getBalancesForGroup(groupId);
      final debts = sp.getDebtsForGroup(groupId);
      final memberMap = {for (final m in members) m.id: m.name};
      final expenses = sp.getExpensesForGroup(groupId);
      final hasUnsettled = debts.isNotEmpty || balances.values.any((b) => b.abs() >= 0.01);

      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          if (!hasUnsettled) ...[
            Center(child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(children: [
                Icon(expenses.isEmpty ? Icons.receipt_long_outlined : Icons.check_circle_outline,
                    size: 48, color: const Color(0xFF006948)),
                const SizedBox(height: 8),
                Text(expenses.isEmpty ? 'No expenses yet' : 'All settled up! 🎉',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                if (expenses.isEmpty) ...[
                  const SizedBox(height: 4),
                  const Text('Add expenses to start splitting with the group',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6D7A72))),
                ],
              ]),
            )),
          ] else ...[
            const Text('Who Owes Whom', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF131B2E))),
            const SizedBox(height: 4),
            const Text('Simplified to minimum transactions', style: TextStyle(fontSize: 12, color: Color(0xFF6D7A72))),
            const SizedBox(height: 12),
            ...debts.map((debt) => _DebtCard(
              debt: debt, memberMap: memberMap,
              onSettle: () async {
                await showModalBottomSheet<double>(
                  context: context, isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => SettleUpScreen(
                    debt: debt, memberMap: memberMap,
                    groupId: groupId,
                  ),
                );
              },
            )),
          ],
          if (balances.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('Individual Balances', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF131B2E))),
            const SizedBox(height: 12),
            ...members.map((m) {
              final bal = balances[m.id] ?? 0.0;
              return _BalanceRow(name: m.name, balance: bal);
            }),
          ],
        ],
      );
    });
  }
}

class _DebtCard extends StatelessWidget {
  final Debt debt;
  final Map<String, String> memberMap;
  final VoidCallback onSettle;
  const _DebtCard({required this.debt, required this.memberMap, required this.onSettle});

  @override
  Widget build(BuildContext context) {
    final from = memberMap[debt.fromMemberId] ?? debt.fromMemberId;
    final to = memberMap[debt.toMemberId] ?? debt.toMemberId;
    final fmt = NumberFormat('#,##0.00');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x0A000000)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              RichText(text: TextSpan(
                style: const TextStyle(fontSize: 14, color: Color(0xFF131B2E)),
                children: [
                  TextSpan(text: from, style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.red)),
                  const TextSpan(text: ' owes '),
                  TextSpan(text: to, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF006948))),
                ],
              )),
              Text('₹${fmt.format(debt.amount)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF131B2E))),
            ]),
          ),
          ElevatedButton(
            onPressed: onSettle,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006948), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: const Text('Settle', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  final String name; final double balance;
  const _BalanceRow({required this.name, required this.balance});
  @override
  Widget build(BuildContext context) {
    final isPositive = balance >= 0;
    final fmt = NumberFormat('#,##0.00');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x0A000000)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18, backgroundColor: isPositive
                ? const Color(0xFF006948).withValues(alpha: 0.1)
                : Colors.red.withValues(alpha: 0.1),
            child: Text(name[0].toUpperCase(),
                style: TextStyle(fontWeight: FontWeight.w800, color: isPositive ? const Color(0xFF006948) : Colors.red)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(isPositive ? '+ ₹${fmt.format(balance)}' : '- ₹${fmt.format(balance.abs())}',
                style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 14,
                  color: isPositive ? const Color(0xFF006948) : Colors.red,
                )),
            Text(isPositive ? 'gets back' : 'owes',
                style: const TextStyle(fontSize: 11, color: Color(0xFF6D7A72))),
          ]),
        ],
      ),
    );
  }
}

// ─── Expenses Tab ─────────────────────────────────────────────────────────────
class _ExpensesTab extends StatelessWidget {
  final String groupId;
  const _ExpensesTab({required this.groupId});

  @override
  Widget build(BuildContext context) {
    return Consumer<SplitProvider>(builder: (context, sp, _) {
      final expenses = sp.getExpensesForGroup(groupId);
      final members = sp.getMembersForGroup(groupId);
      final memberMap = {for (final m in members) m.id: m.name};
      if (expenses.isEmpty) {
        return const Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFFBCCAC0)),
            SizedBox(height: 12),
            Text('No expenses yet', style: TextStyle(color: Color(0xFF6D7A72))),
            SizedBox(height: 4),
            Text('Tap "+ Add Expense" to get started', style: TextStyle(fontSize: 12, color: Color(0xFF6D7A72))),
          ]),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: expenses.length,
        itemBuilder: (context, i) => _ExpenseCard(
          expense: expenses[i],
          memberMap: memberMap,
          groupId: groupId,
          members: members,
        ),
      );
    });
  }
}

class _ExpenseCard extends StatelessWidget {
  final SplitExpense expense;
  final Map<String, String> memberMap;
  final String groupId;
  final List<SplitMember> members;
  const _ExpenseCard({
    required this.expense,
    required this.memberMap,
    required this.groupId,
    required this.members,
  });

  @override
  Widget build(BuildContext context) {
    final paidBy = memberMap[expense.paidByMemberId] ?? 'Former Member';
    final addedBy = memberMap[expense.addedByMemberId] ?? 'Former Member';
    final fmt = NumberFormat('#,##0.00');
    final dateStr = DateFormat('d MMM').format(expense.createdAt);
    return Dismissible(
      key: Key(expense.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Delete Expense'),
          content: Text('Delete "${expense.title}"?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
      onDismissed: (_) => context.read<SplitProvider>().deleteExpense(groupId, expense.id),
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(14)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () async {
            await showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => AddSplitExpenseSheet(
                groupId: groupId,
                members: members,
                expenseToEdit: expense,
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x0A000000)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF4B41E1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.receipt_outlined, color: Color(0xFF4B41E1), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(expense.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      paidBy == addedBy
                          ? 'Paid by $paidBy • $dateStr'
                          : 'Paid by $paidBy (by $addedBy) • $dateStr',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF6D7A72)),
                    ),
                    if (expense.note != null && expense.note!.isNotEmpty)
                      Text(expense.note!, style: const TextStyle(fontSize: 12, color: Color(0xFF6D7A72))),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('₹${fmt.format(expense.totalAmount)}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF131B2E))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF006948).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(expense.splitType.label,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF006948))),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Members Tab ─────────────────────────────────────────────────────────────
class _MembersTab extends StatelessWidget {
  final String groupId;
  const _MembersTab({required this.groupId});

  @override
  Widget build(BuildContext context) {
    return Consumer<SplitProvider>(builder: (context, sp, _) {
      final members = sp.getMembersForGroup(groupId);
      return Column(
        children: [
          Expanded(
            child: members.isEmpty
                ? const Center(child: Text('No members'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    itemCount: members.length,
                    itemBuilder: (context, i) => _MemberTile(member: members[i], groupId: groupId),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final ctrl = TextEditingController();
                    await showDialog(
                      context: context,
                      builder: (_) => AlertDialog(
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
                          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF006948)),
                            onPressed: () async {
                              if (ctrl.text.trim().isNotEmpty) {
                                await sp.addMember(groupId, ctrl.text.trim());
                                if (context.mounted) Navigator.pop(context);
                              }
                            },
                            child: const Text('Add', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.person_add_outlined),
                  label: const Text('Add Member', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006948),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

class _MemberTile extends StatelessWidget {
  final SplitMember member; final String groupId;
  const _MemberTile({required this.member, required this.groupId});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x0A000000)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFF006948).withValues(alpha: 0.1),
            child: Text(member.name[0].toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF006948))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(member.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Remove Member'),
                  content: Text('Remove ${member.name} from the group?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Remove', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              );
              if (confirm == true && context.mounted) {
                await context.read<SplitProvider>().removeMember(groupId, member.id);
              }
            },
          ),
        ],
      ),
    );
  }
}
