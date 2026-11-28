import 'package:expense_tracker/models/split_models.dart';
import 'package:expense_tracker/providers/trip_photo_provider.dart';
import 'package:expense_tracker/screens/split/trip_photo_vault_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Photo Vault shows artwork only in the empty All view', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => TripPhotoProvider(),
        child: MaterialApp(
          home: Scaffold(
            body: TripPhotoVaultTab(
              group: SplitGroup(
                id: 'empty-vault',
                name: 'QA trip',
                createdBy: 'test-member',
                inviteCode: 'TEST',
                createdAt: DateTime(2026),
              ),
              currentMemberName: 'QA Guest',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final artwork = find.image(
      const AssetImage('assets/illustrations/empty-photo-vault.webp'),
    );
    expect(artwork, findsOneWidget);
    expect(find.text('Upload Photos'), findsOneWidget);
    expect(find.text('Photos are available for 48 hours after upload.'), findsOneWidget);

    await tester.tap(find.textContaining('Liked (0)'));
    await tester.pumpAndSettle();
    expect(find.text('No liked photos yet'), findsOneWidget);
    expect(artwork, findsNothing);
  });
}
