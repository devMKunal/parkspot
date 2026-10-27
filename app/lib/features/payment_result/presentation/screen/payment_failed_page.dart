import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:parkspot/core/extensions/context_x.dart';
import 'package:parkspot/core/theme/app_spacing.dart';
import 'package:parkspot/core/utils/formatters.dart';
import 'package:parkspot/core/widgets/alert_banner.dart';
import 'package:parkspot/core/widgets/chunky_button.dart';
import 'package:parkspot/core/widgets/fill_scroll_view.dart';
import 'package:parkspot/features/booking/presentation/screen/booking_page.dart';
import 'package:parkspot/features/bookings/domain/booking.dart';
import 'package:parkspot/features/payment_result/presentation/bloc/payment_result_bloc.dart';
import 'package:parkspot/features/payment_result/presentation/screen/payment_success_page.dart';
import 'package:parkspot/router/app_routes.dart';

class PaymentFailedPage extends StatelessWidget {
  const PaymentFailedPage({required this.bookingId, super.key});

  final String bookingId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          createPaymentResultBloc(context, bookingId)
            ..add(const PaymentResultStarted()),
      child: const PaymentFailedView(),
    );
  }
}

/// Plain wording, the hold time, and two ways forward.
class PaymentFailedView extends StatelessWidget {
  const PaymentFailedView({super.key, this.now});

  /// For tests; defaults to the clock.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return BlocConsumer<PaymentResultBloc, PaymentResultState>(
      listenWhen: (previous, current) =>
          current.outcome != null && current.outcome != previous.outcome,
      listener: (context, state) => goToOutcome(context, state.outcome!),
      builder: (context, state) {
        final booking = state.booking;
        final lot = state.lot;
        if (booking == null || lot == null) {
          return Scaffold(
            body: Center(
              child: state.error == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: AppSpacing.screen,
                      child: AlertBanner(message: state.error!),
                    ),
            ),
          );
        }
        final heldUntil = booking.lockExpiresAt;
        final held =
            booking.status == BookingStatus.pending &&
            heldUntil != null &&
            heldUntil.isAfter(now ?? DateTime.now());
        final amount = Formatters.money(booking.amount);
        return Scaffold(
          body: SafeArea(
            child: FillScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl,
                AppSpacing.xxxl * 2,
                AppSpacing.xxl,
                AppSpacing.lg,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 112,
                      height: 112,
                      decoration: BoxDecoration(
                        color: colors.errorContainer,
                        borderRadius: BorderRadius.circular(40),
                      ),
                      child: Icon(
                        Icons.error_outline_rounded,
                        size: 56,
                        color: colors.error,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    "Payment didn't go through",
                    textAlign: TextAlign.center,
                    style: context.text.headlineMedium,
                  ),
                  const SizedBox(height: AppSpacing.sm + 2),
                  Text(
                    'Your bank or UPI app declined it, or the payment was '
                    'cancelled. If $amount was debited, it will be refunded '
                    'to the same account automatically.',
                    textAlign: TextAlign.center,
                    style: context.text.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  AlertBanner(
                    tone: AlertTone.warning,
                    message: held
                        ? 'Slot ${booking.slotLabel} is held for you until '
                              '${Formatters.time(heldUntil)}. Try again '
                              'before then to keep it.'
                        : 'Your hold on slot ${booking.slotLabel} has ended. '
                              "Trying again books a new slot if there's one "
                              'free.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: colors.outlineVariant,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        _Line(lot.name, amount),
                        const SizedBox(height: AppSpacing.sm),
                        _Line(
                          Formatters.slotWindow(booking.start, booking.end),
                          'Not paid',
                          valueColor: colors.error,
                        ),
                      ],
                    ),
                  ),
                  if (state.retryError case final error?) ...[
                    const SizedBox(height: AppSpacing.lg),
                    AlertBanner(message: error),
                  ],
                  const Spacer(),
                  ChunkyButton(
                    label: 'Try payment again',
                    loading: state.paying.isSubmitting,
                    onPressed: () => context.read<PaymentResultBloc>().add(
                      const PaymentRetried(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () => context.go(AppRoutes.book(lot.id)),
                      child: const Text('Change time'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: context.text.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: context.text.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
