part of 'payment_result_bloc.dart';

@immutable
sealed class PaymentResultEvent extends Equatable {
  const PaymentResultEvent();

  @override
  List<Object?> get props => [];
}

final class PaymentResultStarted extends PaymentResultEvent {
  const PaymentResultStarted({this.waitForConfirmation = false});

  /// Poll while the booking is PENDING (the success screen).
  final bool waitForConfirmation;

  @override
  List<Object?> get props => [waitForConfirmation];
}

/// "Try payment again": books the same lot and time, then pays.
final class PaymentRetried extends PaymentResultEvent {
  const PaymentRetried();
}
