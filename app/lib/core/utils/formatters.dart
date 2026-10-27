import 'package:intl/intl.dart';
import 'package:parkspot/core/utils/money.dart';

/// Every user-visible number and date in one place.
abstract final class Formatters {
  // Indian grouping: 1,23,456.
  static final _grouping = NumberFormat.decimalPattern('en_IN');
  static final _time = DateFormat('h:mm a');
  static final _clock = DateFormat('h:mm');
  static final _day = DateFormat('EEE d MMM');

  /// 4000 → ₹40, 4050 → ₹40.50, 12345678 → ₹1,23,456.78.
  ///
  /// Built from integer rupees and paise, so no double ever touches money.
  static String money(Money m) {
    final rupees = _grouping.format(m.paise ~/ 100);
    final paise = m.paise % 100;
    if (paise == 0) return '₹$rupees';
    return '₹$rupees.${paise.toString().padLeft(2, '0')}';
  }

  /// 412 → "412 m", 1530 → "1.5 km".
  static String distance(int meters) {
    if (meters < 1000) return '$meters m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  /// 30 min → "30m", 2 h → "2h", 2 h 30 min → "2h 30m".
  static String duration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  /// Active-booking countdown: "1:42:05", or "42:05" under an hour.
  /// Negative durations clamp to "00:00".
  static String countdown(Duration d) {
    if (d.isNegative) return '00:00';
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = two(d.inMinutes.remainder(60));
    final s = two(d.inSeconds.remainder(60));
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  /// "Today, 6:30 PM", "Tomorrow, 9:00 AM", otherwise "Thu 23 Oct, 9:00 AM".
  ///
  /// API timestamps are UTC; this converts to local time. Pass [now] in tests.
  static String slotTime(DateTime instant, {DateTime? now}) {
    final local = instant.toLocal();
    final today = _dateOnly((now ?? DateTime.now()).toLocal());
    final days = _dateOnly(local).difference(today).inDays;
    final day = switch (days) {
      0 => 'Today',
      1 => 'Tomorrow',
      _ => _day.format(local),
    };
    return '$day, ${_time.format(local)}';
  }

  /// "6:30 PM", local time.
  static String time(DateTime instant) => _time.format(instant.toLocal());

  /// "6:30 to 8:30 PM", or "11:30 AM to 1:30 PM" across noon.
  static String timeRange(DateTime start, DateTime end) {
    final from = start.toLocal();
    final to = end.toLocal();
    final sameHalf = (from.hour < 12) == (to.hour < 12);
    return '${sameHalf ? _clock.format(from) : _time.format(from)} to '
        '${_time.format(to)}';
  }

  /// "Today, 6:30 to 8:30 PM". Pass [now] in tests.
  static String slotWindow(DateTime start, DateTime end, {DateTime? now}) {
    final day = slotTime(start, now: now).split(',').first;
    return '$day, ${timeRange(start, end)}';
  }

  // Calendar-day maths in UTC so a DST shift can't turn one day into 0.96.
  static DateTime _dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);
}
