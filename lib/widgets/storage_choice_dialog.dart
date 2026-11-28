import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/storage_preference_service.dart';
import '../services/auth_service.dart';
import '../providers/expense_provider.dart';
import '../core/theme/app_colors.dart';


class StorageChoiceDialog extends StatefulWidget {
  final bool isDismissible;

  const StorageChoiceDialog({super.key, this.isDismissible = false});

  static Future<void> showIfNeeded(BuildContext context) async {
    // Ask users who haven't explicitly selected a personal-expense storage mode yet.
    // Never auto-enable Cloud storage without explicit user consent.
    final hasChosen = await StoragePreferenceService.hasChosenMode();
    if (!hasChosen && context.mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const StorageChoiceDialog(isDismissible: false),
      );
    }
  }

  static Future<void> showForChange(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const StorageChoiceDialog(isDismissible: true),
    );
  }

  @override
  State<StorageChoiceDialog> createState() => _StorageChoiceDialogState();
}

class _StorageChoiceDialogState extends State<StorageChoiceDialog> {
  StorageMode _selectedMode = StorageMode.local;
  CloudBackupSchedule _selectedSchedule = CloudBackupSchedule.weekly;
  DateTime? _lastBackupAt;
  bool _isBackingUpNow = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final mode = await StoragePreferenceService.getMode();
    final schedule = await StoragePreferenceService.getBackupSchedule();
    final uid = AuthService.instance.currentUser?.id;
    final lastBackup = uid != null
        ? await StoragePreferenceService.getLastBackupAt(uid)
        : null;
    if (mounted) {
      setState(() {
        _selectedMode = mode;
        _selectedSchedule = schedule;
        _lastBackupAt = lastBackup;
      });
    }
  }

  Future<void> _handleBackupNow() async {
    if (!AuthService.instance.isAuthenticated) return;
    setState(() => _isBackingUpNow = true);
    try {
      await StoragePreferenceService.setMode(StorageMode.cloud);
      await StoragePreferenceService.setBackupSchedule(_selectedSchedule);
      if (!mounted) return;
      final provider = Provider.of<ExpenseProvider>(context, listen: false);
      final synced = await provider.syncAndReconcileCloud();
      final uid = AuthService.instance.currentUser?.id;
      final updatedTime = uid != null
          ? await StoragePreferenceService.getLastBackupAt(uid)
          : DateTime.now();
      if (mounted) {
        setState(() {
          _lastBackupAt = updatedTime ?? DateTime.now();
          _isBackingUpNow = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              synced > 0
                  ? 'Backup complete ($synced ${synced == 1 ? 'change' : 'changes'} synced)!'
                  : 'Backup up to date!',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isBackingUpNow = false);
      }
    }
  }

  Future<void> _handleConfirm() async {
    setState(() => _isLoading = true);

    if (_selectedMode == StorageMode.cloud && !AuthService.instance.isAuthenticated) {
      await StoragePreferenceService.setMode(StorageMode.local);
      if (mounted) {
        setState(() => _isLoading = false);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cloud storage requires an account. Activated Local offline mode. Sign in to enable Cloud backup!'),
            backgroundColor: Color(0xFFF59E0B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    await StoragePreferenceService.setMode(_selectedMode);
    if (_selectedMode == StorageMode.cloud) {
      await StoragePreferenceService.setBackupSchedule(_selectedSchedule);
    }

    if (mounted) {
      final provider = Provider.of<ExpenseProvider>(context, listen: false);
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      if (_selectedMode == StorageMode.cloud) {
        await provider.syncAndReconcileCloud();
      } else {
        await provider.reloadForStorageMode();
      }
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _selectedMode == StorageMode.cloud
                ? 'Cloud backup activated (${_selectedSchedule.shortLabel})!'
                : 'Device local storage activated!',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.table_chart, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Data Storage Choice',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF131B2E),
                        ),
                      ),
                      Text(
                        'Where should your personal expenses live?',
                        style: TextStyle(fontSize: 12, color: Color(0xFF6D7A72)),
                      ),
                    ],
                  ),
                ),
                if (widget.isDismissible)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            // Option 1: Cloud Storage
            _buildOptionTile(
              mode: StorageMode.cloud,
              title: 'Cloud Storage',
              subtitle: 'Stored locally for speed with automatic cloud backup on your chosen schedule.',
              icon: Icons.cloud_upload_outlined,
              iconColor: AppColors.primary,
              badge: 'RECOMMENDED',
            ),
            if (_selectedMode == StorageMode.cloud) ...[
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Backup Frequency',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF3D4A42),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: CloudBackupSchedule.values.map((sched) {
                        final selected = _selectedSchedule == sched;
                        return ChoiceChip(
                          label: Text(
                            sched.shortLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: selected ? Colors.white : const Color(0xFF3D4A42),
                            ),
                          ),
                          selected: selected,
                          selectedColor: AppColors.primary,
                          backgroundColor: const Color(0xFFF2F4F7),
                          side: BorderSide.none,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _selectedSchedule = sched),
                        );
                      }).toList(),
                    ),
                    if (widget.isDismissible && AuthService.instance.isAuthenticated) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _lastBackupAt != null
                                    ? 'Last backup: ${DateFormat('MMM d, h:mm a').format(_lastBackupAt!)}'
                                    : 'Not backed up yet',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _isBackingUpNow || _isLoading ? null : _handleBackupNow,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              icon: _isBackingUpNow
                                  ? const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                                    )
                                  : const Icon(Icons.sync_rounded, size: 15, color: AppColors.primary),
                              label: const Text(
                                'Back Up Now',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Option 2: Local Storage Only
            _buildOptionTile(
              mode: StorageMode.local,
              title: 'Local Storage',
              subtitle: 'Stored offline on this phone. 100% private, never leaves your device.',
              icon: Icons.phone_android,
              iconColor: const Color(0xFF4B41E1),
              badge: 'OFFLINE',
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F3FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Color(0xFF4B41E1)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Applies to personal expenses only. You can change storage & schedule anytime in Settings.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF3D4A42), fontWeight: FontWeight.w500),
                    ),
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
                onPressed: _isLoading ? null : _handleConfirm,
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text(
                        'Continue',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required StorageMode mode,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required String badge,
  }) {
    final isSelected = _selectedMode == mode;

    return InkWell(
      onTap: () => setState(() => _selectedMode = mode),
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF2F3FF).withValues(alpha: 0.6) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 6,
                    runSpacing: 2,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                          color: const Color(0xFF131B2E),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: iconColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: iconColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF6D7A72), height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Radio<StorageMode>(
              value: mode,
              groupValue: _selectedMode,
              activeColor: AppColors.primary,
              onChanged: (val) {
                if (val != null) setState(() => _selectedMode = val);
              },
            ),
          ],
        ),
      ),
    );
  }
}
