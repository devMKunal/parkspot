part of 'active_booking_bloc.dart';

@immutable
sealed class ActiveBookingEvent extends Equatable {
  const ActiveBookingEvent();

  @override
  List<Object?> get props => [];
}

/// Load, and reload (the countdown hit zero, the app came back).
final class ActiveBookingStarted extends ActiveBookingEvent {
  const ActiveBookingStarted();
}

/// Something that changes the booking on the server.
sealed class ActiveBookingAction extends ActiveBookingEvent {
  const ActiveBookingAction();
}

/// The demo gate scan: the app sends its own pass code.
final class ActiveBookingCheckInPressed extends ActiveBookingAction {
  const ActiveBookingCheckInPressed();
}

final class ActiveBookingExtendPressed extends ActiveBookingAction {
  const ActiveBookingExtendPressed(this.by);

  final Duration by;

  @override
  List<Object?> get props => [by];
}

final class ActiveBookingEndPressed extends ActiveBookingAction {
  const ActiveBookingEndPressed();
}
