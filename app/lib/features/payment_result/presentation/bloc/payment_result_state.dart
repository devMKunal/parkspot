part of 'payment_result_bloc.dart';

@immutable
final class PaymentResultState extends Equatable {
  const PaymentResultState({
    this.booking,
    this.lot,
    this.error,
    this.paying = SubmitStatus.idle,
    this.retryError,
    this.outcome,
  });

  final Booking? booking;
  final Lot? lot;

  /// Loading failed.
  final String? error;
  final SubmitStatus paying;
  final String? retryError;

  /// Set when a retry finished; the page navigates on it.
  final PayOutcome? outcome;

  bool get loading => booking == null && error == null;

  PaymentResultState copyWith({
    Booking? booking,
    ValueGetter<String?>? error,
    SubmitStatus? paying,
    ValueGetter<String?>? retryError,
    PayOutcome? outcome,
  }) => PaymentResultState(
    booking: booking ?? this.booking,
    lot: lot,
    error: error != null ? error() : this.error,
    paying: paying ?? this.paying,
    retryError: retryError != null ? retryError() : this.retryError,
    outcome: outcome ?? this.outcome,
  );

  @override
  List<Object?> get props => [booking, lot, error, paying, retryError, outcome];
}
