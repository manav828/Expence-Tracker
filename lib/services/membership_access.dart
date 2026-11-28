import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

/// The owner enables the web pilot after configuring and testing checkout.
class MembershipAccess {
  static Future<bool> allowPlus(BuildContext context) async {
    if (!kIsWeb) return true;
    try {
      final result = await Supabase.instance.client.rpc('membership_access');
      if (result['enabled'] != true || result['plan'] == 'Plus') return true;
      if (!context.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('This feature is included with ExpenCircle Plus.'),
        action: SnackBarAction(label: 'View plans', onPressed: open),
      ));
      return false;
    } catch (_) {
      // Local-first ledger screens remain usable offline and during migration.
      return true;
    }
  }

  static Future<void> open() async {
    await launchUrl(Uri.base.resolve('/console/index.html?view=membership'));
  }
}
