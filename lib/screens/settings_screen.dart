import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/app_permission_service.dart';
import '../services/cloudflare_r2_service.dart';
import '../services/file_picker_stub.dart';
import '../services/storage_preference_service.dart';
import '../providers/expense_provider.dart';
import '../widgets/category_payment_manager_sheet.dart';
import '../widgets/storage_choice_dialog.dart';
import '../widgets/export_data_sheet.dart';
import '../widgets/legal_sheets.dart';
import '../widgets/user_profile_avatar.dart';
import 'payment_reminders_screen.dart';
import '../core/theme/app_colors.dart';


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
                  leading: const Icon(Icons.category_outlined, color: AppColors.primary),
                  title: const Text('Categories & Payment Methods', style: TextStyle(fontWeight: FontWeight.w600)),
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
                  leading: const Icon(Icons.alarm_on_rounded, color: Color(0xFF4B41E1)),
                  title: const Text('Payment Reminders & Bills', style: TextStyle(fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const PaymentRemindersScreen()),
                    );
                  },
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.file_download_outlined, color: Color(0xFF4B41E1)),
                  title: const Text('Export Ledger Data', style: TextStyle(fontWeight: FontWeight.w600)),
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
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _showCurrencyDialog(context),
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.delete_sweep_outlined, color: Color(0xFFBA1A1A)),
                  title: const Text('Clear All Expenses', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFBA1A1A))),
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
                  leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.primary),
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
                        ? 'Sign Out'
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
              UserProfileAvatar(
                size: 58,
                showBorder: true,
                onTap: () => _showEditProfileDialog(context),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ValueListenableBuilder<String>(
                      valueListenable: auth.userNameNotifier,
                      builder: (context, currentName, _) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                currentName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  height: 1.15,
                                  color: Color(0xFF131B2E),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Tooltip(
                              message: 'Edit Profile',
                              child: InkWell(
                                onTap: () => _showEditProfileDialog(context),
                                borderRadius: BorderRadius.circular(8),
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(
                                    Icons.edit_outlined,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
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
                        height: 1.2,
                        color: Color(0xFF6D7A72),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  iconColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.login, size: 18, color: Colors.white),
                label: const Text(
                  'Sign In / Create Account for Cloud Backup',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    final auth = AuthService.instance;
    final currentName = auth.userDisplayName == 'Guest User' ? '' : auth.userDisplayName;
    final controller = TextEditingController(text: currentName);
    PickedFileData? pickedPhoto;
    bool removeExistingPhoto = false;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (innerCtx, setDialogState) {
          Future<void> handlePickPhoto(BuildContext pickerCtx, {required bool useCamera}) async {
            if (!pickerCtx.mounted) return;
            final bool granted;
            if (useCamera) {
              granted = await AppPermissionService.requestCameraPermission(
                pickerCtx,
                reason: 'take a profile photo',
              );
            } else {
              granted = await AppPermissionService.requestPhotosPermission(
                pickerCtx,
                reason: 'select a profile photo from your gallery',
              );
            }
            if (!granted || !pickerCtx.mounted) return;

            final file = await pickImageFile(
              useCamera: useCamera,
              maxWidth: 512,
              maxHeight: 512,
              imageQuality: 85,
            );
            if (file != null && pickerCtx.mounted) {
              setDialogState(() {
                pickedPhoto = file;
                removeExistingPhoto = false;
              });
            }
          }

          Widget buildAvatarPreview() {
            if (pickedPhoto != null) {
              return ClipOval(
                child: Image.memory(
                  pickedPhoto!.bytes,
                  width: 78,
                  height: 78,
                  fit: BoxFit.cover,
                ),
              );
            }
            if (removeExistingPhoto || auth.userAvatarUrl == null || auth.userAvatarUrl!.isEmpty) {
              return Container(
                width: 78,
                height: 78,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  auth.userInitial,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 32,
                  ),
                ),
              );
            }
            return const UserProfileAvatar(size: 78, showBorder: false);
          }

          final hasAnyPhoto = pickedPhoto != null ||
              (!removeExistingPhoto && auth.userAvatarUrl != null && auth.userAvatarUrl!.isNotEmpty);

          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text(
              'Edit Profile',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF131B2E)),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.primaryBorder, width: 2),
                        ),
                        child: buildAvatarPreview(),
                      ),
                      InkWell(
                        onTap: isSaving ? null : () => handlePickPhoto(innerCtx, useCamera: false),
                        customBorder: const CircleBorder(),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt_outlined, size: 15, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: isSaving ? null : () => handlePickPhoto(innerCtx, useCamera: false),
                        icon: const Icon(Icons.photo_library_outlined, size: 16, color: AppColors.primary),
                        label: const Text(
                          'Gallery',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: isSaving ? null : () => handlePickPhoto(innerCtx, useCamera: true),
                        icon: const Icon(Icons.camera_alt_outlined, size: 16, color: AppColors.primary),
                        label: const Text(
                          'Camera',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                        ),
                      ),
                      if (hasAnyPhoto)
                        TextButton.icon(
                          onPressed: isSaving
                              ? null
                              : () => setDialogState(() {
                                    pickedPhoto = null;
                                    removeExistingPhoto = true;
                                  }),
                          icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFBA1A1A)),
                          label: const Text(
                            'Remove',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFBA1A1A)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Display Name',
                      hintText: 'e.g. Manav',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                child: const Text('Cancel', style: TextStyle(color: Color(0xFF6D7A72))),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isSaving
                    ? null
                    : () async {
                        setDialogState(() => isSaving = true);
                        final newName = controller.text.trim();
                        if (newName.isNotEmpty) {
                          await auth.updateDisplayName(newName);
                        }
                        if (removeExistingPhoto) {
                          await auth.updateProfilePhoto(null);
                        } else if (pickedPhoto != null) {
                          final uploadedUrl = await CloudflareR2Service.instance.uploadImage(
                            bytes: pickedPhoto!.bytes,
                            folder: 'avatars',
                            extension: pickedPhoto!.extension,
                          );
                          if (uploadedUrl != null) {
                            await auth.updateProfilePhoto(uploadedUrl);
                          } else {
                            final ext = pickedPhoto!.extension.toLowerCase();
                            final mime = ext == 'png'
                                ? 'image/png'
                                : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
                            final dataUri = 'data:$mime;base64,${base64Encode(pickedPhoto!.bytes)}';
                            await auth.updateProfilePhoto(dataUri);
                          }
                        }
                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                      },
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        },
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
        color: isCloud ? AppColors.primary : const Color(0xFF4B41E1),
      ),
      title: const Text('Personal Expense Storage', style: TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showStorageDialog(context),
    );
  }
}
