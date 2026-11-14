import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/storage_preference_service.dart';
import '../providers/expense_provider.dart';
import '../widgets/category_payment_manager_sheet.dart';
import '../widgets/storage_choice_dialog.dart';
import '../widgets/sms_tester_sheet.dart';
import '../widgets/set_budget_sheet.dart';
import '../widgets/export_data_sheet.dart';
import '../widgets/legal_sheets.dart';
import '../widgets/user_profile_avatar.dart';
import 'history_screen.dart';
import 'payment_reminders_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8FF),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF131B2E)),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: const Text(
          'Profile & Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Color(0xFF131B2E),
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          // User Profile Header Card
          _buildUserProfileHeader(context),
          const SizedBox(height: 20),

          // Section Title
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'PREFERENCES & DATA',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6D7A72),
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 8),

          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                const _StorageModeTile(),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.security, color: Color(0xFF006948)),
                  title: const Text('Security & Biometrics', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Device screen lock & authentication', style: TextStyle(fontSize: 12, color: Color(0xFF6D7A72))),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showSecurityDialog(context),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.sms_outlined, color: Color(0xFF4B41E1)),
                  title: const Text('SMS Auto-Detection Rules', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Configure or test bank SMS parsing', style: TextStyle(fontSize: 12, color: Color(0xFF6D7A72))),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const SmsTesterSheet(),
                    );
                  },
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.category_outlined, color: Color(0xFF006948)),
                  title: const Text('Categories & Payment Methods', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Manage custom categories & methods', style: TextStyle(fontSize: 12, color: Color(0xFF6D7A72))),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const CategoryPaymentManagerSheet(),
                    );
                  },
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF006948)),
                  title: const Text('Category Budgets & Spending Limits', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Monthly spend caps & alerts', style: TextStyle(fontSize: 12, color: Color(0xFF6D7A72))),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const SetBudgetSheet(),
                    );
                  },
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.alarm_on_rounded, color: Color(0xFF4B41E1)),
                  title: const Text('Payment Reminders & Bills', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Recurring & one-time bill alerts with 1-tap pay', style: TextStyle(fontSize: 12, color: Color(0xFF6D7A72))),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PaymentRemindersScreen()),
                    );
                  },
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.receipt_long_outlined, color: Color(0xFF4B41E1)),
                  title: const Text('Transaction History Ledger', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Detailed audit log of all entries', style: TextStyle(fontSize: 12, color: Color(0xFF6D7A72))),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HistoryScreen()),
                    );
                  },
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.file_download_outlined, color: Color(0xFF4B41E1)),
                  title: const Text('Export Ledger Data', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Download CSV or JSON file', style: TextStyle(fontSize: 12, color: Color(0xFF6D7A72))),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const ExportDataSheet(),
                    );
                  },
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.currency_exchange, color: Color(0xFF008096)),
                  title: const Text('Currency & Formatting', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('INR (₹) - Indian Rupee', style: TextStyle(fontSize: 12, color: Color(0xFF6D7A72))),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showCurrencyDialog(context),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFBA1A1A)),
                  title: const Text('Clear All Expenses', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFBA1A1A))),
                  subtitle: const Text('Delete all local records permanently', style: TextStyle(fontSize: 12, color: Color(0xFFBA1A1A))),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: Colors.white,
                        title: const Text('Clear All Expenses?'),
                        content: const Text('This will permanently delete all recorded transactions from the ledger. This action cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Clear All', style: TextStyle(color: Color(0xFFBA1A1A))),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && context.mounted) {
                      final messenger = ScaffoldMessenger.of(context);
                      await Provider.of<ExpenseProvider>(context, listen: false).clearAll();
                      messenger.showSnackBar(
                        const SnackBar(content: Text('All expenses cleared')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Legal & About Section
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'LEGAL & ACCOUNT',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6D7A72),
                letterSpacing: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 8),

          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined, color: Color(0xFF006948)),
                  title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => LegalSheets.showPrivacyPolicy(context),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.description_outlined, color: Color(0xFF4B41E1)),
                  title: const Text('Terms of Service', style: TextStyle(fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => LegalSheets.showTermsOfService(context),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Color(0xFFF43F5E)),
                  title: Text(
                    AuthService.instance.isAuthenticated
                        ? 'Sign Out (${AuthService.instance.currentUser?.email ?? "Account"})'
                        : 'Sign In / Exit Guest Mode',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFF43F5E)),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Color(0xFFF43F5E)),
                  onTap: () async {
                    await AuthService.instance.signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                Image.asset('screen/logos/logo.png', width: 42, height: 42),
                const SizedBox(height: 8),
                const Text(
                  'ExpenCircle',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: Color(0xFF131B2E),
                  ),
                ),
                const Text(
                  'Smart Expenses for a Brighter You',
                  style: TextStyle(fontSize: 11, color: Color(0xFF6D7A72)),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Version 1.0.2',
                  style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserProfileHeader(BuildContext context) {
    final auth = AuthService.instance;
    final isGuest = !auth.isAuthenticated;
    final isGoogle = auth.isGoogleUser;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const UserProfileAvatar(
                size: 60,
                showBorder: true,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ValueListenableBuilder<String>(
                      valueListenable: auth.userNameNotifier,
                      builder: (context, currentName, _) {
                        return Row(
                          children: [
                            Expanded(
                              child: Text(
                                currentName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF131B2E),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF006948)),
                              onPressed: () => _showEditNameDialog(context),
                              tooltip: 'Edit Display Name',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 2),
                    Text(
                      auth.userEmail,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF6D7A72),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isGoogle
                            ? const Color(0xFFEA4335).withValues(alpha: 0.08)
                            : (auth.isAuthenticated
                                ? const Color(0xFF006948).withValues(alpha: 0.08)
                                : const Color(0xFFD97706).withValues(alpha: 0.1)),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isGoogle
                              ? const Color(0xFFEA4335).withValues(alpha: 0.25)
                              : (auth.isAuthenticated
                                  ? const Color(0xFF006948).withValues(alpha: 0.2)
                                  : const Color(0xFFD97706).withValues(alpha: 0.3)),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isGoogle
                                ? Icons.g_mobiledata_rounded
                                : (auth.isAuthenticated
                                    ? Icons.verified_user_rounded
                                    : Icons.cloud_off_rounded),
                            size: isGoogle ? 18 : 13,
                            color: isGoogle
                                ? const Color(0xFFEA4335)
                                : (auth.isAuthenticated
                                    ? const Color(0xFF006948)
                                    : const Color(0xFFD97706)),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isGoogle
                                ? 'Google Account'
                                : (auth.isAuthenticated
                                    ? 'Email Verified'
                                    : 'Guest (Offline Mode)'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isGoogle
                                  ? const Color(0xFFC5221F)
                                  : (auth.isAuthenticated
                                      ? const Color(0xFF006948)
                                      : const Color(0xFFB45309)),
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
          if (isGuest) ...[
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF006948),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.login_rounded, size: 18),
                label: const Text(
                  'Sign In / Create Account for Cloud Backup',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showEditNameDialog(BuildContext context) {
    final auth = AuthService.instance;
    final currentName = auth.userDisplayName == 'Guest User' ? '' : auth.userDisplayName;
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Personalize Your Name',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF131B2E)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your name so ExpenCircle greets you properly on your dashboard.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6D7A72)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                hintText: 'e.g. Manav',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF006948), width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF6D7A72))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF006948),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                await auth.updateDisplayName(newName);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save Name'),
          ),
        ],
      ),
    );
  }

  void _showSecurityDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Security & Biometrics'),
        content: const Text(
          'ExpenCircle is protected by your system security lock (Fingerprint / Face ID / Screen Lock PIN). '
          'Your data is stored securely in your private, encrypted app storage.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showCurrencyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Currency & Formatting'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<String>(
              value: 'INR',
              groupValue: 'INR',
              title: const Text('₹ INR (Indian Rupee)'),
              subtitle: const Text('Default formatting: ₹ 1,234.00'),
              onChanged: (_) => Navigator.pop(ctx),
            ),
            RadioListTile<String>(
              value: 'USD',
              groupValue: 'INR',
              title: const Text('\$ USD (US Dollar)'),
              onChanged: null,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _StorageModeTile extends StatefulWidget {
  const _StorageModeTile();
  @override
  State<_StorageModeTile> createState() => _StorageModeTileState();
}

class _StorageModeTileState extends State<_StorageModeTile> {
  StorageMode _mode = StorageMode.local;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await StoragePreferenceService.getMode();
    if (mounted) {
      setState(() {
        _mode = m;
        _loading = false;
      });
    }
  }

  void _showStorageDialog(BuildContext context) async {
    await StorageChoiceDialog.showForChange(context);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final isCloud = _mode == StorageMode.cloud;
    return ListTile(
      leading: Icon(
        isCloud ? Icons.cloud_done_outlined : Icons.sd_storage_outlined,
        color: isCloud ? const Color(0xFF006948) : const Color(0xFF4B41E1),
      ),
      title: const Text('Personal Expense Storage', style: TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        _loading
            ? 'Loading...'
            : (isCloud ? 'Cloud Sync & Backup (Connected)' : 'Device Local Storage (Offline Mode)'),
        style: TextStyle(
          fontSize: 12,
          color: isCloud ? const Color(0xFF006948) : const Color(0xFF6D7A72),
          fontWeight: isCloud ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showStorageDialog(context),
    );
  }
}
