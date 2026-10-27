part of 'booking_bloc.dart';

typedef DurationPreset = ({String title, Duration duration});

const List<DurationPreset> durationPresets = [
  (title: 'Quick errand', duration: Duration(minutes: 30)),
  (title: 'Coffee & catch-up', duration: Duration(hours: 1)),
  (title: 'Shopping spree', duration: Duration(hours: 2)),
  (title: 'Movie night', duration: Duration(hours: 3)),
];

@immutable
final class BookingState extends Equatable {
  BookingState({
    required this.now,
    DateTime? day,
    this.start,
    this.duration = const Duration(hours: 2),
    this.fineTune = false,
    this.lot,
    this.loadError,
    this.status = SubmitStatus.idle,
    this.error,
    this.outcome,
  }) : day = day ?? DateTime(now.year, now.month, now.day);

  /// When the screen opened; start times before it aren't offered.
  final DateTime now;

  /// Local midnight of the chosen day.
  final DateTime day;
  final DateTime? start;
  final Duration duration;

  /// Showing the 15-minute stepper under the presets.
  final bool fineTune;
  final Lot? lot;
  final String? loadError;
  final SubmitStatus status;
  final String? error;

  /// Set once paying finished; the page navigates on it.
  final PayOutcome? outcome;

  DateTime get today => DateTime(now.year, now.month, now.day);

  /// The last day a booking may start (7 days ahead).
  DateTime get lastDay => today.add(AppConstants.maxBookAhead);

  DateTime? get end => start?.add(duration);

  /// Start times on [day] in 15-minute steps, from the next step today.
  List<DateTime> get starts {
    final step = AppConstants.slotStep.inMinutes;
    final first = day == today
        ? DateTime(
            now.year,
            now.month,
            now.day,
            now.hour,
            (now.minute ~/ step + 1) * step,
          )
        : day;
    final next = day.add(const Duration(days: 1));
    return [
      for (var t = first; t.isBefore(next); t = t.add(AppConstants.slotStep)) t,
    ];
  }

  /// What the server will charge, rounded the same way (whole paise). For
  /// the summary only; the checkout always uses the server's order.
  Money? get estimate {
    final price = lot?.pricePerHour;
    if (price == null) return null;
    return Money(
      (price.paise * duration.inMinutes + 30) ~/ 60,
      currency: price.currency,
    );
  }

  BookingState copyWith({
    DateTime? now,
    DateTime? day,
    ValueGetter<DateTime?>? start,
    Duration? duration,
    bool? fineTune,
    ValueGetter<Lot?>? lot,
    ValueGetter<String?>? loadError,
    SubmitStatus? status,
    ValueGetter<String?>? error,
    ValueGetter<PayOutcome?>? outcome,
  }) => BookingState(
    now: now ?? this.now,
    day: day ?? this.day,
    start: start != null ? start() : this.start,
    duration: duration ?? this.duration,
    fineTune: fineTune ?? this.fineTune,
    lot: lot != null ? lot() : this.lot,
    loadError: loadError != null ? loadError() : this.loadError,
    status: status ?? this.status,
    error: error != null ? error() : this.error,
    outcome: outcome != null ? outcome() : this.outcome,
  );

  @override
  List<Object?> get props => [
    now,
    day,
    start,
    duration,
    fineTune,
    lot,
    loadError,
    status,
    error,
    outcome,
  ];
}
