part of 'booking_bloc.dart';

@immutable
sealed class BookingEvent extends Equatable {
  const BookingEvent();

  @override
  List<Object?> get props => [];
}

/// Loads the lot and opens on the first free start today. Also the retry.
final class BookingStarted extends BookingEvent {
  const BookingStarted();
}

final class BookingDayPicked extends BookingEvent {
  const BookingDayPicked(this.day);

  final DateTime day;

  @override
  List<Object?> get props => [day];
}

final class BookingStartPicked extends BookingEvent {
  const BookingStartPicked(this.start);

  final DateTime start;

  @override
  List<Object?> get props => [start];
}

/// A preset card. The same card twice toggles fine-tuning.
final class BookingDurationPicked extends BookingEvent {
  const BookingDurationPicked(this.duration);

  final Duration duration;

  @override
  List<Object?> get props => [duration];
}

/// Fine-tuning: +1 or -1 slot step (15 minutes).
final class BookingDurationNudged extends BookingEvent {
  const BookingDurationNudged(this.steps);

  final int steps;

  @override
  List<Object?> get props => [steps];
}

final class BookingPayPressed extends BookingEvent {
  const BookingPayPressed();
}
