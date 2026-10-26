import 'dart:async';

import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:parkspot/core/config/app_config.dart';
import 'package:parkspot/core/constants/storage_keys.dart';
import 'package:parkspot/core/location/location_service.dart';
import 'package:parkspot/core/network/api_client.dart';
import 'package:parkspot/core/network/auth_interceptor.dart';
import 'package:parkspot/core/network/session_refresher.dart';
import 'package:parkspot/core/payments/payment_checkout.dart';
import 'package:parkspot/core/storage/token_store.dart';
import 'package:parkspot/features/auth/data/auth_repository_impl.dart';
import 'package:parkspot/features/auth/domain/auth_repository.dart';
import 'package:parkspot/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:parkspot/features/bookings/data/bookings_repository_impl.dart';
import 'package:parkspot/features/bookings/domain/bookings_repository.dart';
import 'package:parkspot/features/bookings/domain/checkout_flow.dart';
import 'package:parkspot/features/lots/data/lots_repository_impl.dart';
import 'package:parkspot/features/lots/domain/lots_repository.dart';
import 'package:parkspot/features/onboarding/data/prefs_onboarding_status.dart';
import 'package:parkspot/features/onboarding/domain/onboarding_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

final GetIt getIt = GetIt.instance;

/// The composition root: the only place that picks concrete classes.
/// Called once from `main`; tests build what they need by hand.
Future<void> configureDependencies(AppConfig config) async {
  final prefs = await SharedPreferencesWithCache.create(
    cacheOptions: const SharedPreferencesWithCacheOptions(
      allowList: {
        StorageKeys.onboardingSeen,
        StorageKeys.locationRationaleSeen,
        StorageKeys.themeMode,
      },
    ),
  );

  final tokens = TokenStore();
  final refresher = SessionRefresher(dio: createDio(config), tokens: tokens);
  final sessionExpired = StreamController<void>.broadcast();
  final dio = createDio(config);
  dio.interceptors.add(
    AuthInterceptor(
      dio: dio,
      tokens: tokens,
      refresher: refresher,
      onSessionExpired: () => sessionExpired.add(null),
    ),
  );

  final auth = AuthRepositoryImpl(
    dio: dio,
    tokens: tokens,
    refresher: refresher,
  );

  final bookings = BookingsRepositoryImpl(dio);

  getIt
    ..registerSingleton<Dio>(dio)
    ..registerSingleton<OnboardingStatus>(PrefsOnboardingStatus(prefs))
    ..registerSingleton<AuthRepository>(auth)
    ..registerSingleton<LotsRepository>(LotsRepositoryImpl(dio))
    ..registerSingleton(LocationService(prefs))
    ..registerSingleton<BookingsRepository>(bookings)
    ..registerSingleton(CheckoutFlow(bookings, RazorpayCheckout()))
    ..registerSingleton<AuthBloc>(
      AuthBloc(repository: auth, sessionExpired: sessionExpired.stream)
        ..add(const AuthSessionRestoreRequested()),
    );
}
