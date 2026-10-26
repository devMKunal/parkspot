import 'package:equatable/equatable.dart';
import 'package:parkspot/core/utils/money.dart';

/// docs/bookings-api.md
enum BookingStatus {
  pending,
  confirmed,
  active,
  completed,
  cancelled,
  failed,
  expired;

  static BookingStatus parse(String wire) => values.byName(wire.toLowerCase());

  /// The pass can be shown at the gate.
  bool get isLive => this == confirmed || this == active;
}

class Booking extends Equatable {
  const Booking({
    required this.id,
    required this.lotId,
    required this.slotLabel,
    required this.start,
    required this.end,
    required this.amount,
    required this.status,
    this.lockExpiresAt,
    this.passCode,
    this.endedAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
    id: json['id'] as String,
    lotId: json['lotId'] as String,
    slotLabel: json['slotLabel'] as String,
    start: DateTime.parse(json['start'] as String),
    end: DateTime.parse(json['end'] as String),
    amount: Money.fromJson(json['amount'] as Map<String, dynamic>),
    status: BookingStatus.parse(json['status'] as String),
    lockExpiresAt: _date(json['lockExpiresAt']),
    passCode: json['passCode'] as String?,
    endedAt: _date(json['endedAt']),
  );

  static DateTime? _date(Object? value) =>
      value == null ? null : DateTime.parse(value as String);

  final String id;
  final String lotId;
  final String slotLabel;
  final DateTime start;
  final DateTime end;

  /// Total paid, extensions included. Always the server's number.
  final Money amount;
  final BookingStatus status;

  /// While PENDING: when the held slot is released.
  final DateTime? lockExpiresAt;

  /// The QR payload; only set while the pass is live.
  final String? passCode;
  final DateTime? endedAt;

  Duration get duration => end.difference(start);

  @override
  List<Object?> get props => [
    id,
    lotId,
    slotLabel,
    start,
    end,
    amount,
    status,
    lockExpiresAt,
    passCode,
    endedAt,
  ];
}

/// The order to pay, as `POST /bookings` returns it.
class PaymentOrder extends Equatable {
  const PaymentOrder({
    required this.keyId,
    required this.orderId,
    required this.amount,
  });

  factory PaymentOrder.fromJson(Map<String, dynamic> json) => PaymentOrder(
    keyId: json['keyId'] as String,
    orderId: json['orderId'] as String,
    amount: Money(json['amount'] as int, currency: json['currency'] as String),
  );

  /// The provider's public key id, for the checkout.
  final String keyId;
  final String orderId;
  final Money amount;

  @override
  List<Object?> get props => [keyId, orderId, amount];
}
