import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/screens/split/widgets/slide_to_pay_track.dart';
import 'package:expense_tracker/services/split_service.dart';

void main() {
  group('SlideToPayTrack & Self-Settlement Prevention Tests', () {
    testWidgets('SlideToPayTrack renders centered placeholder text and speed chevrons', (tester) async {
      bool paid = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 350,
                child: SlideToPayTrack(
                  amount: 353.0,
                  label: 'Slide to Mark as Paid',
                  onPayCompleted: () async {
                    paid = true;
                  },
                ),
              ),
            ),
          ),
        ),
      );

      // Verify centered prompt text is found
      expect(find.text('Slide to Mark as Paid • ₹353'), findsOneWidget);
      // Verify speed chevron icons are rendered
      expect(find.byIcon(Icons.chevron_right_rounded), findsNWidgets(3));
      // Verify circular knob arrow icon is present
      expect(find.byIcon(Icons.arrow_forward_rounded), findsOneWidget);

      // Verify the track SizedBox has width: double.infinity
      final trackSizedBox = find.descendant(
        of: find.byType(SlideToPayTrack),
        matching: find.byType(SizedBox),
      ).first;
      final SizedBox sizedBox = tester.widget(trackSizedBox);
      expect(sizedBox.width, double.infinity);
      expect(sizedBox.height, 54.0);

      // Pump 500ms to verify speed animation loops without crashing
      await tester.pump(const Duration(milliseconds: 500));
      expect(paid, isFalse);
    });

    test('SplitService.recordSettlement rejects self-settlement when fromMemberId == toMemberId', () async {
      expect(
        () => SplitService.instance.recordSettlement(
          groupId: 'test-group',
          fromMemberId: 'member-manav',
          toMemberId: 'member-manav',
          amount: 344.50,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
