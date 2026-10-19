import 'package:flutter_test/flutter_test.dart';
import 'package:parkspot/core/utils/formatters.dart';
import 'package:parkspot/core/utils/money.dart';

void main() {
  group('money', () {
    test('drops paise when they are zero', () {
      expect(Formatters.money(Money.zero), '₹0');
      expect(Formatters.money(const Money(100)), '₹1');
      expect(Formatters.money(const Money(4000)), '₹40');
    });

    test('keeps two-digit paise', () {
      expect(Formatters.money(const Money(4050)), '₹40.50');
      expect(Formatters.money(const Money(4005)), '₹40.05');
    });

    test('uses Indian digit grouping', () {
      expect(Formatters.money(const Money(12345678)), '₹1,23,456.78');
      expect(Formatters.money(const Money(1000000000)), '₹1,00,00,000');
    });
  });

  group('distance', () {
    test('metres below 1 km, one decimal above', () {
      expect(Formatters.distance(0), '0 m');
      expect(Formatters.distance(999), '999 m');
      expect(Formatters.distance(1000), '1.0 km');
      expect(Formatters.distance(1530), '1.5 km');
    });
  });

  group('duration', () {
    test('formats hours and minutes', () {
      expect(Formatters.duration(Duration.zero), '0m');
      expect(Formatters.duration(const Duration(minutes: 30)), '30m');
      expect(Formatters.duration(const Duration(hours: 2)), '2h');
      expect(Formatters.duration(const Duration(minutes: 150)), '2h 30m');
    });
  });

  group('countdown', () {
    test('mm:ss under an hour, h:mm:ss above', () {
      expect(
        Formatters.countdown(const Duration(minutes: 42, seconds: 5)),
        '42:05',
      );
      expect(
        Formatters.countdown(const Duration(hours: 1, minutes: 42, seconds: 5)),
        '1:42:05',
      );
      expect(Formatters.countdown(const Duration(hours: 11)), '11:00:00');
    });

    test('clamps negative time to zero', () {
      expect(Formatters.countdown(const Duration(seconds: -3)), '00:00');
    });
  });

  group('slotTime', () {
    final now = DateTime(2026, 10, 19, 14);

    test('today and tomorrow by name', () {
      expect(
        Formatters.slotTime(DateTime(2026, 10, 19, 18, 30), now: now),
        'Today, 6:30 PM',
      );
      expect(
        Formatters.slotTime(DateTime(2026, 10, 20, 9), now: now),
        'Tomorrow, 9:00 AM',
      );
    });

    test('later days by date', () {
      expect(
        Formatters.slotTime(DateTime(2026, 10, 23, 9), now: now),
        'Fri 23 Oct, 9:00 AM',
      );
    });

    test('just after midnight is tomorrow, not today', () {
      expect(
        Formatters.slotTime(
          DateTime(2026, 10, 20, 0, 15),
          now: DateTime(2026, 10, 19, 23, 50),
        ),
        'Tomorrow, 12:15 AM',
      );
    });
  });
}
