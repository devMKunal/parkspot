import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:parkspot/core/di/injector.dart';
import 'package:parkspot/core/extensions/context_x.dart';
import 'package:parkspot/core/theme/app_spacing.dart';
import 'package:parkspot/core/theme/app_typography.dart';
import 'package:parkspot/core/utils/formatters.dart';
import 'package:parkspot/core/widgets/alert_banner.dart';
import 'package:parkspot/core/widgets/choice_pill.dart';
import 'package:parkspot/core/widgets/status_chip.dart';
import 'package:parkspot/features/bookings/domain/booking.dart';
import 'package:parkspot/features/trips/presentation/bloc/trips_bloc.dart';
import 'package:parkspot/router/app_routes.dart';

class TripsPage extends StatelessWidget {
  const TripsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          TripsBloc(bookings: getIt(), lots: getIt())
            ..add(const TripsStarted()),
      child: const TripsView(),
    );
  }
}

class TripsView extends StatelessWidget {
  const TripsView({this.now, super.key});

  /// For tests; defaults to the clock.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TripsBloc, TripsState>(
      builder: (context, state) {
        final bloc = context.read<TripsBloc>();
        final list = state.tab == TripsTab.upcoming
            ? state.upcoming
            : state.past;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              tooltip: 'Back',
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () =>
                  context.canPop() ? context.pop() : context.go(AppRoutes.home),
            ),
          ),
          body: RefreshIndicator(
            onRefresh: () async {
              bloc.add(const TripsStarted());
              await bloc.stream.firstWhere((s) => !s.loading);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                0,
                AppSpacing.xl,
                AppSpacing.xl,
              ),
              children: [
                Text('My trips', style: context.text.headlineLarge),
                const SizedBox(height: AppSpacing.lg),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final (tab, label) in [
                      (TripsTab.upcoming, 'Upcoming'),
                      (TripsTab.past, 'Past'),
                    ])
                      ChoicePill(
                        label: label,
                        selected: state.tab == tab,
                        onSelected: () => bloc.add(TripsTabChanged(tab)),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                if (state.error case final error?) ...[
                  AlertBanner(message: error),
                  TextButton(
                    onPressed: () => bloc.add(const TripsStarted()),
                    child: const Text('Try again'),
                  ),
                ] else if (state.loading && state.bookings.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.xxxl),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (list.isEmpty)
                  _Empty(tab: state.tab)
                else
                  for (final booking in list) ...[
                    if (state.tab == TripsTab.upcoming)
                      _UpcomingCard(
                        booking: booking,
                        lotName: state.lots[booking.lotId]?.name,
                        now: now ?? DateTime.now(),
                      )
                    else
                      _PastTile(
                        booking: booking,
                        lotName: state.lots[booking.lotId]?.name,
                      ),
                    const SizedBox(height: AppSpacing.md),
                  ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.tab});

  final TripsTab tab;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxxl),
      child: Column(
        children: [
          Text(
            tab == TripsTab.upcoming
                ? 'Nothing booked yet.'
                : 'No past trips yet.',
            style: context.text.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => context.go(AppRoutes.home),
            child: const Text('Find a spot on the map'),
          ),
        ],
      ),
    );
  }
}

/// The primary card: happening now, starting later, or awaiting payment.
class _UpcomingCard extends StatelessWidget {
  const _UpcomingCard({
    required this.booking,
    required this.lotName,
    required this.now,
  });

  final Booking booking;
  final String? lotName;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final pending = booking.status == BookingStatus.pending;
    final happening =
        booking.status.isLive &&
        !now.isBefore(booking.start) &&
        now.isBefore(booking.end);
    final (chip, trailing, action) = pending
        ? ('Awaiting payment', '', 'Tap to finish paying')
        : happening
        ? (
            'Happening now',
            '${Formatters.countdown(booking.end.difference(now))} left',
            'Tap to open your pass',
          )
        : (
            'Booked',
            'Starts ${Formatters.time(booking.start)}',
            'Tap to open your pass',
          );
    final onCard = colors.onPrimary;

    return Material(
      color: colors.primary,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.go(
          pending
              ? AppRoutes.bookingFailed(booking.id)
              : AppRoutes.booking(booking.id),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusChip(label: chip, tone: StatusTone.highlight),
                  const Spacer(),
                  Text(
                    trailing,
                    style: context.text.labelLarge?.copyWith(color: onCard),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm + 2),
              Text(
                '${lotName ?? 'Parking lot'} · ${booking.slotLabel}',
                style: context.text.titleLarge?.copyWith(color: onCard),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '${Formatters.slotWindow(booking.start, booking.end)} · '
                '$action',
                style: context.text.bodySmall?.copyWith(
                  color: onCard.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PastTile extends StatelessWidget {
  const _PastTile({required this.booking, required this.lotName});

  final Booking booking;
  final String? lotName;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final semantic = context.semantic;
    final (label, tone, tint) = switch (booking.status) {
      BookingStatus.completed => (
        'Completed',
        StatusTone.success,
        semantic.tintMint,
      ),
      BookingStatus.cancelled => (
        'Cancelled',
        StatusTone.neutral,
        semantic.tintYellow,
      ),
      BookingStatus.expired => (
        'Not paid',
        StatusTone.neutral,
        semantic.tintYellow,
      ),
      _ => ('Failed', StatusTone.danger, semantic.tintViolet),
    };
    final day = Formatters.slotTime(booking.start).split(',').first;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant, width: 2),
      ),
      child: Row(
        children: [
          ExcludeSemantics(
            child: Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'P',
                style: TextStyle(
                  fontFamily: AppTypography.display,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: colors.onSurface,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(lotName ?? 'Parking lot', style: context.text.titleSmall),
                Text(
                  '$day, ${Formatters.duration(booking.duration)} · '
                  '${Formatters.money(booking.amount)}',
                  style: context.text.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                StatusChip(label: label, tone: tone),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          FilledButton.tonal(
            onPressed: () => context.go(AppRoutes.book(booking.lotId)),
            child: const Text('Rebook'),
          ),
        ],
      ),
    );
  }
}
