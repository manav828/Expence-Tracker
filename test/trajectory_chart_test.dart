import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

void main() {
  group('Spend Escalation Trajectory Algorithm Tests', () {
    test('Milestone index selection picks at most 4 evenly spaced non-colliding labels', () {
      for (final count in [1, 2, 5, 20, 60, 160, 365]) {
        final List<int> milestoneIndices = [];
        if (count <= 4) {
          milestoneIndices.addAll(List.generate(count, (i) => i));
        } else {
          const int labelCount = 4;
          for (int i = 0; i < labelCount; i++) {
            final idx = ((count - 1) * i / (labelCount - 1)).round();
            if (!milestoneIndices.contains(idx)) {
              milestoneIndices.add(idx);
            }
          }
        }

        expect(milestoneIndices.length, lessThanOrEqualTo(4));
        expect(milestoneIndices.first, 0);
        expect(milestoneIndices.last, count - 1);
        // Verify strictly ascending (no duplicates or overlaps)
        for (int i = 1; i < milestoneIndices.length; i++) {
          expect(milestoneIndices[i], greaterThan(milestoneIndices[i - 1]));
        }
      }
    });

    test('Date formatting for milestone labels does not overlap', () {
      final now = DateTime(2026, 10, 24);
      final days = List.generate(60, (i) => now.subtract(Duration(days: 59 - i)));

      const labelCount = 4;
      final labels = <String>[];
      for (int i = 0; i < labelCount; i++) {
        final idx = ((days.length - 1) * i / (labelCount - 1)).round();
        final d = days[idx];
        final label = idx == days.length - 1 ? 'Today' : DateFormat('d MMM').format(d);
        labels.add(label);
      }

      expect(labels.length, 4);
      expect(labels.last, 'Today');
      // Verify labels are distinct
      expect(labels.toSet().length, 4);
    });
  });
}
