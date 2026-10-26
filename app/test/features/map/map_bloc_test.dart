import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parkspot/core/network/api_exception.dart';
import 'package:parkspot/core/utils/geo_point.dart';
import 'package:parkspot/features/map/presentation/bloc/map_bloc.dart';

import '../../helpers/mocks.dart';

void main() {
  setUpAll(() => registerFallbackValue(const GeoPoint(0, 0)));

  late MockLotsRepository lots;
  late MockLocationService location;

  const me = GeoPoint(18.5246, 73.8411); // on FC Road
  final near = testLot(id: 'near', pricePaise: 6000, free: 5);
  final cheap = testLot(
    id: 'cheap',
    name: 'Koregaon Park Plaza',
    pricePaise: 2000,
    free: 10,
    location: const GeoPoint(18.5362, 73.8940),
  );
  final roomy = testLot(
    id: 'roomy',
    name: 'Viman Nagar Mall',
    pricePaise: 3000,
    free: 90,
    location: const GeoPoint(18.5679, 73.9143),
  );

  setUp(() {
    lots = MockLotsRepository();
    location = MockLocationService();
    when(() => location.shouldExplain()).thenAnswer((_) async => false);
    when(() => location.current()).thenAnswer((_) async => me);
    when(
      () => lots.nearby(any(), radiusMeters: any(named: 'radiusMeters')),
    ).thenAnswer((_) async => [roomy, cheap, near]);
  });

  MapBloc build() =>
      MapBloc(lots: lots, location: location, debounce: Duration.zero);

  blocTest<MapBloc, MapState>(
    'starts at the user and opens the nearest lot',
    build: build,
    act: (bloc) => bloc.add(const MapStarted()),
    verify: (bloc) {
      expect(bloc.state.me, me);
      expect(bloc.state.focus, me);
      expect(bloc.state.status, MapStatus.ready);
      expect(bloc.state.selected, near);
      expect(bloc.state.distanceTo(near), 0);
      verify(() => lots.nearby(me, radiusMeters: 2000)).called(1);
    },
  );

  blocTest<MapBloc, MapState>(
    'first visit: asks for location and looks around Pune meanwhile',
    setUp: () =>
        when(() => location.shouldExplain()).thenAnswer((_) async => true),
    build: build,
    act: (bloc) => bloc.add(const MapStarted()),
    verify: (bloc) {
      expect(bloc.state.askLocation, isTrue);
      expect(bloc.state.me, isNull);
      expect(bloc.state.distanceTo(near), isNull);
      verifyNever(() => location.current());
      verify(
        () => lots.nearby(
          const GeoPoint(18.5204, 73.8567),
          radiusMeters: any(named: 'radiusMeters'),
        ),
      ).called(1);
    },
  );

  blocTest<MapBloc, MapState>(
    'granted on the rationale: locates',
    build: build,
    seed: () => const MapState(askLocation: true),
    act: (bloc) => bloc.add(const MapLocationAnswered(granted: true)),
    verify: (bloc) {
      expect(bloc.state.askLocation, isFalse);
      expect(bloc.state.me, me);
    },
  );

  blocTest<MapBloc, MapState>(
    'sort pills open the top lot and fly to it',
    build: build,
    seed: () =>
        MapState(me: me, lots: [roomy, cheap, near], selectedId: 'near'),
    act: (bloc) => bloc
      ..add(const MapSortChanged(MapSort.cheapest))
      ..add(const MapSortChanged(MapSort.mostFree)),
    expect: () => [
      isA<MapState>()
          .having((s) => s.selectedId, 'selected', 'cheap')
          .having((s) => s.focus, 'focus', cheap.location),
      isA<MapState>().having((s) => s.selectedId, 'selected', 'roomy'),
    ],
  );

  blocTest<MapBloc, MapState>(
    'search filters by name or address',
    build: build,
    seed: () => MapState(me: me, lots: [roomy, cheap, near]),
    act: (bloc) => bloc
      ..add(const MapSearchChanged('viman'))
      ..add(const MapSearchChanged('nowhere')),
    expect: () => [
      isA<MapState>()
          .having((s) => s.visible, 'visible', [roomy])
          .having((s) => s.selectedId, 'selected', 'roomy'),
      isA<MapState>()
          .having((s) => s.visible, 'visible', isEmpty)
          .having((s) => s.selected, 'selected', isNull),
    ],
  );

  blocTest<MapBloc, MapState>(
    'selecting refreshes the free count',
    setUp: () => when(
      () => lots.byId('near'),
    ).thenAnswer((_) async => testLot(id: 'near', pricePaise: 6000, free: 1)),
    build: build,
    seed: () => MapState(me: me, lots: [roomy, near]),
    act: (bloc) => bloc.add(const MapLotSelected('near')),
    verify: (bloc) => expect(bloc.state.selected?.freeSlots, 1),
  );

  blocTest<MapBloc, MapState>(
    'panning reloads where the camera stopped, keeping the open lot',
    build: build,
    seed: () => MapState(me: me, lots: [cheap], selectedId: 'cheap'),
    act: (bloc) => bloc.add(const MapCameraIdle(GeoPoint(18.56, 73.91), 3000)),
    verify: (bloc) {
      verify(
        () => lots.nearby(const GeoPoint(18.56, 73.91), radiusMeters: 3000),
      ).called(1);
      expect(bloc.state.center, const GeoPoint(18.56, 73.91));
      expect(bloc.state.selectedId, 'cheap');
    },
  );

  blocTest<MapBloc, MapState>(
    'a burst of pans makes one request',
    build: () => MapBloc(
      lots: lots,
      location: location,
      debounce: const Duration(milliseconds: 50),
    ),
    act: (bloc) async {
      for (var i = 0; i < 4; i++) {
        bloc.add(MapCameraIdle(GeoPoint(18.5 + i / 100, 73.8), 2000));
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    },
    wait: const Duration(milliseconds: 100),
    verify: (_) => verify(
      () => lots.nearby(
        const GeoPoint(18.53, 73.8),
        radiusMeters: any(named: 'radiusMeters'),
      ),
    ).called(1),
  );

  blocTest<MapBloc, MapState>(
    'a failed load can be retried',
    setUp: () => when(
      () => lots.nearby(any(), radiusMeters: any(named: 'radiusMeters')),
    ).thenThrow(const ApiException(ApiErrorCode.network, 'Offline')),
    build: build,
    act: (bloc) => bloc.add(const MapRetried()),
    verify: (bloc) {
      expect(bloc.state.status, MapStatus.failure);
      expect(bloc.state.error, 'Offline');
    },
  );

  blocTest<MapBloc, MapState>(
    'locate without permission offers Settings',
    setUp: () {
      when(() => location.current()).thenAnswer((_) async => null);
      when(() => location.isBlocked()).thenAnswer((_) async => true);
    },
    build: build,
    act: (bloc) => bloc.add(const MapLocateRequested()),
    expect: () => [
      isA<MapState>().having((s) => s.notice?.blocked, 'blocked', isTrue),
    ],
  );
}
