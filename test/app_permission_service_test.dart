import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/services/app_permission_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppPermissionService Tests', () {
    testWidgets('AppPermissionService can be invoked in widget context', (tester) async {
      late BuildContext testContext;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) {
              testContext = ctx;
              return const Scaffold(body: Text('Permission Test'));
            },
          ),
        ),
      );

      expect(find.text('Permission Test'), findsOneWidget);
      expect(testContext, isNotNull);

      // Verify static methods can be called safely
      expect(AppPermissionService.requestPhotosPermission, isNotNull);
      expect(AppPermissionService.requestCameraPermission, isNotNull);
      expect(AppPermissionService.requestSmsPermissionWithDisclosure, isNotNull);
      expect(AppPermissionService.requestNotificationPermission, isNotNull);
    });
  });
}
