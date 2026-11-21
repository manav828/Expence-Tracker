import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/theme/app_colors.dart';


/// Centralized service to manage user permissions with:
/// 1. In-app rationale disclosures (App Store & Play Store compliant).
/// 2. Graceful permanently-denied resolution via device Settings.
/// 3. Web and multi-platform safety.
class AppPermissionService {
  AppPermissionService._();

  static const Color _primaryColor = AppColors.primary;
  static const Color _textColor = Color(0xFF1E293B);
  static const Color _subtextColor = Color(0xFF64748B);

  /// Requests Photo/Gallery access with an in-app rationale modal.
  /// Complies with Apple App Store Guideline 5.1.1 and Google Play Photo & Video policy.
  static Future<bool> requestPhotosPermission(
    BuildContext context, {
    String reason = 'select receipts and upload trip memories',
  }) async {
    if (kIsWeb) return true;

    try {
      // Check current photo status (iOS & Android 13+)
      PermissionStatus status = await Permission.photos.status;

      // On Android <= 12, photos permission may be reported as denied/unsupported while storage is used
      if (!status.isGranted && !status.isLimited) {
        final storageStatus = await Permission.storage.status;
        if (storageStatus.isGranted) return true;
      }

      if (status.isGranted || status.isLimited) {
        return true;
      }

      // If permanently denied, prompt user to go to Settings
      if (status.isPermanentlyDenied) {
        if (!context.mounted) return false;
        return await _showPermanentlyDeniedDialog(
          context,
          title: 'Photo Access Required',
          description:
              'ExpenCircle needs access to your photos to $reason. '
              'Please enable Photos permission in your device Settings.',
        );
      }

      // Show in-app prominent disclosure / rationale before triggering OS prompt
      if (!context.mounted) return false;
      final shouldProceed = await _showRationaleSheet(
        context,
        icon: Icons.photo_library_outlined,
        title: 'Access Your Photos',
        headline: 'Select photos safely from your gallery',
        points: [
          'Used only to $reason.',
          'Your photos remain private and are only uploaded when you choose.',
          'ExpenCircle never accesses photos you do not select.',
        ],
        actionText: 'Allow Photos Access',
      );

      if (!shouldProceed) return false;

      // Trigger native OS permission
      status = await Permission.photos.request();

      // Fallback for Android 12 and below
      if (!status.isGranted && !status.isLimited) {
        final storageRes = await Permission.storage.request();
        if (storageRes.isGranted) return true;
      }

      if (status.isGranted || status.isLimited) {
        return true;
      }

      if (status.isPermanentlyDenied) {
        if (!context.mounted) return false;
        return await _showPermanentlyDeniedDialog(
          context,
          title: 'Photo Access Required',
          description:
              'Photo access was declined. You can enable it anytime in device Settings to select photos.',
        );
      }

      return false;
    } catch (e) {
      debugPrint('[AppPermissionService] Photos permission error: $e');
      return true; // Fallback to allowing picker to attempt native handling
    }
  }

  /// Requests Camera access with an in-app rationale modal.
  static Future<bool> requestCameraPermission(
    BuildContext context, {
    String reason = 'capture expense receipts or group photos',
  }) async {
    if (kIsWeb) return true;

    try {
      PermissionStatus status = await Permission.camera.status;

      if (status.isGranted) return true;

      if (status.isPermanentlyDenied) {
        if (!context.mounted) return false;
        return await _showPermanentlyDeniedDialog(
          context,
          title: 'Camera Access Required',
          description:
              'ExpenCircle needs camera access to $reason. '
              'Please enable Camera permission in your device Settings.',
        );
      }

      // In-app rationale
      if (!context.mounted) return false;
      final shouldProceed = await _showRationaleSheet(
        context,
        icon: Icons.camera_alt_outlined,
        title: 'Camera Access',
        headline: 'Take photos directly in the app',
        points: [
          'Used to $reason.',
          'The camera is only activated when you tap to take a photo.',
          'Photos are stored only where you decide.',
        ],
        actionText: 'Allow Camera Access',
      );

      if (!shouldProceed) return false;

      status = await Permission.camera.request();

      if (status.isGranted) return true;

      if (status.isPermanentlyDenied) {
        if (!context.mounted) return false;
        return await _showPermanentlyDeniedDialog(
          context,
          title: 'Camera Access Required',
          description:
              'Camera access was declined. You can enable it anytime in device Settings to take photos.',
        );
      }

      return false;
    } catch (e) {
      debugPrint('[AppPermissionService] Camera permission error: $e');
      return true;
    }
  }

  /// Requests SMS reading permissions with Google Play Store Compliant Prominent In-App Disclosure.
  /// Never call blindly on app startup. Must only be triggered upon user intent.
  static Future<bool> requestSmsPermissionWithDisclosure(
    BuildContext context,
  ) async {
    if (kIsWeb) return false;

    try {
      PermissionStatus status = await Permission.sms.status;
      if (status.isGranted) return true;

      if (status.isPermanentlyDenied) {
        if (!context.mounted) return false;
        return await _showPermanentlyDeniedDialog(
          context,
          title: 'SMS Permission Required',
          description:
              'To automatically track your bank transactions, SMS permission is required. '
              'Please enable SMS permission in device Settings.',
        );
      }

      if (!context.mounted) return false;

      // Google Play Store Mandatory Prominent Disclosure
      final shouldProceed = await _showRationaleSheet(
        context,
        icon: Icons.sms_outlined,
        title: 'Bank SMS Auto-Detection',
        headline: 'Google Play Certified On-Device Financial Parsing',
        points: [
          '100% On-Device: Your SMS messages are analyzed exclusively on your phone. Raw SMS text is NEVER sent to any server.',
          'Bank Alerts Only: Reads official bank transaction debits & credits (e.g., HDFC, SBI, ICICI) to log expenses automatically.',
          'Privacy Guaranteed: Personal chats, OTPs, passwords, and promotional texts are strictly ignored and discarded.',
        ],
        actionText: 'Enable Bank SMS Detection',
        cancelText: 'Not Now',
      );

      if (!shouldProceed) return false;

      status = await Permission.sms.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('[AppPermissionService] SMS permission error: $e');
      return false;
    }
  }

  /// Requests Notification permission (Android 13+ & iOS).
  static Future<bool> requestNotificationPermission(
    BuildContext context, {
    String reason = 'receive bill payment reminders and group split alerts',
  }) async {
    if (kIsWeb) return true;

    try {
      PermissionStatus status = await Permission.notification.status;
      if (status.isGranted) return true;

      if (status.isPermanentlyDenied) {
        if (!context.mounted) return false;
        return await _showPermanentlyDeniedDialog(
          context,
          title: 'Notifications Disabled',
          description:
              'Please enable notifications in Settings to $reason.',
        );
      }

      if (!context.mounted) return false;
      final shouldProceed = await _showRationaleSheet(
        context,
        icon: Icons.notifications_none_rounded,
        title: 'Turn on Notifications',
        headline: 'Never miss important expense updates',
        points: [
          'Alerts for bill payment due dates and recurring expenses.',
          'Instant notifications when friends settle up in split groups.',
          'You can customize or mute alerts at any time.',
        ],
        actionText: 'Enable Notifications',
        cancelText: 'Maybe Later',
      );

      if (!shouldProceed) return false;

      status = await Permission.notification.request();
      return status.isGranted;
    } catch (e) {
      debugPrint('[AppPermissionService] Notification permission error: $e');
      return false;
    }
  }

  /// Displays an educational, branded in-app rationale modal sheet.
  static Future<bool> _showRationaleSheet(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String headline,
    required List<String> points,
    required String actionText,
    String cancelText = 'Cancel',
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 14,
            bottom: MediaQuery.of(ctx).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
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
              const SizedBox(height: 20),

              // Icon & Title
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: _primaryColor, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          headline,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _subtextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Points
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: points.map((p) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: _primaryColor,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              p,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                color: Color(0xFF334155),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 22),

              // Actions
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(
                    actionText,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(
                    cancelText,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _subtextColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    return result ?? false;
  }

  /// Informs the user that a permission is permanently denied and offers a shortcut to open App Settings.
  static Future<bool> _showPermanentlyDeniedDialog(
    BuildContext context, {
    required String title,
    required String description,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.settings_suggest_rounded,
                color: _primaryColor,
                size: 26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _textColor,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Color(0xFF475569),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: _subtextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              onPressed: () async {
                Navigator.of(ctx).pop(true);
                await openAppSettings();
              },
              child: const Text(
                'Open Settings',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }
}
