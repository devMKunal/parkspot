import 'package:flutter_test/flutter_test.dart';
import 'package:parkspot/core/utils/money.dart';

void main() {
  group('Money', () {
    test('reads the API shape', () {
      final m = Money.fromJson(const {'amount': 4000, 'currency': 'INR'});
      expect(m, const Money(4000));
      expect(m.toJson(), {'amount': 4000, 'currency': 'INR'});
    });

    test('adds and multiplies in paise', () {
      expect(const Money(4000) * 2, const Money(8000));
      expect(const Money(4000) + const Money(50), const Money(4050));
    });

    test('refuses to mix currencies', () {
      expect(
        () => const Money(100) + const Money(100, currency: 'USD'),
        throwsArgumentError,
      );
    });

    test('compares by amount', () {
      expect(const Money(100).compareTo(const Money(200)), isNegative);
      expect(Money.zero.isZero, isTrue);
    });
  });
}
