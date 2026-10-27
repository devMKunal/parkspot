import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parkspot/core/location/location_service.dart';
import 'package:parkspot/core/payments/payment_checkout.dart';
import 'package:parkspot/core/utils/geo_point.dart';
import 'package:parkspot/core/utils/money.dart';
import 'package:parkspot/features/auth/domain/auth_repository.dart';
import 'package:parkspot/features/auth/domain/user.dart';
import 'package:parkspot/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:parkspot/features/bookings/domain/booking.dart';
import 'package:parkspot/features/bookings/domain/bookings_repository.dart';
import 'package:parkspot/features/bookings/domain/checkout_flow.dart';
import 'package:parkspot/features/lots/domain/lot.dart';
import 'package:parkspot/features/lots/domain/lots_repository.dart';
import 'package:parkspot/features/onboarding/domain/onboarding_status.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

class MockAuthBloc extends MockBloc<AuthEvent, AuthState> implements AuthBloc {}

class MockLotsRepository extends Mock implements LotsRepository {}

class MockLocationService extends Mock implements LocationService {}

class MockBookingsRepository extends Mock implements BookingsRepository {}

class MockPaymentCheckout extends Mock implements PaymentCheckout {}

class MockCheckoutFlow extends Mock implements CheckoutFlow {}

Booking testBooking({
  String id = 'b1',
  BookingStatus status = BookingStatus.confirmed,
  DateTime? start,
  Duration duration = const Duration(hours: 2),
  DateTime? lockExpiresAt,
  String? passCode = 'PS-7Q2K',
}) {
  final from = start ?? DateTime.utc(2026, 10, 19, 13);
  return Booking(
    id: id,
    lotId: 'fc',
    slotLabel: 'S014',
    start: from,
    end: from.add(duration),
    amount: const Money(8000),
    status: status,
    lockExpiresAt: lockExpiresAt,
    passCode: status.isLive ? passCode : null,
  );
}

Lot testLot({
  String id = 'fc',
  String name = 'FC Road Multilevel Parking',
  int free = 37,
  int total = 120,
  int pricePaise = 4000,
  GeoPoint location = const GeoPoint(18.5246, 73.8411),
}) => Lot(
  id: id,
  name: name,
  address: 'Fergusson College Rd, Shivajinagar',
  location: location,
  pricePerHour: Money(pricePaise),
  totalSlots: total,
  freeSlots: free,
);

/// Registers a quiet map in get_it: no location, no lots.
void registerQuietMap(GetIt getIt) {
  final lots = MockLotsRepository();
  final location = MockLocationService();
  when(location.shouldExplain).thenAnswer((_) async => false);
  when(location.current).thenAnswer((_) async => null);
  when(
    () => lots.nearby(any(), radiusMeters: any(named: 'radiusMeters')),
  ).thenAnswer((_) async => []);
  getIt
    ..registerSingleton<LotsRepository>(lots)
    ..registerSingleton<LocationService>(location);
}

final testUser = User(
  id: 'u1',
  name: 'Asha',
  email: 'asha@mail.com',
  createdAt: DateTime.utc(2026, 10, 1, 10),
);

/// [OnboardingStatus] that forgets on restart.
class InMemoryOnboardingStatus implements OnboardingStatus {
  InMemoryOnboardingStatus({bool seen = false}) : _seen = ValueNotifier(seen);

  final ValueNotifier<bool> _seen;

  @override
  ValueListenable<bool> get seen => _seen;

  @override
  Future<void> markSeen() async => _seen.value = true;
}
