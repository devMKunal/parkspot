import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:parkspot/core/di/injector.dart';
import 'package:parkspot/core/extensions/context_x.dart';
import 'package:parkspot/core/theme/app_spacing.dart';
import 'package:parkspot/core/utils/directions.dart';
import 'package:parkspot/core/utils/formatters.dart';
import 'package:parkspot/core/widgets/alert_banner.dart';
import 'package:parkspot/core/widgets/choice_pill.dart';
import 'package:parkspot/core/widgets/chunky_button.dart';
import 'package:parkspot/core/widgets/countdown_ring.dart';
import 'package:parkspot/core/widgets/status_chip.dart';
import 'package:parkspot/core/widgets/ticket_card.dart';
import 'package:parkspot/features/active_booking/presentation/bloc/active_booking_bloc.dart';
import 'package:parkspot/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:parkspot/features/bookings/domain/booking.dart';
import 'package:parkspot/router/app_routes.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ActiveBookingPage extends StatelessWidget {
  const ActiveBookingPage({required this.bookingId, super.key});

  final String bookingId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ActiveBookingBloc(
        bookingId: bookingId,
        bookings: getIt(),
        lots: getIt(),
        checkout: getIt(),
        user: context.read<AuthBloc>().state.user,
      )..add(const ActiveBookingStarted()),
      child: const ActiveBookingView(),
    );
  }
}

/// Extension choices in the "Need more time?" sheet.
const List<Duration> extendOptions = [
  Duration(minutes: 15),
  Duration(minutes: 30),
  Duration(hours: 1),
  Duration(hours: 2),
];

class ActiveBookingView extends StatefulWidget {
  const ActiveBookingView({this.clock, super.key});

  /// For tests; defaults to the device clock.
  final DateTime Function()? clock;

  @override
  State<ActiveBookingView> createState() => _ActiveBookingViewState();
}

class _ActiveBookingViewState extends State<ActiveBookingView> {
  late final DateTime Function() _clock = widget.clock ?? DateTime.now;
  late DateTime _now = _clock();
  Timer? _ticker;
  bool _reloadedAtEnd = false;

  @override
  void initState() {
    super.initState();
    // The countdown is display only; the server decides when time is up.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    setState(() => _now = _clock());
    final booking = context.read<ActiveBookingBloc>().state.booking;
    if (booking != null &&
        booking.status.isLive &&
        !_now.isBefore(booking.end) &&
        !_reloadedAtEnd) {
      _reloadedAtEnd = true;
      context.read<ActiveBookingBloc>().add(const ActiveBookingStarted());
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _extend() async {
    final bloc = context.read<ActiveBookingBloc>();
    final by = await showModalBottomSheet<Duration>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _ExtendSheet(),
    );
    if (by != null) bloc.add(ActiveBookingExtendPressed(by));
  }

  Future<void> _leaveEarly() async {
    final bloc = context.read<ActiveBookingBloc>();
    final sure = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leaving early?'),
        content: const Text(
          "We'll free your slot for the next driver. Time you don't use "
          "isn't refunded.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("I'm leaving"),
          ),
        ],
      ),
    );
    if (sure ?? false) bloc.add(const ActiveBookingEndPressed());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ActiveBookingBloc, ActiveBookingState>(
      listenWhen: (previous, current) =>
          current.notice != null && current.notice != previous.notice,
      listener: (context, state) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(state.notice!))),
      builder: (context, state) {
        final booking = state.booking;
        final lot = state.lot;
        if (booking == null || lot == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: state.loadError == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: AppSpacing.screen,
                      child: AlertBanner(message: state.loadError!),
                    ),
            ),
          );
        }
        final busy = state.acting.isSubmitting;
        final status = booking.status;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Back to the map',
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go(AppRoutes.home),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              0,
              AppSpacing.xl,
              AppSpacing.lg,
            ),
            children: [
              _Header(booking: booking, lotName: lot.name),
              const SizedBox(height: AppSpacing.lg + 2),
              _TimeCard(booking: booking, now: _now),
              if (status.isLive && booking.passCode != null) ...[
                const SizedBox(height: AppSpacing.lg + 2),
                _Pass(passCode: booking.passCode!),
              ],
            ],
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.xl,
              AppSpacing.lg,
            ),
            child: switch (status) {
              BookingStatus.confirmed || BookingStatus.active => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ChunkyButton.icon(
                        icon: Icons.near_me_rounded,
                        semanticLabel: 'Directions',
                        onPressed: () =>
                            unawaited(openDirections(context, lot.location)),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: status == BookingStatus.active
                            ? ChunkyButton(
                                label: 'Need more time?',
                                variant: ChunkyButtonVariant.accent,
                                loading: busy,
                                onPressed: () => unawaited(_extend()),
                              )
                            : ChunkyButton(
                                label: 'Scan at the gate',
                                loading: busy,
                                onPressed: () => context
                                    .read<ActiveBookingBloc>()
                                    .add(const ActiveBookingCheckInPressed()),
                              ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: AppSizes.minTouchTarget,
                    child: status == BookingStatus.active
                        ? TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: context.colors.error,
                            ),
                            onPressed: busy
                                ? null
                                : () => unawaited(_leaveEarly()),
                            child: const Text("I'm leaving early"),
                          )
                        : Center(
                            child: Text(
                              'Demo: sends your pass code, like a gate '
                              'scanner would',
                              style: context.text.bodySmall?.copyWith(
                                color: context.colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                  ),
                ],
              ),
              _ => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ChunkyButton(
                    label: 'Book here again',
                    onPressed: () => context.go(AppRoutes.book(lot.id)),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.home),
                    child: const Text('Back to the map'),
                  ),
                ],
              ),
            },
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.booking, required this.lotName});

  final Booking booking;
  final String lotName;

  @override
  Widget build(BuildContext context) {
    final (title, chip) = switch (booking.status) {
      BookingStatus.active => (
        'Parked & cosy',
        const StatusChip(
          label: 'Checked in',
          tone: StatusTone.success,
          icon: Icons.check_rounded,
        ),
      ),
      BookingStatus.confirmed => (
        'Your pass is ready',
        const StatusChip(label: 'Booked', tone: StatusTone.highlight),
      ),
      BookingStatus.completed => (
        'All done',
        const StatusChip(label: 'Completed'),
      ),
      _ => (
        'This booking is closed',
        StatusChip(label: _statusLabel(booking.status)),
      ),
    };
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$lotName · ${booking.slotLabel}',
                style: context.text.labelLarge?.copyWith(
                  color: context.colors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(title, style: context.text.headlineMedium),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        chip,
      ],
    );
  }
}

String _statusLabel(BookingStatus s) => switch (s) {
  BookingStatus.pending => 'Awaiting payment',
  BookingStatus.confirmed => 'Booked',
  BookingStatus.active => 'Checked in',
  BookingStatus.completed => 'Completed',
  BookingStatus.cancelled => 'Cancelled',
  BookingStatus.failed => 'Failed',
  BookingStatus.expired => 'Expired',
};

class _TimeCard extends StatelessWidget {
  const _TimeCard({required this.booking, required this.now});

  final Booking booking;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final live = booking.status.isLive;
    final early = now.isBefore(booking.start);
    final left = booking.end.difference(now);
    final fraction = !live
        ? 0.0
        : early
        ? 1.0
        : left.inSeconds / booking.duration.inSeconds;

    final (ringText, ringCaption) = !live
        ? (Formatters.duration(booking.duration), 'parked')
        : early
        ? (Formatters.countdown(booking.start.difference(now)), 'to start')
        : (Formatters.countdown(left), 'left');
    final (headline, note) = !live
        ? (
            Formatters.slotWindow(booking.start, booking.end),
            'Paid ${Formatters.money(booking.amount)}.',
          )
        : early
        ? (
            'From ${Formatters.time(booking.start)}',
            'Check in at the gate from 15 minutes before.',
          )
        : (
            'Till ${Formatters.time(booking.end)}',
            "Extend before it runs out and you'll keep this slot.",
          );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.semantic.tintViolet,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          CountdownRing(
            remaining: fraction,
            semanticLabel: '$ringText $ringCaption',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ringText,
                  style: context.text.headlineSmall?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                Text(
                  ringCaption,
                  style: context.text.labelMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.lg + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(headline, style: context.text.titleLarge),
                const SizedBox(height: AppSpacing.xs + 2),
                Text(
                  note,
                  style: context.text.bodySmall?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pass extends StatelessWidget {
  const _Pass({required this.passCode});

  final String passCode;

  // Scanners need dark on white, whatever the theme.
  static const Color _paper = Colors.white;

  @override
  Widget build(BuildContext context) {
    final ink = context.semantic.markerOutline;
    return Semantics(
      container: true,
      label: 'Entry pass',
      child: TicketCard(
        color: _paper,
        borderColor: context.isDark ? context.colors.outlineVariant : ink,
        notchOffset: 0.42,
        child: Column(
          children: [
            Semantics(
              image: true,
              label: 'QR code for your entry pass',
              child: QrImageView(
                data: passCode,
                size: AppSizes.qrSize,
                padding: EdgeInsets.zero,
                eyeStyle: QrEyeStyle(eyeShape: QrEyeShape.square, color: ink),
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: ink,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.sm + 2),
            Text(
              'Flash this at the gate',
              style: context.text.labelLarge?.copyWith(
                color: ink.withValues(alpha: 0.8),
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              passCode,
              style: context.text.titleMedium?.copyWith(
                color: ink,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtendSheet extends StatefulWidget {
  const _ExtendSheet();

  @override
  State<_ExtendSheet> createState() => _ExtendSheetState();
}

class _ExtendSheetState extends State<_ExtendSheet> {
  Duration _by = extendOptions[1];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('How much longer?', style: context.text.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Same slot, paid separately. The checkout shows the price.',
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final option in extendOptions)
                ChoicePill(
                  label: '+${Formatters.duration(option)}',
                  height: 48,
                  emphasis: ChoicePillEmphasis.primary,
                  selected: option == _by,
                  onSelected: () => setState(() => _by = option),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          ChunkyButton(
            label: 'Pay & extend',
            variant: ChunkyButtonVariant.accent,
            onPressed: () => Navigator.pop(context, _by),
          ),
        ],
      ),
    );
  }
}
