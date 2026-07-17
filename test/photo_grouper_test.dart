import 'package:ds_video_player/features/photos/domain/photo_grouper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Fixed reference instant for deterministic bucketing.
  final now = DateTime(2026, 3, 15, 10, 30);
  int at(DateTime d) => d.millisecondsSinceEpoch;
  const grouper = PhotoGrouper();

  // The grouper is generic; tests use the timestamp itself as the item.
  // Renamed from `group` → `bucketize`: `group` clashes with flutter_test's
  // `group(description, body)` and shadowed it, making test-group calls
  // fail to compile ("String can't be assigned to List<int>").
  List<PhotoSection<int>> bucketize(List<int> ts) =>
      grouper.group<int>(ts, (t) => t, now: now);

  group('PhotoGrouper.group', () {
    test('empty input yields no sections', () {
      expect(bucketize([]), isEmpty);
    });

    test('today photos land in a single "Today" section', () {
      final out = bucketize([
        at(DateTime(2026, 3, 15, 9)),
        at(DateTime(2026, 3, 15, 1)),
      ]);
      expect(out, hasLength(1));
      expect(out.first.label, 'Today');
      expect(out.first.items, hasLength(2));
    });

    test('classifies Yesterday and This week', () {
      final out = bucketize([
        at(DateTime(2026, 3, 15, 8)), // today
        at(DateTime(2026, 3, 14, 8)), // yesterday
        at(DateTime(2026, 3, 11, 8)), // 4 days ago -> this week
      ]);
      expect(out.map((s) => s.label),
          ['Today', 'Yesterday', 'This week']);
    });

    test('older same-month photos are "Earlier this month"', () {
      final out = bucketize([
        at(DateTime(2026, 3, 2, 8)), // 13 days ago, same month
      ]);
      expect(out.single.label, 'Earlier this month');
    });

    test('previous months get a "Month Year" label', () {
      final out = bucketize([
        at(DateTime(2025, 11, 20, 8)),
        at(DateTime(2024, 1, 5, 8)),
      ]);
      final labels = out.map((s) => s.label).toList();
      expect(labels, contains('November 2025'));
      expect(labels, contains('January 2024'));
    });

    test('sections are ordered newest first', () {
      final out = bucketize([
        at(DateTime(2025, 11, 20, 8)), // November 2025
        at(DateTime(2026, 3, 15, 8)), // Today
        at(DateTime(2026, 3, 14, 8)), // Yesterday
      ]);
      expect(out.map((s) => s.label),
          ['Today', 'Yesterday', 'November 2025']);
    });

    test('items within a section are newest first', () {
      final early = at(DateTime(2026, 3, 15, 1));
      final late = at(DateTime(2026, 3, 15, 9));
      final out = bucketize([early, late]);
      expect(out.single.items, [late, early]);
    });

    test('future timestamps fold into Today', () {
      final out = bucketize([at(DateTime(2026, 3, 20, 8))]); // 5 days ahead
      expect(out.single.label, 'Today');
    });

    test('total items across sections equals the input count', () {
      final input = [
        at(DateTime(2026, 3, 15, 8)),
        at(DateTime(2026, 3, 14, 8)),
        at(DateTime(2026, 2, 1, 8)),
        at(DateTime(2025, 12, 25, 8)),
      ];
      final out = bucketize(input);
      final total = out.fold<int>(0, (s, sec) => s + sec.items.length);
      expect(total, input.length);
    });
  });
}
