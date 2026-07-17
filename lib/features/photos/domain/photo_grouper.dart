/// One date-grouped run of photos.
class PhotoSection<T> {
  const PhotoSection({required this.label, required this.items});

  final String label;

  /// Items in the section, newest first.
  final List<T> items;
}

/// Pure date-bucketing for the photo gallery. Generic over the item type
/// (the caller supplies a timestamp accessor) so it is trivially testable
/// with plain values and never depends on `photo_manager`.
///
/// Buckets, newest first:
///   Today · Yesterday · This week · Earlier this month · "Month Year".
class PhotoGrouper {
  const PhotoGrouper();

  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  List<PhotoSection<T>> group<T>(
    List<T> items,
    int Function(T item) epochMsOf, {
    DateTime? now,
  }) {
    if (items.isEmpty) return const [];

    final ref = now ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);

    final buckets = <String, List<_Entry<T>>>{};
    for (final item in items) {
      final ts = epochMsOf(item);
      final label = _labelFor(ts, today, ref);
      buckets.putIfAbsent(label, () => []).add(_Entry(item, ts));
    }

    final sections = <_RankedSection<T>>[];
    for (final entry in buckets.entries) {
      final ranked = entry.value..sort((a, b) => b.ts.compareTo(a.ts));
      sections.add(
        _RankedSection(
          mostRecent: ranked.first.ts,
          section: PhotoSection(
            label: entry.key,
            items: ranked.map((e) => e.item).toList(growable: false),
          ),
        ),
      );
    }

    // Newest section first — ranked by each bucket's most-recent item.
    sections.sort((a, b) => b.mostRecent.compareTo(a.mostRecent));
    return sections.map((r) => r.section).toList(growable: false);
  }

  String _labelFor(int epochMs, DateTime today, DateTime ref) {
    final dt = DateTime.fromMillisecondsSinceEpoch(epochMs);
    final day = DateTime(dt.year, dt.month, dt.day);
    var daysAgo = today.difference(day).inDays;
    if (daysAgo < 0) daysAgo = 0; // future timestamps fold into Today

    if (daysAgo == 0) return 'Today';
    if (daysAgo == 1) return 'Yesterday';
    if (daysAgo <= 6) return 'This week';
    if (dt.year == ref.year && dt.month == ref.month) {
      return 'Earlier this month';
    }
    return '${_months[dt.month - 1]} ${dt.year}';
  }
}

class _Entry<T> {
  _Entry(this.item, this.ts);
  final T item;
  final int ts;
}

class _RankedSection<T> {
  _RankedSection({required this.mostRecent, required this.section});
  final int mostRecent;
  final PhotoSection<T> section;
}
