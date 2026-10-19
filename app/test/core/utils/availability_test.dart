import 'package:flutter_test/flutter_test.dart';
import 'package:parkspot/core/utils/availability.dart';

void main() {
  Availability of(int free, int total) =>
      Availability.fromCounts(free: free, total: total);

  test('above 30% free is high', () {
    expect(of(37, 120), Availability.high);
  });

  test('10% to 30% free is medium, both ends included', () {
    expect(of(30, 100), Availability.medium);
    expect(of(10, 100), Availability.medium);
  });

  test('under 10% free is low', () {
    expect(of(2, 30), Availability.low);
  });

  test('no free slots, or a lot with no slots, is full', () {
    expect(of(0, 25), Availability.full);
    expect(of(0, 0), Availability.full);
  });
}
