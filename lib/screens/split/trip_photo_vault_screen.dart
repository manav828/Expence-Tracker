import 'package:flutter/material.dart';
import '../../models/split_models.dart';
import 'trip_photo_vault_tab.dart';

/// Dedicated full-page screen for a split group's 48-Hour Ephemeral Photo Vault.
class TripPhotoVaultScreen extends StatelessWidget {
  final SplitGroup group;
  final String currentMemberName;

  const TripPhotoVaultScreen({
    super.key,
    required this.group,
    required this.currentMemberName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF131B2E)),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${group.name} Vault',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 17,
                color: Color(0xFF131B2E),
                letterSpacing: -0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Text(
              '48-Hour Ephemeral Trip Photos',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: const Color(0x0F000000),
            height: 1,
          ),
        ),
      ),
      body: TripPhotoVaultTab(
        group: group,
        currentMemberName: currentMemberName,
      ),
    );
  }
}
