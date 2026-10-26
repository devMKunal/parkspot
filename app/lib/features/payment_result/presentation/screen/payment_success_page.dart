import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:parkspot/core/di/injector.dart';
import 'package:parkspot/core/extensions/context_x.dart';
import 'package:parkspot/core/theme/app_spacing.dart';
import 'package:parkspot/core/utils/directions.dart';
import 'package:parkspot/core/utils/formatters.dart';
import 'package:parkspot/core/widgets/alert_banner.dart';
import 'package:parkspot/core/widgets/brand_mark.dart';
import 'package:parkspot/core/widgets/chunky_button.dart';
import 'package:parkspot/core/widgets/fill_scroll_view.dart';
import 'package:parkspot/core/widgets/ticket_card.dart';
import 'package:parkspot/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:parkspot/features/bookings/domain/booking.dart';
import 'package:parkspot/features/lots/domain/lot.dart';
import 'package:parkspot/features/payment_result/presentation/bloc/payment_result_bloc.dart';
import 'package:parkspot/router/app_routes.dart';

/// Builds a [PaymentResultBloc] for [bookingId]; both result pages use it.
PaymentResultBloc createPaymentResultBloc(
  BuildContext context,
  String bookingId,
) => PaymentResultBloc(
  bookingId: bookingId,
  bookings: getIt(),
  lots: getIt(),
  checkout: getIt(),
  user: context.read<AuthBloc>().state.user,
);

class PaymentSuccessPage extends StatelessWidget {
  const PaymentSuccessPage({required this.bookingId, super.key});

  final String bookingId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          createPaymentResultBloc(context, bookingId)
            ..add(const PaymentResultStarted(waitForConfirmation: true)),
      child: const PaymentSuccessView(),
    );
  }
}

/// "You're parked!", on the celebration colour. While the server is still
/// confirming (offline verify, external wallet) it says so and waits.
class PaymentSuccessView extends StatelessWidget {
  const PaymentSuccessView({super.key});

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final onBrand = semantic.onCelebration;
    return BlocConsumer<PaymentResultBloc, PaymentResultState>(
      // Expired or failed while we waited: that's the failure screen's job.
      listenWhen: (previous, current) =>
          previous.booking?.status != current.booking?.status &&
          _gaveUp(current.booking),
      listener: (context, state) =>
          context.go(AppRoutes.bookingFailed(state.booking!.id)),
      builder: (context, state) {
        final booking = state.booking;
        final lot = state.lot;
        final confirmed = booking?.status.isLive ?? false;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            backgroundColor: semantic.celebration,
            body: Stack(
              children: [
                if (confirmed) const Positioned.fill(child: _Confetti()),
                SafeArea(
                  child: FillScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xxl,
                      AppSpacing.xxxl * 2,
                      AppSpacing.xxl,
                      AppSpacing.lg,
                    ),
                    child: Column(
                      children: [
                        if (state.error case final error?)
                          AlertBanner(message: error)
                        else if (booking == null || lot == null || !confirmed)
                          _Confirming(color: onBrand)
                        else ...[
                          BrandMark(
                            size: 132,
                            child: Icon(
                              Icons.check_rounded,
                              size: 72,
                              color: semantic.onAccent,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxl),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              "You're parked!",
                              style: context.text.displaySmall?.copyWith(
                                color: onBrand,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Slot ${booking.slotLabel} is all yours from '
                            '${Formatters.time(booking.start)}.\n'
                            'Payment confirmed by ParkSpot.',
                            textAlign: TextAlign.center,
                            style: context.text.bodyLarge?.copyWith(
                              color: onBrand.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxl),
                          _Summary(booking: booking, lot: lot),
                        ],
                        const Spacer(),
                        if (confirmed) ...[
                          ChunkyButton(
                            label: 'Show my pass',
                            variant: ChunkyButtonVariant.accent,
                            onPressed: () =>
                                context.go(AppRoutes.booking(booking!.id)),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: onBrand,
                                side: BorderSide(
                                  color: onBrand.withValues(alpha: 0.45),
                                  width: 2,
                                ),
                              ),
                              onPressed: () => unawaited(
                                openDirections(context, lot!.location),
                              ),
                              child: const Text('Take me there'),
                            ),
                          ),
                        ] else
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: onBrand,
                            ),
                            onPressed: () => context.go(AppRoutes.home),
                            child: const Text('Back to the map'),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static bool _gaveUp(Booking? b) =>
      b != null &&
      (b.status == BookingStatus.expired ||
          b.status == BookingStatus.failed ||
          b.status == BookingStatus.cancelled);
}

class _Confirming extends StatelessWidget {
  const _Confirming({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Column(
        children: [
          SizedBox.square(
            dimension: 48,
            child: CircularProgressIndicator(color: color, strokeWidth: 4),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            'Confirming your payment…',
            textAlign: TextAlign.center,
            style: context.text.headlineSmall?.copyWith(color: color),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "This usually takes a few seconds. You won't be charged twice.",
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(
              color: color.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.booking, required this.lot});

  final Booking booking;
  final Lot lot;

  @override
  Widget build(BuildContext context) {
    Widget fact(
      String label,
      String value, {
      bool big = false,
      bool end = false,
    }) => Column(
      crossAxisAlignment: end
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.text.labelMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: big ? context.text.titleLarge : context.text.titleSmall,
        ),
      ],
    );
    return Semantics(
      container: true,
      label: 'Booking summary',
      child: TicketCard(
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: fact('Where', lot.name)),
                fact('Slot', booking.slotLabel, big: true, end: true),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: DashedDivider(),
            ),
            Row(
              children: [
                Expanded(
                  child: fact(
                    'When',
                    Formatters.slotWindow(booking.start, booking.end),
                  ),
                ),
                fact(
                  'Paid',
                  Formatters.money(booking.amount),
                  big: true,
                  end: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Decoration only: a scatter of shapes in the brand colours.
class _Confetti extends StatelessWidget {
  const _Confetti();

  // x, y in the 390-wide design frame.
  static const _spots = [
    (28.0, 60.0),
    (92.0, 132.0),
    (300.0, 52.0),
    (340.0, 150.0),
    (56.0, 230.0),
    (320.0, 270.0),
    (180.0, 40.0),
    (250.0, 110.0),
    (20.0, 330.0),
    (350.0, 360.0),
    (140.0, 250.0),
    (270.0, 220.0),
    (70.0, 400.0),
    (330.0, 440.0),
    (210.0, 70.0),
    (110.0, 30.0),
  ];

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final colors = [
      semantic.accent,
      semantic.availabilityHigh,
      semantic.availabilityLow,
      semantic.onCelebration,
      context.colors.primaryContainer,
    ];
    final scale = MediaQuery.sizeOf(context).width / 390;
    return ExcludeSemantics(
      child: Stack(
        children: [
          for (final (i, (x, y)) in _spots.indexed)
            Positioned(
              left: x * scale,
              top: y * scale,
              child: Transform.rotate(
                angle: ((i * 37) % 90 - 45) * 3.14159 / 180,
                child: Container(
                  width: i % 3 == 0 ? 12 : 8,
                  height: i % 3 == 0 ? 12 : 18,
                  decoration: BoxDecoration(
                    color: colors[i % colors.length],
                    borderRadius: BorderRadius.circular(i % 3 == 0 ? 6 : 3),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
