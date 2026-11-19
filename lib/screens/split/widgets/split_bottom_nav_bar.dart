import 'package:flutter/material.dart';

/// CheQ-style unified 5-item Bottom Navigation Dock for Split Group screens.
///
/// Items:
/// 0: Expenses
/// 1: Settle
/// Center (+): Add Expense elevated trigger
/// 2: Members
/// 3: Photos
class SplitBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onAddExpenseTap;
  final int photoCount;

  const SplitBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.onAddExpenseTap,
    this.photoCount = 0,
  });

  static const _activeGreen = Color(0xFF00B865);
  static const _inactiveSlate = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(8, 6, 8, bottomInset > 0 ? bottomInset : 8),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // 1. Expenses
              _buildNavItem(
                index: 0,
                label: 'Expenses',
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long,
              ),

              // 2. Settle
              _buildNavItem(
                index: 1,
                label: 'Settle',
                icon: Icons.sync_alt_rounded,
                activeIcon: Icons.sync_alt_rounded,
              ),

              // 3. Spacer for center elevated Add button
              const SizedBox(width: 56),

              // 4. Members
              _buildNavItem(
                index: 2,
                label: 'Members',
                icon: Icons.group_outlined,
                activeIcon: Icons.group_rounded,
              ),

              // 5. Photos
              _buildNavItem(
                index: 3,
                label: photoCount > 0 ? 'Photos ($photoCount)' : 'Photos',
                icon: Icons.photo_library_outlined,
                activeIcon: Icons.photo_library_rounded,
              ),
            ],
          ),

          // Center Elevated Floating Add Button
          Positioned(
            top: -22,
            child: GestureDetector(
              onTap: onAddExpenseTap,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _activeGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3.5),
                      boxShadow: [
                        BoxShadow(
                          color: _activeGreen.withValues(alpha: 0.38),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Add Expense',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
  }) {
    final isActive = currentIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => onTabSelected(index),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? activeIcon : icon,
                color: isActive ? _activeGreen : _inactiveSlate,
                size: 22,
              ),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                  color: isActive ? _activeGreen : _inactiveSlate,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isActive ? 4 : 0,
                height: isActive ? 4 : 0,
                decoration: const BoxDecoration(
                  color: _activeGreen,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
