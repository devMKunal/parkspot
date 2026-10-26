import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parkspot/core/theme/app_theme.dart';
import 'package:parkspot/core/utils/geo_point.dart';
import 'package:parkspot/core/widgets/chunky_button.dart';
import 'package:parkspot/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:parkspot/features/map/presentation/bloc/map_bloc.dart';
import 'package:parkspot/features/map/presentation/screen/map_page.dart';

import '../../helpers/mocks.dart';
import '../../helpers/pump_themed.dart';

class MockMapBloc extends MockBloc<MapEvent, MapState> implements MapBloc {}

void main() {
  setUpAll(() => registerFallbackValue(const MapStarted()));

  late MockMapBloc bloc;
  late MockAuthBloc auth;

  const me = GeoPoint(18.5246, 73.8411);
  final lot = testLot();

  setUp(() {
    bloc = MockMapBloc();
    auth = MockAuthBloc();
    when(() => auth.state).thenReturn(AuthState.authenticated(testUser));
  });

  Future<void> pump(
    WidgetTester tester,
    MapState state, {
    bool dark = false,
  }) async {
    tester.usePhoneSize();
    when(() => bloc.state).thenReturn(state);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(value: auth),
              BlocProvider<MapBloc>.value(value: bloc),
            ],
            child: const MapView(map: ColoredBox(color: Colors.grey)),
          ),
        ),
        GoRoute(
          path: '/lots/:id/book',
          builder: (_, s) => Text('Booking ${s.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        routerConfig: router,
      ),
    );
  }

  for (final dark in [false, true]) {
    testWidgets('header and lot sheet (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      await pump(
        tester,
        MapState(
          status: MapStatus.ready,
          me: me,
          lots: [lot],
          selectedId: 'fc',
        ),
        dark: dark,
      );

      expect(find.text('Hey Asha'), findsOneWidget);
      expect(find.text('Where are we parking?'), findsOneWidget);
      expect(find.text('Loads of space'), findsOneWidget);
      expect(find.text('FC Road Multilevel Parking'), findsOneWidget);
      expect(find.text('₹40/hr'), findsOneWidget);
      expect(find.text('0 m'), findsOneWidget);
      expect(find.text('37/120'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Grab a spot opens booking for that lot', (tester) async {
    await pump(
      tester,
      MapState(status: MapStatus.ready, lots: [lot], selectedId: 'fc'),
    );

    // No location: distance unknown, not a misleading number.
    expect(find.text('–'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChunkyButton, 'Grab a spot'));
    await tester.pumpAndSettle();
    expect(find.text('Booking fc'), findsOneWidget);
  });

  testWidgets('a full lot cannot be booked', (tester) async {
    await pump(
      tester,
      MapState(
        status: MapStatus.ready,
        lots: [testLot(free: 0)],
        selectedId: 'fc',
      ),
    );

    final button = tester.widget<ChunkyButton>(
      find.widgetWithText(ChunkyButton, 'Lot is full'),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('sort pills and search talk to the bloc', (tester) async {
    await pump(tester, MapState(status: MapStatus.ready, lots: [lot]));

    await tester.tap(find.text('Cheapest'));
    await tester.enterText(find.byType(TextField), 'viman');

    verify(() => bloc.add(const MapSortChanged(MapSort.cheapest))).called(1);
    verify(() => bloc.add(const MapSearchChanged('viman'))).called(1);
  });

  testWidgets('no match explains itself', (tester) async {
    await pump(
      tester,
      MapState(status: MapStatus.ready, lots: [lot], query: 'viman'),
    );

    expect(find.textContaining('No lots match "viman"'), findsOneWidget);
  });

  testWidgets('a failed load offers a retry', (tester) async {
    await pump(
      tester,
      const MapState(status: MapStatus.failure, error: 'Offline'),
    );

    await tester.tap(find.text('Try again'));
    verify(() => bloc.add(const MapRetried())).called(1);
  });

  testWidgets('locate button', (tester) async {
    await pump(tester, const MapState(status: MapStatus.ready));

    await tester.tap(find.bySemanticsLabel('Centre on my location'));
    verify(() => bloc.add(const MapLocateRequested())).called(1);
  });
}
