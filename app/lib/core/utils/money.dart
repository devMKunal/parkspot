import 'package:flutter/foundation.dart';

/// An amount in paise, exactly as the API sends it:
/// `{ "amount": 4000, "currency": "INR" }` is ₹40.
///
/// Integer maths only. Display goes through `Formatters.money`; the amount
/// shown on a Pay button is always the server's, never a client total.
@immutable
final class Money implements Comparable<Money> {
  const Money(this.paise, {this.currency = 'INR'})
    : assert(paise >= 0, 'Money cannot be negative');

  factory Money.fromJson(Map<String, dynamic> json) =>
      Money(json['amount'] as int, currency: json['currency'] as String);

  static const zero = Money(0);

  final int paise;
  final String currency;

  bool get isZero => paise == 0;

  Money operator +(Money other) {
    _checkCurrency(other);
    return Money(paise + other.paise, currency: currency);
  }

  Money operator *(int times) => Money(paise * times, currency: currency);

  Map<String, dynamic> toJson() => {'amount': paise, 'currency': currency};

  void _checkCurrency(Money other) {
    if (other.currency != currency) {
      throw ArgumentError('Cannot mix $currency and ${other.currency}');
    }
  }

  @override
  int compareTo(Money other) {
    _checkCurrency(other);
    return paise.compareTo(other.paise);
  }

  @override
  bool operator ==(Object other) =>
      other is Money && other.paise == paise && other.currency == currency;

  @override
  int get hashCode => Object.hash(paise, currency);

  @override
  String toString() => 'Money($paise $currency)';
}
