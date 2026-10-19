import { Errors } from '../../core/errors/AppError.js';
import { logger } from '../../core/logger.js';
import type { BookingService, ConfirmOutcome } from '../bookings/booking.service.js';
import type { BookingRecord } from '../bookings/booking.types.js';
import type { ExtensionService } from '../bookings/extension.service.js';
import type { CheckoutResult, PaymentGateway } from './payment.gateway.js';
import type { PaymentRepository } from './payment.repository.js';

export interface PaymentServiceDeps {
  gateway: PaymentGateway | null;
  bookingService: BookingService;
  extensionService: ExtensionService;
  payments: PaymentRepository;
}

/**
 * Turns provider-signed payments into confirmed bookings. The server never trusts the app's
 * word that a payment succeeded: only a valid provider signature moves a booking forward.
 */
export class PaymentService {
  constructor(private readonly deps: PaymentServiceDeps) {}

  /** Called by the app after checkout succeeds. */
  async verifyCheckout(userId: string, result: CheckoutResult): Promise<BookingRecord> {
    const gateway = this.requireGateway();
    if (!gateway.verifyCheckout(result)) throw Errors.paymentSignatureInvalid();

    const owner =
      (await this.deps.bookingService.ownerOfOrder(result.orderId)) ??
      (await this.deps.extensionService.ownerOfOrder(result.orderId));
    if (owner !== userId) throw Errors.notFound('Booking');

    const outcome = await this.apply(
      { orderId: result.orderId, paymentId: result.paymentId },
      'client',
    );
    if (outcome.kind === 'REFUND') throw Errors.paymentRefunded();
    if (outcome.kind === 'UNKNOWN_ORDER') throw Errors.notFound('Booking');
    return outcome.booking;
  }

  /**
   * Called by Razorpay. Covers the app crashing or losing network between paying and verifying.
   * Answers 2xx for every authentic event, so Razorpay stops retrying ones we've handled.
   */
  async handleWebhook(rawBody: Buffer, signature: string | undefined): Promise<void> {
    const gateway = this.requireGateway();
    const event = gateway.parseWebhook(rawBody, signature);
    if (!event) throw Errors.webhookSignatureInvalid();
    if (event.kind === 'ignored') return;

    const outcome = await this.apply(event.payment, 'webhook');
    if (outcome.kind === 'UNKNOWN_ORDER') {
      logger.warn({ orderId: event.payment.orderId }, 'Webhook for an order we did not create');
    }
  }

  private async apply(
    payment: { orderId: string; paymentId: string; amountPaise?: number },
    source: 'client' | 'webhook',
  ): Promise<ConfirmOutcome> {
    // An order belongs to either a booking or an extension of one.
    let outcome = await this.deps.bookingService.confirmPaid(payment);
    if (outcome.kind === 'UNKNOWN_ORDER')
      outcome = await this.deps.extensionService.confirmPaid(payment);
    if (outcome.kind === 'UNKNOWN_ORDER') return outcome;

    await this.deps.payments.recordCaptured({
      provider: this.requireGateway().provider,
      orderId: payment.orderId,
      paymentId: payment.paymentId,
      bookingId: outcome.booking.id,
      amountPaise: payment.amountPaise ?? outcome.orderPaise,
      source,
    });

    if (outcome.kind === 'REFUND') await this.refund(payment.paymentId, outcome);
    return outcome;
  }

  private async refund(paymentId: string, outcome: Extract<ConfirmOutcome, { kind: 'REFUND' }>) {
    const { payments } = this.deps;
    // Verify and webhook both report the same payment; only one of them may refund it.
    if (!(await payments.claimRefund(paymentId))) return;
    logger.warn({ paymentId, bookingId: outcome.booking.id, reason: outcome.reason }, 'Refunding');
    try {
      await this.requireGateway().refund(paymentId, outcome.orderPaise);
      await payments.setStatus(paymentId, 'REFUNDED');
    } catch (err) {
      // Left visible as REFUND_FAILED for a manual refund from the dashboard.
      logger.error({ err, paymentId }, 'Refund failed');
      await payments.setStatus(paymentId, 'REFUND_FAILED');
    }
  }

  private requireGateway(): PaymentGateway {
    if (!this.deps.gateway) throw Errors.paymentsUnavailable();
    return this.deps.gateway;
  }
}
