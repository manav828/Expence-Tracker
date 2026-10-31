import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../providers/split_provider.dart';
import '../../models/split_models.dart';
import '../../services/auth_service.dart';
import '../../services/pixabay_service.dart';
import 'add_split_expense_sheet.dart';
import 'settle_up_screen.dart';
import 'group_banner_picker_sheet.dart';
import 'receipt_attachment_sheet.dart';

const List<Color> _avatarColors = [
  Color(0xFF006948), // Deep emerald
  Color(0xFF4B41E1), // Indigo
  Color(0xFF0284C7), // Sky blue
  Color(0xFFD97706), // Amber
  Color(0xFFDC2626), // Crimson
  Color(0xFF7C3AED), // Purple
];

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
    final color = _avatarColors[index % _avatarColors.length];
    final initial = member.name.trim().isNotEmpty
        ? member.name.trim()[0].toUpperCase()
        : '?';

    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: color,
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
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 12.5,
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
        '+$remainingCount',
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
                      Flexible(
                        child: Container(
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
                              Flexible(
                                child: Text(
                                  dateRangeStr,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

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
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: _buildMemberAvatarStack(context, members),
                          ),
                        ),
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
          if (_loadingDetail && sp.getMembersForGroup(_group.id).isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF006948)),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadDetail,
            color: _primaryColor,
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  // 1. Group Scenic Banner Card (Scrollable, NOT sticky)
                  SliverToBoxAdapter(
                    child: _buildHeroBanner(context, _group, sp),
                  ),

                  // 2. Tab Bar: Balances | Expenses | Members (Scrollable, NOT sticky)
                  SliverToBoxAdapter(
                    child: Container(
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
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  _BalancesTab(groupId: _group.id),
                  _ExpensesTab(groupId: _group.id),
                  _MembersTab(group: _group),
                ],
              ),
            ),
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
      final isSimplified = sp.isSimplifyDebtsEnabled(groupId);
      final directDebts = sp.getDebtsForGroup(groupId, forceSimplify: false);
      final simplifiedDebts = sp.getDebtsForGroup(groupId, forceSimplify: true);
      final debts = isSimplified ? simplifiedDebts : directDebts;
      final savingsCount = directDebts.length - simplifiedDebts.length;
      final memberMap = {for (final m in members) m.id: m.name};
      final expenses = sp.getExpensesForGroup(groupId);
      final hasUnsettled = debts.isNotEmpty || balances.values.any((b) => b.abs() >= 0.01);
      final settlementGroups = sp.getSettlementGroupsForGroup(groupId);
      final combinedResult = sp.getCombinedBalancesResult(groupId);

      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        children: [
          // Simplify Debts Toggle Card (allows user to choose between minimum payments or direct itemized)
          if (members.length > 1)
            _SimplifyDebtsCard(
              isSimplified: isSimplified,
              directCount: directDebts.length,
              simplifiedCount: simplifiedDebts.length,
              savingsCount: savingsCount > 0 ? savingsCount : 0,
              onToggle: (val) => sp.setSimplifyDebts(groupId, val),
              onInfoTap: () => _showSimplifyInfoModal(context),
            ),

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isSimplified ? 'Who Owes Whom (Simplified)' : 'Who Owes Whom (Direct)',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF131B2E)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isSimplified
                        ? const Color(0xFF006948).withValues(alpha: 0.1)
                        : const Color(0xFF64748B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${debts.length} ${debts.length == 1 ? "payment" : "payments"}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSimplified ? const Color(0xFF006948) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              isSimplified
                  ? 'Optimized to settle everyone with the minimum cash transfers'
                  : 'Showing direct debts based on who paid for whom',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6D7A72)),
            ),
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

          if (settlementGroups.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                const Text(
                  'Combined Settlement Balances',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF131B2E)),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4B41E1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${settlementGroups.length} ${settlementGroups.length == 1 ? "group" : "groups"}',
                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF4B41E1)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Linked members are settled together. Tap any group to see individual breakdown.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            ...settlementGroups.map((sg) {
              final groupBal = combinedResult.getGroupBalance(sg.id);
              final groupMembers = members.where((m) => sg.memberIds.contains(m.id)).toList();
              return _CombinedGroupBalanceCard(
                group: sg,
                combinedBalance: groupBal,
                members: groupMembers,
                balances: balances,
              );
            }),
            const SizedBox(height: 18),
            const Text(
              'Individual Net Balances',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF131B2E)),
            ),
            const SizedBox(height: 10),
            ...members.map((m) {
              final bal = balances[m.id] ?? 0.0;
              final linkedGroup = combinedResult.memberToGroupMap[m.id];
              return _BalanceRow(
                name: m.name,
                balance: bal,
                groupTag: linkedGroup?.name,
              );
            }),
          ] else if (balances.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('Individual Net Balances', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF131B2E))),
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

class _SimplifyDebtsCard extends StatelessWidget {
  final bool isSimplified;
  final int directCount;
  final int simplifiedCount;
  final int savingsCount;
  final ValueChanged<bool> onToggle;
  final VoidCallback onInfoTap;

  const _SimplifyDebtsCard({
    required this.isSimplified,
    required this.directCount,
    required this.simplifiedCount,
    required this.savingsCount,
    required this.onToggle,
    required this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSimplified
              ? const Color(0xFF006948).withValues(alpha: 0.25)
              : const Color(0x0F000000),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: isSimplified
                  ? const Color(0xFF006948).withValues(alpha: 0.1)
                  : const Color(0xFF64748B).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isSimplified
                  ? Icons.auto_awesome_rounded
                  : Icons.compare_arrows_rounded,
              color: isSimplified
                  ? const Color(0xFF006948)
                  : const Color(0xFF64748B),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      'Simplify Debts',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF131B2E),
                      ),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: onInfoTap,
                      borderRadius: BorderRadius.circular(10),
                      child: const Padding(
                        padding: EdgeInsets.all(3),
                        child: Icon(
                          Icons.info_outline_rounded,
                          size: 15,
                          color: Color(0xFF6D7A72),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isSimplified
                      ? (savingsCount > 0
                          ? '$savingsCount fewer payments ($simplifiedCount vs $directCount)'
                          : '$simplifiedCount ${simplifiedCount == 1 ? "payment" : "payments"} (minimized)')
                      : '$directCount direct pairwise ${directCount == 1 ? "payment" : "payments"}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSimplified && savingsCount > 0
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: isSimplified && savingsCount > 0
                        ? const Color(0xFF006948)
                        : const Color(0xFF6D7A72),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: isSimplified,
            activeColor: const Color(0xFF006948),
            onChanged: onToggle,
          ),
        ],
      ),
    );
  }
}

void _showSimplifyInfoModal(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF006948).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Color(0xFF006948),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'About Simplify Debts',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF131B2E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Simplify Debts reorganizes group payments to settle everyone using the absolute minimum number of transactions.',
            style: TextStyle(
              fontSize: 13.5,
              color: Color(0xFF3D4A42),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF8FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0x0F000000)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.compare_arrows_rounded, size: 18, color: Color(0xFF64748B)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Direct Mode (OFF): Shows debts strictly between the members who shared each specific bill.',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.35),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 18, color: Color(0xFF006948)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Simplified Mode (ON): If A owes B ₹500 and B owes C ₹500, A simply pays C ₹500 directly, taking B out of the middle.',
                        style: TextStyle(fontSize: 12.5, color: Color(0xFF006948), fontWeight: FontWeight.w600, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.verified_rounded, size: 18, color: Color(0xFF006948)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Everyone pays and receives the exact same net amount.',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF006948),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Got It', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ),
        ],
      ),
    ),
  );
}

class _DebtCard extends StatelessWidget {
  final Debt debt;
  final Map<String, String> memberMap;
  final VoidCallback onSettle;
  const _DebtCard({required this.debt, required this.memberMap, required this.onSettle});

  @override
  Widget build(BuildContext context) {
    final from = debt.fromGroupName ?? (memberMap[debt.fromMemberId] ?? debt.fromMemberId);
    final to = debt.toGroupName ?? (memberMap[debt.toMemberId] ?? debt.toMemberId);
    final fmt = NumberFormat('#,##0.00');
    final isGroupDebt = debt.isFromGroup || debt.isToGroup;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isGroupDebt
              ? const Color(0xFF4B41E1).withValues(alpha: 0.25)
              : const Color(0x0A000000),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (isGroupDebt)
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4B41E1).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Combined Settlement',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4B41E1),
                    ),
                  ),
                ),
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

class _CombinedGroupBalanceCard extends StatefulWidget {
  final SplitSettlementGroup group;
  final double combinedBalance;
  final List<SplitMember> members;
  final Map<String, double> balances;

  const _CombinedGroupBalanceCard({
    required this.group,
    required this.combinedBalance,
    required this.members,
    required this.balances,
  });

  @override
  State<_CombinedGroupBalanceCard> createState() => _CombinedGroupBalanceCardState();
}

class _CombinedGroupBalanceCardState extends State<_CombinedGroupBalanceCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final isPositive = widget.combinedBalance > 0.009;
    final isNegative = widget.combinedBalance < -0.009;
    final balColor = isPositive ? const Color(0xFF006948) : (isNegative ? Colors.red : const Color(0xFF6D7A72));
    final balText = isPositive
        ? 'Gets back ₹${fmt.format(widget.combinedBalance)}'
        : (isNegative ? 'Owes ₹${fmt.format(widget.combinedBalance.abs())}' : 'Settled up (₹0.00)');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4B41E1).withValues(alpha: 0.2)),
        boxShadow: const [
          BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4B41E1).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.group_work, color: Color(0xFF4B41E1), size: 22),
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
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4B41E1).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${widget.members.length} members',
                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF4B41E1)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          balText,
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: balColor),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: const Color(0xFF6D7A72),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            const Divider(height: 1, indent: 14, endIndent: 14),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Individual Member Breakdown:',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 6),
                  ...widget.members.map((m) {
                    final b = widget.balances[m.id] ?? 0.0;
                    final isP = b > 0.009;
                    final isN = b < -0.009;
                    final c = isP ? const Color(0xFF006948) : (isN ? Colors.red : const Color(0xFF6D7A72));
                    final t = isP ? '+₹${fmt.format(b)}' : (isN ? '-₹${fmt.format(b.abs())}' : '₹0.00');
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(m.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c)),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  final String name;
  final double balance;
  final String? groupTag;
  const _BalanceRow({required this.name, required this.balance, this.groupTag});

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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (groupTag != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Combined in "$groupTag"',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF4B41E1), fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
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
        return LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFFBCCAC0)),
                      SizedBox(height: 12),
                      Text('No expenses yet', style: TextStyle(color: Color(0xFF6D7A72), fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text('Tap "+ Add Expense" to get started', style: TextStyle(fontSize: 12, color: Color(0xFF6D7A72))),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }
      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
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
                    if (expense.receiptUrl != null && expense.receiptUrl!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => FullScreenReceiptViewer.show(
                          context,
                          imageUrl: expense.receiptUrl!,
                          title: expense.title,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF006948).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF006948).withValues(alpha: 0.25)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.receipt_long, size: 12, color: Color(0xFF006948)),
                              SizedBox(width: 4),
                              Text(
                                'Bill Attached',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF006948),
                                ),
                              ),
                              SizedBox(width: 2),
                              Icon(Icons.zoom_in, size: 12, color: Color(0xFF006948)),
                            ],
                          ),
                        ),
                      ),
                    ],
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
class _MembersTab extends StatefulWidget {
  final SplitGroup group;
  const _MembersTab({required this.group});

  @override
  State<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<_MembersTab> {
  final Set<String> _collapsedGroupIds = {};

  @override
  Widget build(BuildContext context) {
    return Consumer<SplitProvider>(builder: (context, sp, _) {
      final members = sp.getMembersForGroup(widget.group.id);
      final expenseGroups = sp.getExpenseGroupsForGroup(widget.group.id);
      final settlementGroups = sp.getSettlementGroupsForGroup(widget.group.id);
      final memberMap = {for (final m in members) m.id: m};

      final currentUid = Supabase.instance.client.auth.currentUser?.id;
      final currentMemberName = sp.currentMemberName ?? AuthService.instance.userDisplayName;
      final isGroupCreator = (widget.group.userId != null && currentUid != null && widget.group.userId == currentUid) ||
          (widget.group.createdBy.trim().toLowerCase() == currentMemberName.trim().toLowerCase());

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

      return Column(
        children: [
          Expanded(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              children: [
                // Sleek, Compact Action Bar (Title & Quick Add Buttons)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Text(
                        'Trip Members (${members.length})',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Color(0xFF0F172A)),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _showSettlementGroupModal(context, widget.group, members),
                        icon: const Icon(Icons.call_merge_rounded, size: 14, color: Color(0xFF4F46E5)),
                        label: const Text('Combine', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5))),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          backgroundColor: const Color(0xFFEEF2FF),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 6),
                      TextButton.icon(
                        onPressed: () => _showExpenseGroupModal(context, widget.group, members),
                        icon: const Icon(Icons.playlist_add_check_rounded, size: 14, color: Color(0xFF006948)),
                        label: const Text('Group', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF006948))),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          backgroundColor: const Color(0xFFE8F7F0),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.info_outline, size: 17, color: Color(0xFF64748B)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'How grouping works',
                        onPressed: () => _showGroupsInfoModal(context),
                      ),
                    ],
                  ),
                ),

                // 1. Individual Members on TOP
                if (ungroupedMembers.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.person_outline, size: 15, color: Color(0xFF64748B)),
                        const SizedBox(width: 5),
                        Text(
                          displayGroups.isNotEmpty
                              ? 'Individual Members (${ungroupedMembers.length})'
                              : 'All Members (${ungroupedMembers.length})',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  ...ungroupedMembers.map((m) {
                    final overallIndex = members.indexOf(m);
                    final isThisMemberCreator = (widget.group.userId != null && widget.group.userId!.isNotEmpty)
                        ? (m.userId != null && m.userId == widget.group.userId)
                        : (overallIndex == 0);
                    final isManualMember = (m.userId == null || m.userId!.isEmpty) && !isThisMemberCreator;
                    final canEditName = isGroupCreator && (isManualMember || isThisMemberCreator);

                    return _MemberTile(
                      member: m,
                      group: widget.group,
                      index: overallIndex >= 0 ? overallIndex : 0,
                      isGroupCreator: isGroupCreator,
                      isThisMemberCreator: isThisMemberCreator,
                      isManualMember: isManualMember,
                      canEditName: canEditName,
                    );
                  }),
                ],

                // 2. Groups BELOW Individual Members (sleek & compact)
                if (displayGroups.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.folder_outlined, size: 15, color: Color(0xFF64748B)),
                        const SizedBox(width: 5),
                        Text(
                          'Groups & Combinations (${displayGroups.length})',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  ...displayGroups.map((group) {
                    final groupMembers = group.memberIds
                        .map((mid) => memberMap[mid])
                        .whereType<SplitMember>()
                        .toList();
                    final isCollapsed = _collapsedGroupIds.contains(group.id);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sleek Group Header Card with Expand/Collapse arrow
                          Container(
                            decoration: BoxDecoration(
                              color: group.isSettlement
                                  ? const Color(0xFFEEF2FF).withValues(alpha: 0.7)
                                  : const Color(0xFFE8F7F0).withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: group.isSettlement
                                    ? const Color(0xFF4F46E5).withValues(alpha: 0.25)
                                    : const Color(0xFF006948).withValues(alpha: 0.25),
                              ),
                            ),
                            child: InkWell(
                              onTap: () => setState(() {
                                if (isCollapsed) {
                                  _collapsedGroupIds.remove(group.id);
                                } else {
                                  _collapsedGroupIds.add(group.id);
                                }
                              }),
                              borderRadius: BorderRadius.circular(10),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                child: Row(
                                  children: [
                                    Icon(
                                      group.isSettlement ? Icons.call_merge_rounded : Icons.playlist_add_check_rounded,
                                      size: 16,
                                      color: group.isSettlement ? const Color(0xFF4F46E5) : const Color(0xFF006948),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              group.name,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                                color: Color(0xFF0F172A),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              group.isSettlement ? 'Combined Settlement' : 'Expense Group',
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w700,
                                                color: group.isSettlement ? const Color(0xFF4F46E5) : const Color(0xFF006948),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '(${groupMembers.length})',
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      isCollapsed ? Icons.keyboard_arrow_right_rounded : Icons.keyboard_arrow_down_rounded,
                                      size: 18,
                                      color: const Color(0xFF64748B),
                                    ),
                                    const SizedBox(width: 2),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert, size: 17, color: Color(0xFF94A3B8)),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onSelected: (val) {
                                        if (val == 'edit') {
                                          if (group.isSettlement && group.settlementGroup != null) {
                                            _showSettlementGroupModal(context, widget.group, members, existing: group.settlementGroup);
                                          } else if (group.expenseGroup != null) {
                                            _showExpenseGroupModal(context, widget.group, members, existing: group.expenseGroup);
                                          }
                                        } else if (val == 'delete') {
                                          if (group.isSettlement && group.settlementGroup != null) {
                                            _showDeleteGroupConfirm(
                                              context,
                                              title: 'Dissolve Combined Settlement',
                                              message: 'Dissolve "${group.name}"? Balances will be settled individually again.',
                                              onConfirm: () => sp.deleteSettlementGroup(settlementGroupId: group.id, groupId: widget.group.id),
                                            );
                                          } else if (group.expenseGroup != null) {
                                            _showDeleteGroupConfirm(
                                              context,
                                              title: 'Delete Expense Group',
                                              message: 'Delete "${group.name}"? Members will remain in the group.',
                                              onConfirm: () => sp.deleteExpenseGroup(expenseGroupId: group.id, groupId: widget.group.id),
                                            );
                                          }
                                        }
                                      },
                                      itemBuilder: (ctx) => [
                                        const PopupMenuItem(value: 'edit', child: Text('Edit Group')),
                                        const PopupMenuItem(value: 'delete', child: Text('Dissolve / Delete', style: TextStyle(color: Colors.red))),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Nested Members with compact Tree Connector Lines
                          if (!isCollapsed) ...[
                            ...groupMembers.asMap().entries.map((entry) {
                              final idx = entry.key;
                              final m = entry.value;
                              final isLast = (idx == groupMembers.length - 1);
                              final overallIndex = members.indexOf(m);
                              final isThisMemberCreator = (widget.group.userId != null && widget.group.userId!.isNotEmpty)
                                  ? (m.userId != null && m.userId == widget.group.userId)
                                  : (overallIndex == 0);
                              final isManualMember = (m.userId == null || m.userId!.isEmpty) && !isThisMemberCreator;
                              final canEditName = isGroupCreator && (isManualMember || isThisMemberCreator);

                              return IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    SizedBox(
                                      width: 22,
                                      child: CustomPaint(
                                        painter: _TreeBranchPainter(
                                          isLast: isLast,
                                          color: group.isSettlement
                                              ? const Color(0xFFC7D2FE)
                                              : const Color(0xFFCBD5E1),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 3),
                                        child: _MemberTile(
                                          member: m,
                                          group: widget.group,
                                          index: overallIndex >= 0 ? overallIndex : idx,
                                          isGroupCreator: isGroupCreator,
                                          isThisMemberCreator: isThisMemberCreator,
                                          isManualMember: isManualMember,
                                          canEditName: canEditName,
                                          compact: true,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ],
                      ),
                    );
                  }),
                ],

                if (members.isEmpty)
                  const Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text('No members in this group'))),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _showAddMemberDialog(context, sp, widget.group),
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
    this.isSettlement = false,
    this.settlementGroup,
    this.expenseGroup,
  });
}

class _TreeBranchPainter extends CustomPainter {
  final bool isLast;
  final Color color;

  const _TreeBranchPainter({
    required this.isLast,
    this.color = const Color(0xFFCBD5E1),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final double midX = size.width / 2;
    final double midY = size.height / 2;

    // Vertical trunk
    canvas.drawLine(
      Offset(midX, 0),
      Offset(midX, isLast ? midY : size.height),
      paint,
    );

    // Horizontal branch
    canvas.drawLine(
      Offset(midX, midY),
      Offset(size.width, midY),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _TreeBranchPainter oldDelegate) =>
      oldDelegate.isLast != isLast || oldDelegate.color != color;
}

// ─── Group Management Helpers & Dialogs ─────────────────────────────────────

Future<void> _showAddMemberDialog(BuildContext context, SplitProvider sp, SplitGroup group) async {
  final ctrl = TextEditingController();
  await showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Add Member', style: TextStyle(fontWeight: FontWeight.w800)),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          hintText: 'Member name',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF006948),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () async {
            final newName = ctrl.text.trim();
            if (newName.isNotEmpty) {
              final existing = sp.getMembersForGroup(group.id);
              if (existing.any((m) => m.name.trim().toLowerCase() == newName.toLowerCase())) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Member "$newName" already exists in this group'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              await sp.addMember(group.id, newName);
              if (context.mounted) Navigator.pop(context);
            }
          },
          child: const Text('Add', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
}

void _showGroupsInfoModal(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.info_outline, color: Color(0xFF006948)),
          SizedBox(width: 8),
          Text('Group Types Explained', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F7F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.playlist_add_check_rounded, color: Color(0xFF006948), size: 20),
                      SizedBox(width: 6),
                      Text('Expense Member Group', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF006948), fontSize: 14)),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Shortcut for selecting multiple participants at once when adding an expense (e.g. Office Team or Family).\n\nEveryone still receives their own individual expense split.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF1E293B), height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.call_merge_rounded, color: Color(0xFF4F46E5), size: 20),
                      SizedBox(width: 6),
                      Text('Combined Settlement Group', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF4F46E5), fontSize: 14)),
                    ],
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Links 2 or more members (e.g. Couples or Families) to combine their net balances during settlements.\n\nGenerates fewer settlement payments while keeping each member\'s individual expense history intact.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF1E293B), height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF006948),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Got it', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

Future<void> _showDeleteGroupConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required Future<void> Function() onConfirm,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      content: Text(message, style: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await onConfirm();
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
                      child: const Icon(Icons.playlist_add_check_rounded, color: Color(0xFF006948), size: 22),
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
                        activeColor: const Color(0xFF006948),
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
                      backgroundColor: const Color(0xFF006948),
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

  // Map of memberId -> settlement group name where they are already assigned (excluding current existing group)
  final allSettlementGroups = sp.getSettlementGroupsForGroup(group.id);
  final takenMemberMap = <String, String>{};
  for (final sg in allSettlementGroups) {
    if (existing != null && sg.id == existing.id) continue;
    for (final mid in sg.memberIds) {
      takenMemberMap[mid] = sg.name;
    }
  }

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
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: members.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (ctx, i) {
                      final m = members[i];
                      final isTaken = takenMemberMap.containsKey(m.id);
                      final takenBy = takenMemberMap[m.id];
                      final isSelected = selectedIds.contains(m.id);

                      return CheckboxListTile(
                        value: isSelected,
                        dense: true,
                        activeColor: const Color(0xFF4F46E5),
                        enabled: !isTaken,
                        title: Text(
                          m.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: isTaken ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                          ),
                        ),
                        subtitle: isTaken
                            ? Text('Already combined in "$takenBy"', style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444)))
                            : null,
                        onChanged: isTaken
                            ? null
                            : (val) {
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

class _MemberTile extends StatelessWidget {
  final SplitMember member;
  final SplitGroup group;
  final int index;
  final bool isGroupCreator;
  final bool isThisMemberCreator;
  final bool isManualMember;
  final bool canEditName;
  final bool compact;

  const _MemberTile({
    required this.member,
    required this.group,
    required this.index,
    required this.isGroupCreator,
    required this.isThisMemberCreator,
    required this.isManualMember,
    required this.canEditName,
    this.compact = false,
  });

  void _showEditNameDialog(BuildContext context) {
    final ctrl = TextEditingController(text: member.name);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F7F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.edit_note_rounded, color: Color(0xFF006948), size: 22),
            ),
            const SizedBox(width: 10),
            const Text(
              'Change Name',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isThisMemberCreator
                    ? 'Update your display name for this group.'
                    : 'This member was added manually. You can update their display name for this group.',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: ctrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Member Name',
                  hintText: 'Enter name',
                  prefixIcon: const Icon(Icons.person_outline, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF006948), width: 2),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Name cannot be empty';
                  }
                  final trimmed = val.trim().toLowerCase();
                  final allMembers = context.read<SplitProvider>().getMembersForGroup(group.id);
                  if (allMembers.any((m) => m.id != member.id && m.name.trim().toLowerCase() == trimmed)) {
                    return 'A member with this name already exists in this group';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006948),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                final newName = ctrl.text.trim();
                Navigator.pop(ctx);
                if (newName != member.name) {
                  await context.read<SplitProvider>().updateMemberName(group.id, member.id, newName);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Member name updated to "$newName"'),
                        backgroundColor: const Color(0xFF006948),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showAssignMemberDialog(BuildContext context, List<SplitMember> allMembers) {
    final otherMembers = allMembers.where((m) => m.id != member.id).toList();
    if (otherMembers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other members in this group to transfer entries to.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF2563EB), size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Assign Entries To',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Transfer all past expenses, shares, and settlements from "${member.name}" to another member who joined:',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: SingleChildScrollView(
                child: Column(
                  children: otherMembers.map((target) {
                    final isTargetJoined = target.userId != null && target.userId!.isNotEmpty;
                    return ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFF006948),
                        child: Text(
                          target.name.trim().isNotEmpty ? target.name.trim()[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                      title: Text(
                        target.name,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                      subtitle: Text(
                        isTargetJoined ? 'Joined via invite link' : 'Group member',
                        style: TextStyle(fontSize: 11, color: isTargetJoined ? const Color(0xFF2563EB) : const Color(0xFF94A3B8)),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF64748B)),
                      onTap: () async {
                        Navigator.pop(ctx);
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c2) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            title: const Text('Confirm Transfer'),
                            content: Text(
                              'Transfer all expenses and shares from "${member.name}" to "${target.name}"? "${member.name}" will then be merged and removed.',
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c2, false), child: const Text('Cancel')),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF006948)),
                                onPressed: () => Navigator.pop(c2, true),
                                child: const Text('Confirm & Transfer', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && context.mounted) {
                          await context.read<SplitProvider>().mergeMembers(group.id, member.id, target.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('All entries transferred to "${target.name}"!'),
                                backgroundColor: const Color(0xFF006948),
                              ),
                            );
                          }
                        }
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarColor = _avatarColors[index % _avatarColors.length];
    final initial = member.name.trim().isNotEmpty ? member.name.trim()[0].toUpperCase() : '?';

    if (compact) {
      return Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: avatarColor,
              child: Text(
                initial,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10.5),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      member.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isThisMemberCreator) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F7F0),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Admin', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF006948))),
                    ),
                  ],
                ],
              ),
            ),
            if (canEditName)
              InkWell(
                onTap: () => _showEditNameDialog(context),
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.edit_outlined, size: 15, color: Color(0xFF64748B)),
                ),
              ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 1. Initial Circle Avatar matching outside card
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: avatarColor,
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
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // 2. Member Name & Status Badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                if (isThisMemberCreator)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F7F0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Group Creator',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF006948),
                      ),
                    ),
                  )
                else if (isManualMember)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Added manually',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.link, size: 10.5, color: Color(0xFF2563EB)),
                        SizedBox(width: 3),
                        Text(
                          'Joined via invite',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // 3. Edit Name Action (If added manually or creator's own name, and current user is group creator)
          if (canEditName)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Color(0xFF006948), size: 20),
              tooltip: 'Change Name',
              onPressed: () => _showEditNameDialog(context),
            ),

          // 4. Assign / Transfer Action (Transfer all entries from temp manual member to joined person)
          if (isGroupCreator && isManualMember)
            IconButton(
              icon: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF2563EB), size: 21),
              tooltip: 'Assign entries to joined member',
              onPressed: () {
                final all = context.read<SplitProvider>().getMembersForGroup(group.id);
                _showAssignMemberDialog(context, all);
              },
            ),

          // 5. Remove Action (Creator can remove members except themselves)
          if (isGroupCreator && !isThisMemberCreator)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFEF4444), size: 20),
              tooltip: 'Remove Member',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text('Remove Member'),
                    content: Text('Remove ${member.name} from the group?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Remove', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  await context.read<SplitProvider>().removeMember(group.id, member.id);
                }
              },
            ),
        ],
      ),
    );
  }
}
