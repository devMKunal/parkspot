import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:parkspot/core/di/injector.dart';
import 'package:parkspot/core/extensions/context_x.dart';
import 'package:parkspot/core/theme/app_spacing.dart';
import 'package:parkspot/core/utils/formatters.dart';
import 'package:parkspot/core/widgets/alert_banner.dart';
import 'package:parkspot/core/widgets/choice_pill.dart';
import 'package:parkspot/core/widgets/chunky_button.dart';
import 'package:parkspot/core/widgets/duration_preset_card.dart';
import 'package:parkspot/core/widgets/ticket_card.dart';
import 'package:parkspot/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:parkspot/features/booking/presentation/bloc/booking_bloc.dart';
import 'package:parkspot/features/bookings/domain/checkout_flow.dart';
import 'package:parkspot/router/app_routes.dart';

class BookingPage extends StatelessWidget {
  const BookingPage({required this.lotId, super.key});

  final String lotId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => BookingBloc(
        lotId: lotId,
        lots: getIt(),
        checkout: getIt(),
        user: context.read<AuthBloc>().state.user,
      )..add(const BookingStarted()),
      child: const BookingView(),
    );
  }
}

/// Where the outcome of a payment attempt takes the driver. Shared with
/// the "Try payment again" button on the failure screen.
void goToOutcome(BuildContext context, PayOutcome outcome) {
  final id = outcome.booking.id;
  context.go(switch (outcome) {
    PayConfirmed() || PayPending() => AppRoutes.bookingPaid(id),
    PayNotCompleted() => AppRoutes.bookingFailed(id),
  });
}

class BookingView extends StatelessWidget {
  const BookingView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<BookingBloc, BookingState>(
      listenWhen: (previous, current) =>
          current.outcome != null && current.outcome != previous.outcome,
      listener: (context, state) => goToOutcome(context, state.outcome!),
      builder: (context, state) {
        final lot = state.lot;
        return Scaffold(
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.xl,
                    0,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      tooltip: 'Back',
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go(AppRoutes.home),
                    ),
                  ),
                ),
                Expanded(
                  child: lot == null
                      ? _Loading(error: state.loadError)
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.xl,
                            0,
                            AppSpacing.xl,
                            AppSpacing.lg,
                          ),
                          children: [
                            Text(
                              lot.name,
                              style: context.text.labelLarge?.copyWith(
                                color: context.colors.primary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'When are you rolling in?',
                              style: context.text.headlineMedium,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _DayPicker(state: state),
                            const SizedBox(height: AppSpacing.sm),
                            _StartPicker(state: state),
                            const SizedBox(height: AppSpacing.xl),
                            Text(
                              'How long are you staying?',
                              style: context.text.titleMedium,
                            ),
                            const SizedBox(height: AppSpacing.sm + 2),
                            _DurationPicker(state: state),
                            const SizedBox(height: AppSpacing.xl),
                            _Summary(state: state),
                            if (state.error case final error?) ...[
                              const SizedBox(height: AppSpacing.lg),
                              AlertBanner(message: error),
                            ],
                          ],
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.md,
                    AppSpacing.xl,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // No client total on the Pay button: the checkout
                      // shows the server's amount.
                      ChunkyButton(
                        label: 'Pay & park',
                        loading: state.status.isSubmitting,
                        onPressed: lot == null || state.start == null
                            ? null
                            : () => context.read<BookingBloc>().add(
                                const BookingPayPressed(),
                              ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        "We'll hold your spot for 10 minutes while you pay",
                        style: context.text.bodySmall?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading({required this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    if (error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Padding(
      padding: AppSpacing.screen,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AlertBanner(message: error!),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () =>
                context.read<BookingBloc>().add(const BookingStarted()),
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _DayPicker extends StatelessWidget {
  const _DayPicker({required this.state});

  final BookingState state;

  Future<void> _pickDate(BuildContext context) async {
    final bloc = context.read<BookingBloc>();
    final picked = await showDatePicker(
      context: context,
      initialDate: state.day,
      firstDate: state.today,
      lastDate: state.lastDay,
    );
    if (picked != null) bloc.add(BookingDayPicked(picked));
  }

  @override
  Widget build(BuildContext context) {
    final tomorrow = state.today.add(const Duration(days: 1));
    final later = state.day.isAfter(tomorrow);
    void pick(DateTime day) =>
        context.read<BookingBloc>().add(BookingDayPicked(day));
    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        ChoicePill(
          label: 'Today',
          selected: state.day == state.today,
          onSelected: () => pick(state.today),
        ),
        ChoicePill(
          label: 'Tomorrow',
          selected: state.day == tomorrow,
          onSelected: () => pick(tomorrow),
        ),
        ChoicePill(
          label: later
              ? Formatters.slotTime(state.day).split(',').first
              : 'Pick a date',
          selected: later,
          onSelected: () => unawaited(_pickDate(context)),
        ),
      ],
    );
  }
}

class _StartPicker extends StatelessWidget {
  const _StartPicker({required this.state});

  final BookingState state;

  @override
  Widget build(BuildContext context) {
    final starts = state.starts;
    return SizedBox(
      height: AppSizes.minTouchTarget + 4,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: starts.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) => SizedBox(
          width: 84,
          child: ChoicePill(
            label: Formatters.time(starts[i]),
            height: 48,
            emphasis: ChoicePillEmphasis.primary,
            selected: starts[i] == state.start,
            onSelected: () =>
                context.read<BookingBloc>().add(BookingStartPicked(starts[i])),
          ),
        ),
      ),
    );
  }
}

class _DurationPicker extends StatelessWidget {
  const _DurationPicker({required this.state});

  final BookingState state;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<BookingBloc>();
    final isPreset = durationPresets.any((p) => p.duration == state.duration);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Rows, not a grid: the cards size to their text at any font scale.
        for (var row = 0; row < durationPresets.length; row += 2) ...[
          if (row > 0) const SizedBox(height: AppSpacing.sm + 2),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, preset)
                    in durationPresets.skip(row).take(2).indexed) ...[
                  if (i > 0) const SizedBox(width: AppSpacing.sm + 2),
                  Expanded(
                    child: DurationPresetCard(
                      title: preset.title,
                      value: Formatters.duration(preset.duration),
                      selected: preset.duration == state.duration,
                      onTap: () =>
                          bloc.add(BookingDurationPicked(preset.duration)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        if (state.fineTune || !isPreset)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                tooltip: '15 minutes less',
                icon: const Icon(Icons.remove_rounded),
                onPressed: () => bloc.add(const BookingDurationNudged(-1)),
              ),
              SizedBox(
                width: 120,
                child: Text(
                  Formatters.duration(state.duration),
                  textAlign: TextAlign.center,
                  style: context.text.titleLarge,
                ),
              ),
              IconButton.filledTonal(
                tooltip: '15 minutes more',
                icon: const Icon(Icons.add_rounded),
                onPressed: () => bloc.add(const BookingDurationNudged(1)),
              ),
            ],
          )
        else
          Text(
            'Need something else? Tap a card twice to fine-tune in '
            '15-minute steps.',
            style: context.text.bodySmall?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.state});

  final BookingState state;

  @override
  Widget build(BuildContext context) {
    final lot = state.lot!;
    final start = state.start;
    final estimate = state.estimate!;
    final muted = context.text.bodyMedium?.copyWith(
      color: context.colors.onSurfaceVariant,
    );
    final when = start == null
        ? 'Pick a start time'
        : Formatters.timeRange(start, state.end!);
    return TicketCard(
      color: context.semantic.tintYellow,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${Formatters.money(lot.pricePerHour)} × '
                  '${Formatters.duration(state.duration)} · $when',
                  style: muted,
                ),
              ),
              Text(Formatters.money(estimate), style: muted),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: DashedDivider(),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Text('Total', style: context.text.titleSmall)),
              Text(
                Formatters.money(estimate),
                style: context.text.headlineSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
